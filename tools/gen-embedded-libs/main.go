// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
//
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

// Command gen-embedded-libs compiles embedded Ballerina packages from langlib/*/bal and stdlib/*/bal
// and writes {org}.{module}.platform.sym and .bir under lib/registry/gen.
//
// The repository root is two levels above this package (tools/gen-embedded-libs); cwd does not matter.
//
//	go run -tags bootstrap ./tools/gen-embedded-libs
//
// The bootstrap tag is required while lib/registry/gen is empty; see lib/registry/embed_bootstrap.go.
// Output is embedded into the CLI (lib/registry/embed.go) and is gitignored.
package main

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"sort"
	"strings"
	"sync"

	bircodec "ballerina-lang-go/bir/codec"
	"ballerina-lang-go/lib/registry"
	"ballerina-lang-go/model/symbolpool"
	"ballerina-lang-go/projects"
	"ballerina-lang-go/semantics"
)

// stdlibLevels defines compilation levels for stdlib packages.
// Packages within a level are compiled in parallel; each level waits for the
// previous to complete before starting.
// Packages not listed in any level are compiled last in an implicit final level.
var stdlibLevels = [][]string{
	// L1: no cross-stdlib imports.
	// "http", "log" and "random" current implementations are self-contained,
	// but they may import other packages in the future where they will be moved to a higher level.
	{"io", "math.vector", "time", "url", "log", "random", "http"},
	// L2: may import L1 packages.
	{"crypto", "os"},
	// L3: may import L2 packages.
	{"file"},
	// L4, L5, ...: add slices here as new dependency tiers emerge.
}

func main() {
	if err := generateEmbeddedLibs(); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func generateEmbeddedLibs() error {
	_, file, _, _ := runtime.Caller(0)
	repoRoot := filepath.Clean(filepath.Join(filepath.Dir(file), "..", ".."))
	outDir := filepath.Join(repoRoot, "lib", "registry", "gen")
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		return err
	}

	// langlib: sequential (preserve existing behaviour).
	langlibRels, err := listBalPackageRels(repoRoot, "langlib")
	if err != nil {
		return err
	}
	for _, rel := range langlibRels {
		if err := compileAndWrite(repoRoot, rel, outDir); err != nil {
			return err
		}
	}

	// stdlib: assign each discovered package to its explicit level,
	// with unrecognised packages falling into an implicit final level.
	stdlibRels, err := listBalPackageRels(repoRoot, "stdlib")
	if err != nil {
		return err
	}

	// Build a name→level-index lookup from stdlibLevels.
	levelOf := make(map[string]int)
	for i, level := range stdlibLevels {
		for _, name := range level {
			levelOf[name] = i
		}
	}

	// Distribute rel paths into per-level buckets.
	// Packages not in stdlibLevels go to the implicit final bucket.
	finalLevel := len(stdlibLevels)
	buckets := make([][]string, finalLevel+1)
	for _, rel := range stdlibRels {
		// rel is e.g. "stdlib/io/bal" — middle segment is the module name.
		name := filepath.Base(filepath.Dir(filepath.FromSlash(rel)))
		idx, ok := levelOf[name]
		if !ok {
			idx = finalLevel
		}
		buckets[idx] = append(buckets[idx], rel)
	}

	for _, bucket := range buckets {
		if err := compileLevel(repoRoot, outDir, bucket); err != nil {
			return err
		}
	}
	return nil
}

// compileLevel compiles all packages in rels in parallel and returns the combined errors.
func compileLevel(repoRoot, outDir string, rels []string) error {
	var (
		wg   sync.WaitGroup
		mu   sync.Mutex
		errs []error
	)
	for _, rel := range rels {
		wg.Add(1)
		go func(r string) {
			defer wg.Done()
			if err := compileAndWrite(repoRoot, r, outDir); err != nil {
				mu.Lock()
				errs = append(errs, err)
				mu.Unlock()
			}
		}(rel)
	}
	wg.Wait()
	return errors.Join(errs...)
}

func listBalPackageRels(repoRoot, tree string) ([]string, error) {
	entries, err := os.ReadDir(filepath.Join(repoRoot, tree))
	if err != nil {
		return nil, fmt.Errorf("%s: %w", tree, err)
	}

	var names []string
	for _, e := range entries {
		if e.IsDir() {
			names = append(names, e.Name())
		}
	}
	sort.Strings(names)

	var rels []string
	for _, name := range names {
		rel := filepath.ToSlash(filepath.Join(tree, name, "bal"))
		toml := filepath.Join(repoRoot, rel, "Ballerina.toml")
		if _, err := os.Stat(toml); err != nil {
			if os.IsNotExist(err) {
				continue
			}
			return nil, fmt.Errorf("%s: %w", rel, err)
		}
		rels = append(rels, rel)
	}
	return rels, nil
}

func compileAndWrite(repoRoot, rel, outDir string) error {
	balRoot := filepath.Join(repoRoot, filepath.FromSlash(rel))
	b := projects.NewBuildOptionsBuilder()
	if strings.HasPrefix(rel, "langlib/") {
		b = b.WithOmitEmbeddedLanglibImports(true)
	}
	opts := b.Build()

	result, err := projects.Load(os.DirFS(balRoot), ".", projects.ProjectLoadConfig{BuildOptions: &opts})
	if err != nil {
		return fmt.Errorf("%s: load: %w", rel, err)
	}

	compilation := result.Project().CurrentPackage().Compilation()
	if compilation.DiagnosticResult().HasErrors() {
		var diag strings.Builder
		for _, d := range compilation.DiagnosticResult().Diagnostics() {
			fmt.Fprintf(&diag, "%v\n", d)
		}
		return fmt.Errorf("%s: compile errors:\n%s", rel, strings.TrimSuffix(diag.String(), "\n"))
	}

	backend := projects.NewBallerinaBackend(compilation)
	birPkg := backend.BIR()
	tyEnv := result.Project().Environment().TypeEnv()
	org := birPkg.PackageID.OrgName.Value()
	mod := birPkg.PackageID.PkgName.Value()
	exp, ok := backend.ExportedSymbols()[semantics.PackageIdentifier{OrgName: org, ModuleName: mod}]
	if !ok {
		return fmt.Errorf("%s: exported symbols not found for %s/%s", rel, org, mod)
	}

	symBytes, err := symbolpool.Marshal(exp, tyEnv)
	if err != nil {
		return fmt.Errorf("%s: marshal sym: %w", rel, err)
	}
	birBytes, err := bircodec.Marshal(tyEnv, birPkg)
	if err != nil {
		return fmt.Errorf("%s: marshal bir: %w", rel, err)
	}

	base := filepath.Join(outDir, org+"."+mod+".platform")
	symPath, birPath := base+".sym", base+".bir"
	if err := os.WriteFile(symPath, symBytes, 0o644); err != nil {
		return fmt.Errorf("%s: write sym: %w", rel, err)
	}
	if err := os.WriteFile(birPath, birBytes, 0o644); err != nil {
		return fmt.Errorf("%s: write bir: %w", rel, err)
	}
	registry.RegisterEmbedded(registry.ID{OrgName: org, ModuleName: mod}, symBytes)
	fmt.Println("wrote", symPath, "and", birPath)
	return nil
}

// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
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

package test_util_test

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"

	"github.com/ballerina-nutcracker/ballerina/test_util"
)

var goldenStageKinds = map[string]test_util.TestKind{
	"ast":       test_util.AST,
	"bir":       test_util.BIR,
	"cfg":       test_util.CFG,
	"desugared": test_util.Desugar,
}

// TestStageGoldensMatchCorpus checks each per-stage golden directory against
// corpus/bal in both directions: every test must have its golden, and every
// golden must belong to a test. Library tests live in corpus/lib and carry no
// per-stage goldens, so a golden under any of these directories that maps back
// to no .bal is reported as an orphan.
func TestStageGoldensMatchCorpus(t *testing.T) {
	names := make([]string, 0, len(goldenStageKinds))
	for name := range goldenStageKinds {
		names = append(names, name)
	}
	sort.Strings(names)

	for _, name := range names {
		t.Run(name, func(t *testing.T) {
			var missing []string
			expected := map[string]bool{}
			var goldenDir string
			for _, tc := range test_util.GetValidAndPanicTests(t, goldenStageKinds[name]) {
				expected[tc.ExpectedPath] = true
				if goldenDir == "" {
					goldenDir = goldenRoot(tc.ExpectedPath, name)
				}
				if test_util.IsUnsupported(tc.InputPath) {
					continue
				}
				if _, err := os.Stat(tc.ExpectedPath); err != nil {
					if !os.IsNotExist(err) {
						t.Fatalf("stat %s: %v", tc.ExpectedPath, err)
					}
					missing = append(missing, tc.Name)
				}
			}
			if len(missing) > 0 {
				t.Errorf("%d corpus/%s goldens are missing; regenerate with `go test ./... -update`:\n%s",
					len(missing), name, formatList(missing))
			}

			orphans := findOrphans(t, goldenDir, expected)
			if len(orphans) > 0 {
				t.Errorf("%d corpus/%s goldens belong to no corpus/bal test; delete them:\n%s",
					len(orphans), name, formatList(orphans))
			}
		})
	}
}

// goldenRoot recovers the stage's golden directory from any expected path
// inside it, so the walk does not need to re-resolve the corpus location.
func goldenRoot(expectedPath, stage string) string {
	dir := filepath.Dir(expectedPath)
	for dir != "" && filepath.Base(dir) != stage {
		parent := filepath.Dir(dir)
		if parent == dir {
			return ""
		}
		dir = parent
	}
	return dir
}

func findOrphans(t *testing.T, goldenDir string, expected map[string]bool) []string {
	if goldenDir == "" {
		t.Fatal("could not resolve golden directory")
	}
	var orphans []string
	err := filepath.Walk(goldenDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() || !strings.HasSuffix(path, ".txt") {
			return nil
		}
		if !expected[path] {
			orphans = append(orphans, path)
		}
		return nil
	})
	if err != nil {
		t.Fatalf("walk %s: %v", goldenDir, err)
	}
	return orphans
}

func formatList(entries []string) string {
	sort.Strings(entries)
	out := ""
	for _, e := range entries {
		out += "  " + e + "\n"
	}
	return out
}

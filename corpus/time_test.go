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

package corpus

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"

	"ballerina-lang-go/projects"
	"ballerina-lang-go/runtime"
	"ballerina-lang-go/test_util"

	_ "ballerina-lang-go/lib/rt"
)

// runTimeBal compiles and runs a time-module corpus test file, returning stdout.
// It uses the TestPal which now includes a Time implementation.
func runTimeBal(t *testing.T, balFile string) string {
	t.Helper()
	absPath, err := filepath.Abs(balFile)
	if err != nil {
		t.Fatal(err)
	}
	fsys := os.DirFS(filepath.Dir(absPath))
	ballerinaEnvPath, err := getBallerinaEnvPath()
	if err != nil {
		t.Fatal(err)
	}
	ballerinaEnvFs := os.DirFS(ballerinaEnvPath)

	result, err := projects.Load(fsys, filepath.Base(absPath), projects.ProjectLoadConfig{
		BallerinaEnvFs: ballerinaEnvFs,
	})
	if err != nil {
		t.Fatalf("failed to load project: %v", err)
	}
	currentPkg := result.Project().CurrentPackage()
	compilation := currentPkg.Compilation()
	if compilation.DiagnosticResult().HasErrors() {
		for _, d := range compilation.DiagnosticResult().Diagnostics() {
			t.Logf("diagnostic: %v", d)
		}
		t.Fatal("compilation had errors")
	}
	backend := projects.NewBallerinaBackend(compilation)
	birPkg := backend.BIR()

	stdoutBuf := &bytes.Buffer{}
	rt := runtime.NewRuntime(test_util.TestPal(stdoutBuf, os.Stderr), result.Project().Environment().TypeEnv())
	if err := rt.Interpret(*birPkg); err != nil {
		t.Fatalf("runtime error: %v", err)
	}
	return stdoutBuf.String()
}

// assertTimeOutput runs a time corpus test and asserts against its @output annotations.
func assertTimeOutput(t *testing.T, balFile string) {
	t.Helper()
	absPath, _ := filepath.Abs(balFile)
	stdout := runTimeBal(t, balFile)
	sources := collectSingleFileSources(absPath)
	anns, err := parseAnnotations(sources)
	if err != nil {
		t.Fatalf("failed to parse annotations: %v", err)
	}
	assertOutputAnnotations(t, anns, stdout, "")
}

func TestTimeUtc(t *testing.T) {
	assertTimeOutput(t, filepath.Join(externTestDataDir, "time-utc-v.bal"))
}

func TestTimeCivil(t *testing.T) {
	assertTimeOutput(t, filepath.Join(externTestDataDir, "time-civil-v.bal"))
}

func TestTimeDate(t *testing.T) {
	assertTimeOutput(t, filepath.Join(externTestDataDir, "time-date-v.bal"))
}

func TestTimeEmail(t *testing.T) {
	assertTimeOutput(t, filepath.Join(externTestDataDir, "time-email-v.bal"))
}

func TestTimeDuration(t *testing.T) {
	assertTimeOutput(t, filepath.Join(externTestDataDir, "time-duration-v.bal"))
}

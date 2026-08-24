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

package test_util

import (
	"path/filepath"
	"strings"
	"testing"
)

// LibCorpusDir is the corpus root holding standard-library tests. They exercise
// native Go code the compiler never sees, so they carry no per-stage goldens —
// only the end-to-end goldens under corpus/integration/lib.
const LibCorpusDir = "lib"

// HasStageGolden reports whether this test is compared against a per-stage
// golden file. Library tests have none.
func (tc TestCase) HasStageGolden() bool {
	return tc.ExpectedPath != ""
}

// GetLibValidAndPanicTests returns the -v and -p library tests under
// corpus/lib. The stage tests run these for their invariant checks; the golden
// comparison is skipped via HasStageGolden.
func GetLibValidAndPanicTests(t testing.TB) []TestCase {
	return getLibTests(t, func(path string) bool {
		if IsFutureTest(path) {
			return false
		}
		return strings.HasSuffix(path, "-v.bal") || strings.HasSuffix(path, "-p.bal")
	})
}

// GetLibErrorTests returns the -e library tests under corpus/lib.
func GetLibErrorTests(t testing.TB) []TestCase {
	return getLibTests(t, func(path string) bool {
		return strings.HasSuffix(path, "-e.bal") && !IsFutureTest(path)
	})
}

func getLibTests(t testing.TB, filterFunc func(string) bool) []TestCase {
	inputDir, _ := resolveDir(t, LibCorpusDir, LibCorpusDir)
	files := walkDir(t, inputDir, filterFunc)
	cases := make([]TestCase, 0, len(files))
	for _, inputPath := range files {
		relPath, _ := filepath.Rel(inputDir, inputPath)
		cases = append(cases, TestCase{
			InputPath: inputPath,
			Name:      LibCorpusDir + "/" + filepath.ToSlash(relPath),
		})
	}
	return cases
}

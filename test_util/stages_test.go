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
	"sort"
	"testing"

	"github.com/ballerina-nutcracker/ballerina/test_util"
)

var goldenStageKinds = map[string]test_util.TestKind{
	"ast":       test_util.AST,
	"bir":       test_util.BIR,
	"cfg":       test_util.CFG,
	"desugared": test_util.Desugar,
}

// TestStageGoldenFilesMatchRules keeps StageGoldenRules and the goldens on disk
// in sync: no missing goldens, no stale ones left behind.
func TestStageGoldenFilesMatchRules(t *testing.T) {
	names := make([]string, 0, len(goldenStageKinds))
	for name := range goldenStageKinds {
		names = append(names, name)
	}
	sort.Strings(names)

	for _, name := range names {
		t.Run(name, func(t *testing.T) {
			var missing, stale []string
			for _, tc := range test_util.GetValidAndPanicTests(t, goldenStageKinds[name]) {
				if test_util.IsUnsupported(tc.InputPath) {
					continue
				}
				_, err := os.Stat(tc.ExpectedPath)
				if err != nil && !os.IsNotExist(err) {
					t.Fatalf("stat %s: %v", tc.ExpectedPath, err)
				}
				switch {
				case tc.KeepsStageGoldens() && err != nil:
					missing = append(missing, tc.Name)
				case !tc.KeepsStageGoldens() && err == nil:
					stale = append(stale, tc.ExpectedPath)
				}
			}
			if len(missing) > 0 {
				t.Errorf("%d corpus/%s goldens are missing; regenerate with `go test ./... -update`:\n%s",
					len(missing), name, formatList(missing))
			}
			if len(stale) > 0 {
				t.Errorf("%d corpus/%s goldens belong to tests that no longer keep goldens; delete them:\n%s",
					len(stale), name, formatList(stale))
			}
		})
	}
}

func formatList(entries []string) string {
	sort.Strings(entries)
	out := ""
	for _, e := range entries {
		out += "  " + e + "\n"
	}
	return out
}

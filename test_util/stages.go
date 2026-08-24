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
)

// StageGoldenRule maps a corpus path prefix to whether tests under it keep
// per-stage golden files (corpus/ast, corpus/cfg, corpus/desugared, corpus/bir).
type StageGoldenRule struct {
	// Prefix matches TestCase.Name: a directory ("library/"), one library's
	// tests ("library/subset3/avro-"), or an exact test. Empty matches all.
	Prefix  string
	Goldens bool
}

// StageGoldenRules decides which corpus tests keep per-stage goldens. Rules are
// evaluated in order and the last match wins. Every test still runs its stage
// work and invariant checks; only the golden comparison is gated.
// TestStageGoldenFilesMatchRules names the files to regenerate or delete
// whenever these rules and the tree disagree.
var StageGoldenRules = []StageGoldenRule{
	{Prefix: "", Goldens: true},

	// Library goldens hold only the test file's own compilation unit — the
	// library itself stays opaque — so they add nothing over the runtime
	// coverage in corpus/integration/library.
	{Prefix: "library/", Goldens: false},

	// A library shipping a code modifier rewrites the user's AST, so its
	// goldens do carry signal. Opt one in, and narrow single tests back out:
	//   {Prefix: "library/subset4/persist-", Goldens: true},
	//   {Prefix: "library/subset4/persist-huge-schema-v.bal", Goldens: false},
}

// KeepsStageGoldens reports whether this test is compared against per-stage
// golden files.
func (tc TestCase) KeepsStageGoldens() bool {
	name := filepath.ToSlash(tc.Name)
	keep := true
	for _, rule := range StageGoldenRules {
		if strings.HasPrefix(name, rule.Prefix) {
			keep = rule.Goldens
		}
	}
	return keep
}

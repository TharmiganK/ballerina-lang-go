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

package main

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/spf13/cobra"
)

// Version is set via ldflags at build time. Kept a plain literal so -X
// still works. cli.ExtractDriverSource treats "dev" as a sentinel, so
// never overwrite this — only displayVersion() may use the file fallback.
var Version = "dev"

const (
	// Channel mirrors jBallerina's "(Swan Lake)" suffix.
	Channel = "Nutcracker"
	// LanguageSpecVersion matches jBallerina's currently targeted spec.
	LanguageSpecVersion = "2024R1"
)

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print the Ballerina version",
	Run: func(cmd *cobra.Command, args []string) {
		printVersion()
	},
}

func init() {
	rootCmd.Version = Version
	rootCmd.SetVersionTemplate(versionOutput())
}

// readVersionFile reads the repo's VERSION file relative to this source
// file's own path — only resolvable for a binary built from a source
// checkout, not an installed/distributed one.
func readVersionFile() (string, bool) {
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		return "", false
	}
	data, err := os.ReadFile(filepath.Join(filepath.Dir(file), "..", "..", "VERSION"))
	if err != nil {
		return "", false
	}
	return strings.TrimSpace(string(data)), true
}

// displayVersion is what bal -v/bal version print, falling back to the
// VERSION file only when Version is still the unflagged-build default.
func displayVersion() string {
	v := Version
	if v == "dev" {
		if fileVersion, ok := readVersionFile(); ok {
			v = fileVersion
		}
	}
	return strings.TrimSuffix(v, "-SNAPSHOT")
}

func versionOutput() string {
	return fmt.Sprintf("Ballerina %s (%s)\nLanguage specification %s\n", displayVersion(), Channel, LanguageSpecVersion)
}

func printVersion() {
	fmt.Print(versionOutput())
}

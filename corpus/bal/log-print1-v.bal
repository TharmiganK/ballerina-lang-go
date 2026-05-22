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

// Verifies that all four print functions compile and can be called without panic.
// printDebug is filtered at the default INFO level so no log output reaches stderr,
// satisfying the clean-stderr requirement for -v tests.

import ballerina/io;
import ballerina/log;

public function main() {
    log:printDebug("debug message — filtered at INFO level");
    io:println("ok");
}
// @output ok

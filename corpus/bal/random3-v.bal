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

import ballerina/io;
import ballerina/random;

public function main() {
    int|random:Error equal = random:createIntInRange(5, 5);
    io:println(equal is random:Error);

    int|random:Error reversed = random:createIntInRange(10, 3);
    io:println(reversed is random:Error);

    if equal is random:Error {
        io:println(equal.message());
    }
}
// @output true
// @output true
// @output End range value must be greater than the start range value

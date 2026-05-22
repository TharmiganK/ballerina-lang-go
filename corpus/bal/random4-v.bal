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

public function main() returns error? {
    float d1 = random:createDecimal();
    float d2 = random:createDecimal();
    io:println(d1 >= 0.0 && d1 < 1.0);
    io:println(d2 >= 0.0 && d2 < 1.0);

    int a = check random:createIntInRange(0, 1000000);
    int b = check random:createIntInRange(0, 1000000);
    io:println(a >= 0 && a < 1000000);
    io:println(b >= 0 && b < 1000000);
}
// @output true
// @output true
// @output true
// @output true

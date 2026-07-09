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

function add(int x, int y, int z) {
    io:println("Sum of x, y and z:", x + y + z);
}

public function main() {
    // Calls the `add` function using the positional arguments.
    add(1, 2, 3);

    // Calls the `add` function using the named arguments in the same order as the parameters of the function definition.
    add(x = 1, y = 2, z = 3);

    // Calls the `add` function using the named arguments in a different order from the order of the parameters in the function definition.
    add(z = 3, y = 2, x = 1);

    // Calls the `add` function using a combination of named arguments and positional arguments.
    add(1, z = 3, y = 2);
}

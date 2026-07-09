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

// Uninitialized integer variable `value`.
int value;

// Uninitialized final string variable `name`.
final string name;

function init() returns error? {
    // Initialize the `value` variable to 5.
    value = 5;
    // Initialize the final variable greeting to `James`.
    name = "James";
    
    if value > 3 {
        // The initialization will fail with this error message.
        return error("Value should less than 3");
    }
}

public function main() {
    // This will not be executed because the init function returns an error.
    io:println(name);
}

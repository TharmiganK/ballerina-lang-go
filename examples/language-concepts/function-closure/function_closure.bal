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

public function main() {
    string[] names = ["Ana", "Alice", "Bob"];

    // Define a function to modify and return the variable 'names' that are declared outside the scope.
    var addName = function(string value) returns string[] {
        // Access the variable `names` as closure within the `addName` inner function.
        names.push(value);
        return names;
    };

    io:println(addName("James"));
    io:println(names);
}

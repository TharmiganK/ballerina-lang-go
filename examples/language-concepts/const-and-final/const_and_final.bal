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

const int MAX_VALUE = 1000;

// Constants can be defined without the type. Then, the type is inferred from the right-hand side.
const URL = "https://ballerina.io";

// Mapping and list constants can also be defined.
const HTTP_OK = {httpCode: 200, message: "OK"};
const ERROR_CODES = [200, 202, 400];

// The value for the `msg` variable can only be assigned once.
final string msg = loadMessage();

public function main() {
    io:println(MAX_VALUE);
    io:println(URL);
    io:println(HTTP_OK);
    io:println(ERROR_CODES);
    io:println(msg);
}

function loadMessage() returns string {
    return "Hello World";
}

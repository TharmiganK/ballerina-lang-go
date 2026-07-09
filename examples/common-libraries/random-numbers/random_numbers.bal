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
    // Generates a random decimal number between 0.0 and 1.0.
    float randomDecimal = random:createDecimal();
    io:println("Random decimal number: ", randomDecimal);

    // Generates a random number between the given start(inclusive) and end(exclusive) values.
    int randomInteger = check random:createIntInRange(1, 100);
    io:println("Random integer number in range: ", randomInteger);
}

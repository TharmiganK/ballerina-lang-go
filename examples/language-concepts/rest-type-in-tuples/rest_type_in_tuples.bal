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
    // declare a tuple with zero or more `int` members after the first member of type `string`.
    [string, int...] scoreList = ["John", 55, 43, 65, 65];
    io:println(scoreList);

    [string, int...] secondScoreList = ["Amy"];
    io:println(secondScoreList);

    // [T...] is equivalent to array T[].
    [int...] scores = [];
    io:println(scores);

    scores = [23, 53];
    io:println(scores);

    // New members can be pushed to a tuple with rest type by using `array:push()` method
    scores.push(43);
    io:println(scores);
}

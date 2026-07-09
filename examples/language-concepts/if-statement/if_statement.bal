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

function getGrades(int score) returns string {
    // Parentheses are optional in conditions.
    // However, curly braces are required in `if/else` statements.
    if 0 < score && score < 55 {
        return "F";
    } else if 55 <= score && score < 65 {
        return "C";
    } else if 65 <= score && score < 75  {
        return "B";
    } else if 75 <= score && score <= 100 {
        return "A";
    } else {
        return "Invalid grade";
    }
}

public function main() {
    int score = 66;
    string grade = getGrades(score);
    io:println(grade);

    int|string newScore = 77;

    // The `if` statement can be used for type narrowing.
    if newScore is int {
        io:println(getGrades(newScore));
    } else {
        io:println("Score is not an integer");
    }

}

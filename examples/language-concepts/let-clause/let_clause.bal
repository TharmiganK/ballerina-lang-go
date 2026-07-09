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

type Student record {|
    string first;
    string last;
    int mathematics;
    int english;
|};

public function main() {
    Student[] students = [
        {first: "Melina", last: "Kodel", mathematics: 79, english: 83},
        {first: "Tom", last: "Riddle", mathematics: 69, english: 45}
    ];

    int[] names = from var student in students
                  // The `let` clause binds the variables.
                  let int sum = (student.mathematics + student.english)
                  where sum > 0
                  let int avg = sum / 2
                  select avg;

    io:println(names);

    // The `let` clause supports multiple variable declarations separated by `,`.
    names = from var student in students
                   let int sum = (student.mathematics + student.english), int avg = sum / 2
                   where sum > 0
                   select avg;

    io:println(names);
}

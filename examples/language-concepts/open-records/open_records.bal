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

// `Student` type allows additional fields with `anydata` values.
type Student record {
    string name;
    int age;
};

type PartTimeStudent record {|
    string name;
    int age;
    // Rest descriptor allows additional fields with `anydata` values
    // in the `PartTimeStudent` type.
    anydata...;
|};

public function main() {
    // Adds an additional `country` field to `s1`.
    Student s1 = {
        name: "John",
        age: 25,
        "country": "UK"
    };
    io:println(s1);

    // Accesses the `age` field in `s1`.
    int age = s1.age;
    io:println(age);

    // Accesses the `country` field in `s1`.
    anydata country = s1["country"];
    io:println(country);

    // Adds an additional `studyHours` field to `s2`.
    PartTimeStudent s2 = {
        name: "Anne",
        age: 23,
        "studyHours": 6
    };

    // Accesses the `studyHours` field in `s2`.
    anydata studyHours = s2["studyHours"];
    io:println(studyHours);

    // Adds an additional `credits` field to `s2`.
    s2["credits"] = 120.5;
    io:println(s2);

    // A variable of type `PartTimeStudent` can be used where a `Student` value is expected.
    Student s3 = s2;
    io:println(s3);

    // A variable of type `Student` can be used where a `map<anydata>` value is expected.
    map<anydata> s4 = s3;
    io:println(s4);
}

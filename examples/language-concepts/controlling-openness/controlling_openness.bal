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
    string name;
    string country;
|};

type PartTimeStudent record {|
    string name;
    string country;
    // Rest descriptor of type `string` allows additional fields with `string` values.
    string...;
|};

public function main() {
    // `s1` can only have fields exclusively specified in `Student`.
    Student s1 = {name: "Anne", country: "UK"};

    // `s1` is a `map` with `string` values.
    map<string> s2 = s1;
    io:println(s2);

    // `s3` has an additional `faculty` field.
    PartTimeStudent s3 = {
        name: "Anne",
        country: "UK",
        "faculty": "Science"
    };

    // Accesses the `faculty` field in `s3`.
    string? faculty = s3["faculty"];
    io:println(faculty);

    // `s3` is a `map` with `string` values.
    map<string> s4 = s3;
    io:println(s4);
}

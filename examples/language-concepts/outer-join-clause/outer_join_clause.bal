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

type Department record {|
   int id;
   string name;
|};

type Person record {|
   int id;
   string fname;
   string lname;
|};

type DeptPerson record {|
   string fname;
   string? dept;
|};

public function main() {
    Person p1 = {id: 1, fname: "Alex", lname: "George"};
    Person p2 = {id: 2, fname: "John", lname: "Fonseka"};
    Person p3 = {id: 3, fname: "Ted", lname: "Perera"};

    Department d1 = {id: 1, name:"HR"};
    Department d2 = {id: 2, name:"Operations"};

    Person[] personList = [p1, p2, p3];
    Department[] deptList = [d1, d2];

    DeptPerson[] deptPersonList =
       from Person person in personList
       // The `outer join` clause performs a left outer equijoin.
       // For the records for which there is no matching record
       // on the `deptList`, the resulting record will contain `nil` fields.
       outer join var dept in deptList
       on person.id equals dept?.id
       select {
           fname : person.fname,
           dept : dept?.name
       };

    io:println(deptPersonList);
}

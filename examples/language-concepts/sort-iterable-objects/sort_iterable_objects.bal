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

type Employee record {
    string firstName;
    string lastName;
    decimal salary;
};

public function main() {
    Employee[] employees = [
        {firstName: "Jones", lastName: "Welsh", salary: 1000.00},
        {firstName: "Anne", lastName: "Frank", salary: 5000.00},
        {firstName: "Rocky", lastName: "Irving", salary: 6000.00},
        {firstName: "Anne", lastName: "Perera", salary: 3000.00},
        {firstName: "Jermaine", lastName: "Perera", salary: 4000.00},
        {firstName: "Rocky", lastName: "Puckett", salary: 6000.00},
        {firstName: "Jermaine", lastName: "Kent", salary: 4000.00}
    ];

    Employee[] sorted = from var e in employees
                        // The `order by` clause sorts the output items based on the given 
                        // `order-key` and the `order-direction`.
                        // The `order-key` must be an ordered type.
                        // The `order-direction` is `ascending` if not specified explicitly.
                        order by e.firstName ascending, e.lastName descending
                        select e;

    foreach Employee e in sorted {
        io:println(e.firstName, " ", e.lastName);
    }
}

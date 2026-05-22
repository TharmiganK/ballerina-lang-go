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
import ballerina/time;

public function main() {
    // dateValidate — valid date returns nil
    time:Date valid = {year: 1994, month: 11, day: 7};
    time:Error? validErr = time:dateValidate(valid);
    io:println(validErr is ()); // @output true

    // dateValidate — invalid day for month
    time:Date invalid = {year: 2021, month: 2, day: 30};
    time:Error? invalidErr = time:dateValidate(invalid);
    io:println(invalidErr is time:Error); // @output true

    // dateValidate — invalid month
    time:Date badMonth = {year: 2021, month: 13, day: 1};
    time:Error? badMonthErr = time:dateValidate(badMonth);
    io:println(badMonthErr is time:Error); // @output true

    // dayOfWeek — 1994-11-07 is a Monday (1)
    io:println(time:dayOfWeek({year: 1994, month: 11, day: 7})); // @output 1

    // dayOfWeek — 2021-01-03 is a Sunday (0)
    io:println(time:dayOfWeek({year: 2021, month: 1, day: 3})); // @output 0

    // dayOfWeek — 2021-01-09 is a Saturday (6)
    io:println(time:dayOfWeek({year: 2021, month: 1, day: 9})); // @output 6
}

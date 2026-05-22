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

public function main() returns error? {
    // civilAddDuration — +1 year +3 days +4 hours from a Z-timezone civil
    time:Civil base = check time:civilFromString("2025-04-25T10:15:30.00Z");
    time:Civil updated = check time:civilAddDuration(base, {years: 1, days: 3, hours: 4});
    io:println(check time:civilToString(updated)); // @output 2026-04-28T14:15:30Z

    // civilAddDuration — adding weeks
    time:Civil base2 = check time:civilFromString("2025-01-01T00:00:00.00Z");
    time:Civil updated2 = check time:civilAddDuration(base2, {weeks: 2});
    io:println(check time:civilToString(updated2)); // @output 2025-01-15T00:00:00Z

    // civilAddDuration — with fixed offset
    time:Civil base3 = check time:civilFromString("2021-04-12T23:20:50.520+05:30");
    time:Civil updated3 = check time:civilAddDuration(base3, {months: 1, minutes: 10});
    io:println(check time:civilToString(updated3)); // @output 2021-05-12T23:30:50.520+05:30

    // civilAddDuration error — no offset or abbreviation
    time:Civil bare = {year: 2021, month: 1, day: 1, hour: 0, minute: 0};
    time:Civil|time:Error durErr = time:civilAddDuration(bare, {days: 1});
    io:println(durErr is time:Error); // @output true
}

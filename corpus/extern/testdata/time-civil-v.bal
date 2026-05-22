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
    // utcToCivil extracts date/time components
    time:Utc utc = check time:utcFromString("2007-12-03T10:15:30.00Z");
    time:Civil civil = time:utcToCivil(utc);
    io:println(civil.year);    // @output 2007
    io:println(civil.month);   // @output 12
    io:println(civil.day);     // @output 3
    io:println(civil.hour);    // @output 10
    io:println(civil.minute);  // @output 15

    // utcFromCivil roundtrip via Z abbreviation (no utcOffset field set for Z strings)
    time:Utc utcBack = check time:utcFromCivil(civil);
    io:println(time:utcToString(utcBack)); // @output 2007-12-03T10:15:30Z

    // civilFromString / civilToString roundtrip with UTC offset +05:30
    time:Civil civil2 = check time:civilFromString("2021-04-12T23:20:50.520+05:30");
    io:println(check time:civilToString(civil2)); // @output 2021-04-12T23:20:50.520+05:30
    io:println(civil2.year);   // @output 2021
    io:println(civil2.month);  // @output 4
    io:println(civil2.day);    // @output 12

    // civilFromString with Z — no utcOffset in output, timeAbbrev = "Z"
    time:Civil civilZ = check time:civilFromString("2007-12-03T10:15:30.52Z");
    io:println(time:utcToString(check time:utcFromCivil(civilZ))); // @output 2007-12-03T10:15:30.520Z

    // civilToString error — neither utcOffset nor timeAbbrev
    time:Civil bare = {year: 2021, month: 1, day: 1, hour: 0, minute: 0};
    string|time:Error civilErr = time:civilToString(bare);
    io:println(civilErr is time:Error); // @output true
}

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
    // utcFromString / utcToString roundtrip — 0 nanoseconds → no fractional part
    time:Utc utc = check time:utcFromString("2007-12-03T10:15:30.00Z");
    io:println(time:utcToString(utc)); // @output 2007-12-03T10:15:30Z

    // utcToString with sub-millisecond precision — Java grouping: 520ms → 3 digits (.520)
    time:Utc utcMs = check time:utcFromString("2007-12-03T10:15:30.520Z");
    io:println(time:utcToString(utcMs)); // @output 2007-12-03T10:15:30.520Z

    // utcToString with microsecond precision — 6 digits
    time:Utc utcUs = check time:utcFromString("2007-12-03T10:15:30.000052Z");
    io:println(time:utcToString(utcUs)); // @output 2007-12-03T10:15:30.000052Z

    // utcAddSeconds — positive seconds with fraction
    time:Utc utc2 = time:utcAddSeconds(utc, 20.9);
    io:println(time:utcToString(utc2)); // @output 2007-12-03T10:15:50.900Z

    // utcDiffSeconds
    time:Seconds diff = time:utcDiffSeconds(utc2, utc);
    io:println(diff); // @output 20.9

    // utcAddSeconds — negative seconds (subtract)
    time:Utc utc3 = time:utcAddSeconds(utc2, -20.9);
    io:println(time:utcToString(utc3)); // @output 2007-12-03T10:15:30Z

    // utcFromString error — invalid format
    time:Utc|time:Error errResult = time:utcFromString("not-a-timestamp");
    io:println(errResult is time:Error); // @output true
}

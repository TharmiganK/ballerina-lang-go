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
    time:Utc utc = check time:utcFromString("2007-12-03T10:15:30.00Z");

    // utcToEmailString — zh="0" produces "+0000", non-padded day
    io:println(time:utcToEmailString(utc)); // @output Mon, 3 Dec 2007 10:15:30 +0000

    // utcToEmailString — zh="GMT" preserves "GMT"
    io:println(time:utcToEmailString(utc, "GMT")); // @output Mon, 3 Dec 2007 10:15:30 GMT

    // utcToEmailString — zh="Z"
    io:println(time:utcToEmailString(utc, "Z")); // @output Mon, 3 Dec 2007 10:15:30 Z

    // civilFromEmailString / civilToString roundtrip with positive offset
    time:Civil emailCivil = check time:civilFromEmailString("Mon, 12 Apr 2021 23:20:50 +0530");
    io:println(check time:civilToString(emailCivil)); // @output 2021-04-12T23:20:50+05:30

    // civilFromEmailString / civilToString roundtrip with negative offset
    time:Civil emailCivil2 = check time:civilFromEmailString("Wed, 10 Mar 2021 19:51:55 -0800");
    io:println(check time:civilToString(emailCivil2)); // @output 2021-03-10T19:51:55-08:00

    // civilToEmailString with PREFER_ZONE_OFFSET
    time:Civil civil = check time:civilFromString("2021-04-12T23:20:50.520+05:30");
    io:println(check time:civilToEmailString(civil, time:PREFER_ZONE_OFFSET)); // @output Mon, 12 Apr 2021 23:20:50 +0530

    // civilToEmailString with ZONE_OFFSET_WITH_TIME_ABBREV_COMMENT
    time:Civil emailCivil3 = check time:civilFromEmailString("Wed, 10 Mar 2021 19:51:55 -0800 (PST)");
    io:println(check time:civilToEmailString(emailCivil3, time:ZONE_OFFSET_WITH_TIME_ABBREV_COMMENT)); // @output Wed, 10 Mar 2021 19:51:55 -0800 (PST)
}

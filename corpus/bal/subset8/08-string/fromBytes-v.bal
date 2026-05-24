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

public function main() {
    byte[] b = [72, 101, 108, 108, 111, 32, 66, 97, 108, 108, 101, 114, 105, 110, 97, 33];
    if string:fromBytes(b) is error {
        io:println("error");
    } else {
        io:println(checkpanic string:fromBytes(b));
    }
    // @output Hello Ballerina!

    byte[] roundTrip = "Go native".toBytes();
    io:println(checkpanic string:fromBytes(roundTrip)); // @output Go native
}

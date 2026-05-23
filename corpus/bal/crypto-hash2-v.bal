// Copyright (c) 2025, WSO2 LLC. (https://www.wso2.com)
//
// WSO2 LLC. licenses this file under the Apache License,
// Version 2.0 (the "License"); you may not use this file
// except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied. See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/crypto;
import ballerina/io;

public function main() {
    // "Hello Ballerina"
    byte[] data = [72, 101, 108, 108, 111, 32, 66, 97, 108, 108, 101, 114, 105, 110, 97];

    // CRC32B returns an 8-character hex string
    string crc = crypto:crc32b(data);
    io:println(crc.length());

    // Same input → same CRC
    io:println(crc == crypto:crc32b(data));

    // Different input → different CRC ("Other")
    byte[] other = [79, 116, 104, 101, 114];
    io:println(crc == crypto:crc32b(other));
}
// @output 8
// @output true
// @output false

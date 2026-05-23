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

    io:println(crypto:hashMd5(data).length());
    io:println(crypto:hashSha1(data).length());
    io:println(crypto:hashSha256(data).length());
    io:println(crypto:hashSha384(data).length());
    io:println(crypto:hashSha512(data).length());
    io:println(crypto:hashKeccak256(data).length());

    // Two calls with same input must be identical
    byte[] h1 = crypto:hashSha256(data);
    byte[] h2 = crypto:hashSha256(data);
    io:println(crypto:equalConstantTime(h1, h2));

    // Hash with salt produces different result
    // "mysalt"
    byte[] salt = [109, 121, 115, 97, 108, 116];
    byte[] salted = crypto:hashSha256(data, salt);
    io:println(crypto:equalConstantTime(salted, h1));
}
// @output 16
// @output 20
// @output 32
// @output 48
// @output 64
// @output 32
// @output true
// @output false

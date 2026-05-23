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

public function main() returns error? {
    // "Hello Ballerina"
    byte[] data = [72, 101, 108, 108, 111, 32, 66, 97, 108, 108, 101, 114, 105, 110, 97];
    // "secretkey0123456"
    byte[] key = [115, 101, 99, 114, 101, 116, 107, 101, 121, 48, 49, 50, 51, 52, 53, 54];

    io:println((check crypto:hmacMd5(data, key)).length());
    io:println((check crypto:hmacSha1(data, key)).length());
    io:println((check crypto:hmacSha256(data, key)).length());
    io:println((check crypto:hmacSha384(data, key)).length());
    io:println((check crypto:hmacSha512(data, key)).length());

    // Same key+input → same HMAC
    byte[] h1 = check crypto:hmacSha256(data, key);
    byte[] h2 = check crypto:hmacSha256(data, key);
    io:println(crypto:equalConstantTime(h1, h2));

    // Different key → different HMAC ("otherkey01234567")
    byte[] key2 = [111, 116, 104, 101, 114, 107, 101, 121, 48, 49, 50, 51, 52, 53, 54, 55];
    byte[] h3 = check crypto:hmacSha256(data, key2);
    io:println(crypto:equalConstantTime(h1, h3));
}
// @output 16
// @output 20
// @output 32
// @output 48
// @output 64
// @output true
// @output false

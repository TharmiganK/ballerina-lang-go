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
    // "input-key-material"
    byte[] ikm = [105, 110, 112, 117, 116, 45, 107, 101, 121, 45, 109, 97, 116, 101, 114, 105, 97, 108];

    // HKDF with default salt/info
    byte[] key32 = check crypto:hkdfSha256(ikm, 32);
    io:println(key32.length());

    // HKDF with salt and info ("mysalt", "myinfo")
    byte[] salt = [109, 121, 115, 97, 108, 116];
    byte[] info = [109, 121, 105, 110, 102, 111];
    byte[] key16 = check crypto:hkdfSha256(ikm, 16, salt, info);
    io:println(key16.length());

    // Same input → same output (deterministic)
    byte[] key32b = check crypto:hkdfSha256(ikm, 32);
    io:println(crypto:equalConstantTime(key32, key32b));

    // Different length → different key
    byte[] key64 = check crypto:hkdfSha256(ikm, 64);
    io:println(key64.length());
}
// @output 32
// @output 16
// @output true
// @output 64

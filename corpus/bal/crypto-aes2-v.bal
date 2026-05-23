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
    // "Ballerina crypto test"
    byte[] data = [66, 97, 108, 108, 101, 114, 105, 110, 97, 32, 99, 114, 121, 112, 116, 111, 32, 116, 101, 115, 116];
    // AES-256 key
    byte[] key256 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15,
                     16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31];
    byte[] iv12 = [10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];

    // AES-256-GCM round-trip
    byte[] enc = check crypto:encryptAesGcm(data, key256, iv12);
    byte[] dec = check crypto:decryptAesGcm(enc, key256, iv12);
    io:println(crypto:equalConstantTime(dec, data));

    // Wrong key fails decryption
    byte[] key256b = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
                      17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32];
    byte[]|crypto:Error result = crypto:decryptAesGcm(enc, key256b, iv12);
    io:println(result is crypto:Error);
}
// @output true
// @output true

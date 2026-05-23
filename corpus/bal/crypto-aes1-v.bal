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
    // "Hello Ballerina!"
    byte[] data = [72, 101, 108, 108, 111, 32, 66, 97, 108, 108, 101, 114, 105, 110, 97, 33];
    byte[] key128 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
    byte[] iv16 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15];
    byte[] iv12 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11];

    // AES-CBC round-trip
    byte[] cbcEnc = check crypto:encryptAesCbc(data, key128, iv16);
    byte[] cbcDec = check crypto:decryptAesCbc(cbcEnc, key128, iv16);
    io:println(crypto:equalConstantTime(cbcDec, data));

    // AES-ECB round-trip
    byte[] ecbEnc = check crypto:encryptAesEcb(data, key128);
    byte[] ecbDec = check crypto:decryptAesEcb(ecbEnc, key128);
    io:println(crypto:equalConstantTime(ecbDec, data));

    // AES-GCM round-trip (default 128-bit tag)
    byte[] gcmEnc = check crypto:encryptAesGcm(data, key128, iv12);
    byte[] gcmDec = check crypto:decryptAesGcm(gcmEnc, key128, iv12);
    io:println(crypto:equalConstantTime(gcmDec, data));

    // AES-GCM ciphertext is longer than plaintext (includes tag)
    io:println(gcmEnc.length() > data.length());
}
// @output true
// @output true
// @output true
// @output true

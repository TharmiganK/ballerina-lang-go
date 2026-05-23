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
    string password = "mySecretPassword123";

    // BCrypt: hash and verify correct password
    string bcryptHash = check crypto:hashBcrypt(password, 4);
    io:println(check crypto:verifyBcrypt(password, bcryptHash));
    io:println(check crypto:verifyBcrypt("wrongPassword", bcryptHash));

    // Argon2id: hash and verify correct password
    string argon2Hash = check crypto:hashArgon2(password, 1, 8192, 1);
    io:println(check crypto:verifyArgon2(password, argon2Hash));
    io:println(check crypto:verifyArgon2("wrongPassword", argon2Hash));

    // PBKDF2-SHA256: hash and verify correct password
    string pbkdf2Hash = check crypto:hashPbkdf2(password, 1000);
    io:println(check crypto:verifyPbkdf2(password, pbkdf2Hash));
    io:println(check crypto:verifyPbkdf2("wrongPassword", pbkdf2Hash));
}
// @output true
// @output false
// @output true
// @output false
// @output true
// @output false

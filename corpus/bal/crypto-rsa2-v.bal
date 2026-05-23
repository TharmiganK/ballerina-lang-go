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
    string keyFile = "testdata/crypto/rsa_private.pem";
    string certFile = "testdata/crypto/rsa_cert.pem";

    crypto:PrivateKey privKey = check crypto:decodeRsaPrivateKeyFromKeyFile(keyFile);
    crypto:PublicKey pubKey = check crypto:decodeRsaPublicKeyFromCertFile(certFile);

    // "Secret message"
    byte[] data = [83, 101, 99, 114, 101, 116, 32, 109, 101, 115, 115, 97, 103, 101];

    // RSA PKCS1 encrypt/decrypt round-trip
    byte[] encrypted = check crypto:encryptRsaEcb(data, pubKey);
    byte[] decrypted = check crypto:decryptRsaEcb(encrypted, privKey);
    io:println(crypto:equalConstantTime(decrypted, data));

    // RSA-SSA-PSS sign and verify
    byte[] pssSig = check crypto:signRsaSsaPss256(data, privKey);
    io:println(check crypto:verifyRsaSsaPss256Signature(data, pssSig, pubKey));

    // Private key algorithm
    io:println(privKey.algorithm);
}
// @output true
// @output true
// @output RSA

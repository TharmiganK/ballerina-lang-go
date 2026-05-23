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

    // "Hello Ballerina"
    byte[] data = [72, 101, 108, 108, 111, 32, 66, 97, 108, 108, 101, 114, 105, 110, 97];

    // RSA-SHA256 sign and verify
    byte[] sig = check crypto:signRsaSha256(data, privKey);
    io:println(sig.length() > 0);
    io:println(check crypto:verifyRsaSha256Signature(data, sig, pubKey));
    // "tampered"
    byte[] tampered = [116, 97, 109, 112, 101, 114, 101, 100];
    io:println(check crypto:verifyRsaSha256Signature(tampered, sig, pubKey));

    // RSA-SHA512 sign and verify
    byte[] sig512 = check crypto:signRsaSha512(data, privKey);
    io:println(check crypto:verifyRsaSha512Signature(data, sig512, pubKey));
}
// @output true
// @output true
// @output false
// @output true

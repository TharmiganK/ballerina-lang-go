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
    string keyFile = "testdata/crypto/ec_private.pem";
    string certFile = "testdata/crypto/ec_cert.pem";

    crypto:PrivateKey ecPrivKey = check crypto:decodeEcPrivateKeyFromKeyFile(keyFile);
    crypto:PublicKey ecPubKey = check crypto:decodeEcPublicKeyFromCertFile(certFile);

    // "ECDSA test data"
    byte[] data = [69, 67, 68, 83, 65, 32, 116, 101, 115, 116, 32, 100, 97, 116, 97];

    // ECDSA SHA-256 sign and verify
    byte[] sig256 = check crypto:signSha256withEcdsa(data, ecPrivKey);
    io:println(sig256.length() > 0);
    io:println(check crypto:verifySha256withEcdsaSignature(data, sig256, ecPubKey));
    // "tampered"
    byte[] tampered = [116, 97, 109, 112, 101, 114, 101, 100];
    io:println(check crypto:verifySha256withEcdsaSignature(tampered, sig256, ecPubKey));

    // ECDSA SHA-384 sign and verify
    byte[] sig384 = check crypto:signSha384withEcdsa(data, ecPrivKey);
    io:println(check crypto:verifySha384withEcdsaSignature(data, sig384, ecPubKey));
}
// @output true
// @output true
// @output false
// @output true

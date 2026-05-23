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

// AES key size in bytes: 16 (AES-128), 24 (AES-192), or 32 (AES-256).
public type AesKeySize 16|24|32;

// Represents the result of a hybrid encryption operation.
//
// + encapsulatedSecret - Encapsulated secret bytes
// + cipherText - Encrypted data bytes
public type HybridEncryptionResult record {|
    byte[] encapsulatedSecret;
    byte[] cipherText;
|};

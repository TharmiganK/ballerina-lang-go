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

# Signs data using RSA with MD5 digest.
#
# + input - Data to sign
# + privateKey - RSA private key
# + return - Signature bytes or an Error
public isolated function signRsaMd5(byte[] input, PrivateKey privateKey) returns byte[]|Error = external;

# Signs data using RSA with SHA-1 digest.
#
# + input - Data to sign
# + privateKey - RSA private key
# + return - Signature bytes or an Error
public isolated function signRsaSha1(byte[] input, PrivateKey privateKey) returns byte[]|Error = external;

# Signs data using RSA with SHA-256 digest.
#
# + input - Data to sign
# + privateKey - RSA private key
# + return - Signature bytes or an Error
public isolated function signRsaSha256(byte[] input, PrivateKey privateKey) returns byte[]|Error = external;

# Signs data using RSA with SHA-384 digest.
#
# + input - Data to sign
# + privateKey - RSA private key
# + return - Signature bytes or an Error
public isolated function signRsaSha384(byte[] input, PrivateKey privateKey) returns byte[]|Error = external;

# Signs data using RSA with SHA-512 digest.
#
# + input - Data to sign
# + privateKey - RSA private key
# + return - Signature bytes or an Error
public isolated function signRsaSha512(byte[] input, PrivateKey privateKey) returns byte[]|Error = external;

# Signs data using RSA-SSA-PSS with SHA-256 digest and MGF1.
#
# + input - Data to sign
# + privateKey - RSA private key
# + return - Signature bytes or an Error
public isolated function signRsaSsaPss256(byte[] input, PrivateKey privateKey) returns byte[]|Error = external;

# Signs data using ECDSA with SHA-256 digest.
#
# + input - Data to sign
# + privateKey - EC private key
# + return - DER-encoded signature bytes or an Error
public isolated function signSha256withEcdsa(byte[] input, PrivateKey privateKey) returns byte[]|Error = external;

# Signs data using ECDSA with SHA-384 digest.
#
# + input - Data to sign
# + privateKey - EC private key
# + return - DER-encoded signature bytes or an Error
public isolated function signSha384withEcdsa(byte[] input, PrivateKey privateKey) returns byte[]|Error = external;

# Verifies an RSA-MD5 signature.
#
# + data - Original data
# + signature - Signature bytes to verify
# + publicKey - RSA public key
# + return - true if the signature is valid, or an Error
public isolated function verifyRsaMd5Signature(byte[] data, byte[] signature, PublicKey publicKey)
        returns boolean|Error = external;

# Verifies an RSA-SHA-1 signature.
#
# + data - Original data
# + signature - Signature bytes to verify
# + publicKey - RSA public key
# + return - true if the signature is valid, or an Error
public isolated function verifyRsaSha1Signature(byte[] data, byte[] signature, PublicKey publicKey)
        returns boolean|Error = external;

# Verifies an RSA-SHA-256 signature.
#
# + data - Original data
# + signature - Signature bytes to verify
# + publicKey - RSA public key
# + return - true if the signature is valid, or an Error
public isolated function verifyRsaSha256Signature(byte[] data, byte[] signature, PublicKey publicKey)
        returns boolean|Error = external;

# Verifies an RSA-SHA-384 signature.
#
# + data - Original data
# + signature - Signature bytes to verify
# + publicKey - RSA public key
# + return - true if the signature is valid, or an Error
public isolated function verifyRsaSha384Signature(byte[] data, byte[] signature, PublicKey publicKey)
        returns boolean|Error = external;

# Verifies an RSA-SHA-512 signature.
#
# + data - Original data
# + signature - Signature bytes to verify
# + publicKey - RSA public key
# + return - true if the signature is valid, or an Error
public isolated function verifyRsaSha512Signature(byte[] data, byte[] signature, PublicKey publicKey)
        returns boolean|Error = external;

# Verifies an RSA-SSA-PSS-256 signature.
#
# + data - Original data
# + signature - Signature bytes to verify
# + publicKey - RSA public key
# + return - true if the signature is valid, or an Error
public isolated function verifyRsaSsaPss256Signature(byte[] data, byte[] signature, PublicKey publicKey)
        returns boolean|Error = external;

# Verifies an ECDSA signature with SHA-256 digest.
#
# + data - Original data
# + signature - DER-encoded signature bytes to verify
# + publicKey - EC public key
# + return - true if the signature is valid, or an Error
public isolated function verifySha256withEcdsaSignature(byte[] data, byte[] signature, PublicKey publicKey)
        returns boolean|Error = external;

# Verifies an ECDSA signature with SHA-384 digest.
#
# + data - Original data
# + signature - DER-encoded signature bytes to verify
# + publicKey - EC public key
# + return - true if the signature is valid, or an Error
public isolated function verifySha384withEcdsaSignature(byte[] data, byte[] signature, PublicKey publicKey)
        returns boolean|Error = external;

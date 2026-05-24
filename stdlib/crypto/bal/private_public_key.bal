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

import ballerina/time;

// Key algorithm RSA.
public const RSA = "RSA";

// Key algorithm ML-KEM-768 (post-quantum).
public const MLKEM768 = "ML-KEM-768";

// Key algorithm ML-DSA-65 (post-quantum).
public const MLDSA65 = "ML-DSA-65";

// Represents the key algorithm.
public type KeyAlgorithm RSA|MLKEM768|MLDSA65;

// Represents a KeyStore.
//
// + path - Path to the KeyStore file
// + password - KeyStore password
public type KeyStore record {|
    string path;
    string password;
|};

// Represents a TrustStore.
//
// + path - Path to the TrustStore file
// + password - TrustStore password
public type TrustStore record {|
    string path;
    string password;
|};

// Represents a private key.
//
// + algorithm - Key algorithm
public type PrivateKey record {|
    KeyAlgorithm algorithm;
    never...;
|};

// Represents a public key.
//
// + algorithm - Key algorithm
// + certificate - Public key certificate
public type PublicKey record {|
    KeyAlgorithm algorithm;
    Certificate? certificate = ();
    never...;
|};

// Represents a public key certificate.
//
// + version - Certificate version
// + serial - Certificate serial number
// + issuer - Certificate issuer name
// + subject - Certificate subject name
// + notBefore - Certificate validity start time
// + notAfter - Certificate validity end time
// + signature - Certificate signature bytes
// + signingAlgorithm - Certificate signing algorithm OID
public type Certificate record {|
    int version;
    int serial;
    string issuer;
    string subject;
    time:Utc notBefore;
    time:Utc notAfter;
    byte[] signature;
    string signingAlgorithm;
|};

# Decodes an RSA private key from a PKCS12 KeyStore.
#
# + keyStore - KeyStore record with path and password
# + keyAlias - Alias of the key entry
# + keyPassword - Password of the key entry
# + return - PrivateKey or an Error
public isolated function decodeRsaPrivateKeyFromKeyStore(KeyStore keyStore, string keyAlias, string keyPassword)
        returns PrivateKey|Error = external;

# Decodes an EC private key from a PKCS12 KeyStore.
#
# + keyStore - KeyStore record with path and password
# + keyAlias - Alias of the key entry
# + keyPassword - Password of the key entry
# + return - PrivateKey or an Error
public isolated function decodeEcPrivateKeyFromKeyStore(KeyStore keyStore, string keyAlias, string keyPassword)
        returns PrivateKey|Error = external;

# Decodes an RSA private key from a PEM key file.
#
# + keyFile - Path to the key file
# + keyPassword - Optional password for encrypted keys
# + return - PrivateKey or an Error
public isolated function decodeRsaPrivateKeyFromKeyFile(string keyFile, string? keyPassword = ())
        returns PrivateKey|Error = external;

# Decodes an RSA private key from PEM-encoded content.
#
# + content - PEM-encoded key bytes
# + keyPassword - Optional password for encrypted keys
# + return - PrivateKey or an Error
public isolated function decodeRsaPrivateKeyFromContent(byte[] content, string? keyPassword = ())
        returns PrivateKey|Error = external;

# Decodes an EC private key from a PEM key file.
#
# + keyFile - Path to the key file
# + keyPassword - Optional password for encrypted keys
# + return - PrivateKey or an Error
public isolated function decodeEcPrivateKeyFromKeyFile(string keyFile, string? keyPassword = ())
        returns PrivateKey|Error = external;

# Decodes an RSA public key from a PKCS12 TrustStore.
#
# + trustStore - TrustStore record with path and password
# + keyAlias - Alias of the key entry
# + return - PublicKey or an Error
public isolated function decodeRsaPublicKeyFromTrustStore(TrustStore trustStore, string keyAlias)
        returns PublicKey|Error = external;

# Decodes an EC public key from a PKCS12 TrustStore.
#
# + trustStore - TrustStore record with path and password
# + keyAlias - Alias of the key entry
# + return - PublicKey or an Error
public isolated function decodeEcPublicKeyFromTrustStore(TrustStore trustStore, string keyAlias)
        returns PublicKey|Error = external;

# Decodes an RSA public key from a PEM certificate file.
#
# + certFile - Path to the certificate file
# + return - PublicKey or an Error
public isolated function decodeRsaPublicKeyFromCertFile(string certFile) returns PublicKey|Error = external;

# Decodes an RSA public key from PEM-encoded content.
#
# + content - PEM-encoded certificate bytes
# + return - PublicKey or an Error
public isolated function decodeRsaPublicKeyFromContent(byte[] content) returns PublicKey|Error = external;

# Decodes an EC public key from a PEM certificate file.
#
# + certFile - Path to the certificate file
# + return - PublicKey or an Error
public isolated function decodeEcPublicKeyFromCertFile(string certFile) returns PublicKey|Error = external;

# Builds an RSA public key from a modulus and exponent encoded as hexadecimal strings.
#
# + modulus - Hex-encoded modulus
# + exponent - Hex-encoded public exponent
# + return - PublicKey or an Error
public isolated function buildRsaPublicKey(string modulus, string exponent) returns PublicKey|Error = external;

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

// No padding.
public const NONE = "NONE";

// PKCS5 padding (equivalent to PKCS7 in AES context).
public const PKCS5 = "PKCS5";

// RSA PKCS#1 v1.5 padding.
public const PKCS1 = "PKCS1";

// RSA OAEP with MD5 and MGF1 padding.
public const OAEPwithMD5andMGF1 = "OAEPwithMD5andMGF1";

// RSA OAEP with SHA-1 and MGF1 padding.
public const OAEPWithSHA1AndMGF1 = "OAEPWithSHA1AndMGF1";

// RSA OAEP with SHA-256 and MGF1 padding.
public const OAEPWithSHA256AndMGF1 = "OAEPWithSHA256AndMGF1";

// RSA OAEP with SHA-384 and MGF1 padding.
public const OAEPwithSHA384andMGF1 = "OAEPwithSHA384andMGF1";

// RSA OAEP with SHA-512 and MGF1 padding.
public const OAEPwithSHA512andMGF1 = "OAEPwithSHA512andMGF1";

// AES padding mode.
public type AesPadding NONE|PKCS5;

// RSA padding mode.
public type RsaPadding PKCS1|OAEPwithMD5andMGF1|OAEPWithSHA1AndMGF1|OAEPWithSHA256AndMGF1|OAEPwithSHA384andMGF1|OAEPwithSHA512andMGF1;

# Encrypts a byte array using RSA in ECB mode.
#
# + input - Data to encrypt
# + key - RSA public or private key
# + padding - RSA padding mode; defaults to PKCS1
# + return - Encrypted bytes or an Error
public isolated function encryptRsaEcb(byte[] input, PrivateKey|PublicKey key, RsaPadding padding = PKCS1)
        returns byte[]|Error = external;

# Encrypts a byte array using AES in CBC mode.
#
# + input - Data to encrypt
# + key - AES key bytes (16, 24, or 32 bytes)
# + iv - Initialization vector (16 bytes)
# + padding - AES padding mode; defaults to PKCS5
# + return - Encrypted bytes or an Error
public isolated function encryptAesCbc(byte[] input, byte[] key, byte[] iv, AesPadding padding = PKCS5)
        returns byte[]|Error = external;

# Encrypts a byte array using AES in ECB mode.
#
# + input - Data to encrypt
# + key - AES key bytes (16, 24, or 32 bytes)
# + padding - AES padding mode; defaults to PKCS5
# + return - Encrypted bytes or an Error
public isolated function encryptAesEcb(byte[] input, byte[] key, AesPadding padding = PKCS5)
        returns byte[]|Error = external;

# Encrypts a byte array using AES in GCM mode.
#
# + input - Data to encrypt
# + key - AES key bytes (16, 24, or 32 bytes)
# + iv - Initialization vector (12 bytes recommended)
# + padding - AES padding mode; defaults to NONE
# + tagSize - Authentication tag size in bits; defaults to 128
# + return - Encrypted bytes (ciphertext + tag) or an Error
public isolated function encryptAesGcm(byte[] input, byte[] key, byte[] iv, AesPadding padding = NONE,
        int tagSize = 128) returns byte[]|Error = external;

# Decrypts a byte array using RSA in ECB mode.
#
# + input - Data to decrypt
# + key - RSA public or private key
# + padding - RSA padding mode; defaults to PKCS1
# + return - Decrypted bytes or an Error
public isolated function decryptRsaEcb(byte[] input, PrivateKey|PublicKey key, RsaPadding padding = PKCS1)
        returns byte[]|Error = external;

# Decrypts a byte array using AES in CBC mode.
#
# + input - Data to decrypt
# + key - AES key bytes (16, 24, or 32 bytes)
# + iv - Initialization vector (16 bytes)
# + padding - AES padding mode; defaults to PKCS5
# + return - Decrypted bytes or an Error
public isolated function decryptAesCbc(byte[] input, byte[] key, byte[] iv, AesPadding padding = PKCS5)
        returns byte[]|Error = external;

# Decrypts a byte array using AES in ECB mode.
#
# + input - Data to decrypt
# + key - AES key bytes (16, 24, or 32 bytes)
# + padding - AES padding mode; defaults to PKCS5
# + return - Decrypted bytes or an Error
public isolated function decryptAesEcb(byte[] input, byte[] key, AesPadding padding = PKCS5)
        returns byte[]|Error = external;

# Decrypts a byte array using AES in GCM mode.
#
# + input - Data to decrypt (ciphertext + tag)
# + key - AES key bytes (16, 24, or 32 bytes)
# + iv - Initialization vector used during encryption
# + padding - AES padding mode; defaults to PKCS5 (ignored in GCM)
# + tagSize - Authentication tag size in bits; defaults to 128
# + return - Decrypted bytes or an Error
public isolated function decryptAesGcm(byte[] input, byte[] key, byte[] iv, AesPadding padding = PKCS5,
        int tagSize = 128) returns byte[]|Error = external;

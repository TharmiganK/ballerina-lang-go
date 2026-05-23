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

// Algorithms supported by HMAC and PBKDF2 operations.
public enum HmacAlgorithm {
    SHA1,
    SHA256,
    SHA512
}

# Returns the MD5 hash of the given data, optionally with a salt prepended.
#
# + input - Value to be hashed
# + salt - Optional salt prepended before hashing
# + return - MD5 hash bytes
public isolated function hashMd5(byte[] input, byte[]? salt = ()) returns byte[] = external;

# Returns the SHA-1 hash of the given data, optionally with a salt prepended.
#
# + input - Value to be hashed
# + salt - Optional salt prepended before hashing
# + return - SHA-1 hash bytes
public isolated function hashSha1(byte[] input, byte[]? salt = ()) returns byte[] = external;

# Returns the SHA-256 hash of the given data, optionally with a salt prepended.
#
# + input - Value to be hashed
# + salt - Optional salt prepended before hashing
# + return - SHA-256 hash bytes
public isolated function hashSha256(byte[] input, byte[]? salt = ()) returns byte[] = external;

# Returns the SHA-384 hash of the given data, optionally with a salt prepended.
#
# + input - Value to be hashed
# + salt - Optional salt prepended before hashing
# + return - SHA-384 hash bytes
public isolated function hashSha384(byte[] input, byte[]? salt = ()) returns byte[] = external;

# Returns the SHA-512 hash of the given data, optionally with a salt prepended.
#
# + input - Value to be hashed
# + salt - Optional salt prepended before hashing
# + return - SHA-512 hash bytes
public isolated function hashSha512(byte[] input, byte[]? salt = ()) returns byte[] = external;

# Returns the Keccak-256 hash of the given data, optionally with a salt prepended.
#
# + input - Value to be hashed
# + salt - Optional salt prepended before hashing
# + return - Keccak-256 hash bytes
public isolated function hashKeccak256(byte[] input, byte[]? salt = ()) returns byte[] = external;

# Returns the CRC32B checksum of the given data as a hexadecimal string.
#
# + input - Value to be checksummed
# + return - CRC32B checksum hex string
public isolated function crc32b(byte[] input) returns string = external;

# Hashes a password using BCrypt.
#
# + password - Password string to hash
# + workFactor - BCrypt work factor (cost); defaults to 12
# + return - BCrypt hash string or an Error
public isolated function hashBcrypt(string password, int workFactor = 12) returns string|Error = external;

# Verifies a password against a BCrypt hash.
#
# + password - Password string to verify
# + hashedPassword - BCrypt hash string to compare against
# + return - true if the password matches, or an Error
public isolated function verifyBcrypt(string password, string hashedPassword) returns boolean|Error = external;

# Hashes a password using Argon2id.
#
# + password - Password string to hash
# + iterations - Number of iterations; defaults to 3
# + memory - Memory in KiB; defaults to 65536
# + parallelism - Degree of parallelism; defaults to 4
# + return - Argon2id hash string or an Error
public isolated function hashArgon2(string password, int iterations = 3, int memory = 65536, int parallelism = 4)
        returns string|Error = external;

# Verifies a password against an Argon2id hash.
#
# + password - Password string to verify
# + hashedPassword - Argon2id hash string to compare against
# + return - true if the password matches, or an Error
public isolated function verifyArgon2(string password, string hashedPassword) returns boolean|Error = external;

# Hashes a password using PBKDF2.
#
# + password - Password string to hash
# + iterations - Number of iterations; defaults to 10000
# + algorithm - HMAC algorithm to use; defaults to SHA256
# + return - PBKDF2 hash string or an Error
public isolated function hashPbkdf2(string password, int iterations = 10000, HmacAlgorithm algorithm = SHA256)
        returns string|Error = external;

# Verifies a password against a PBKDF2 hash.
#
# + password - Password string to verify
# + hashedPassword - PBKDF2 hash string to compare against
# + return - true if the password matches, or an Error
public isolated function verifyPbkdf2(string password, string hashedPassword) returns boolean|Error = external;

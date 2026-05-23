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

# Returns the HMAC using the MD5 hash function of the given data.
#
# + input - Value to be HMAC-ed
# + key - Key used for HMAC generation
# + return - HMAC bytes or an Error
public isolated function hmacMd5(byte[] input, byte[] key) returns byte[]|Error = external;

# Returns the HMAC using the SHA-1 hash function of the given data.
#
# + input - Value to be HMAC-ed
# + key - Key used for HMAC generation
# + return - HMAC bytes or an Error
public isolated function hmacSha1(byte[] input, byte[] key) returns byte[]|Error = external;

# Returns the HMAC using the SHA-256 hash function of the given data.
#
# + input - Value to be HMAC-ed
# + key - Key used for HMAC generation
# + return - HMAC bytes or an Error
public isolated function hmacSha256(byte[] input, byte[] key) returns byte[]|Error = external;

# Returns the HMAC using the SHA-384 hash function of the given data.
#
# + input - Value to be HMAC-ed
# + key - Key used for HMAC generation
# + return - HMAC bytes or an Error
public isolated function hmacSha384(byte[] input, byte[] key) returns byte[]|Error = external;

# Returns the HMAC using the SHA-512 hash function of the given data.
#
# + input - Value to be HMAC-ed
# + key - Key used for HMAC generation
# + return - HMAC bytes or an Error
public isolated function hmacSha512(byte[] input, byte[] key) returns byte[]|Error = external;

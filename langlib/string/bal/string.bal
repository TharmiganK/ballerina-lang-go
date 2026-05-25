// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
//
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

public type Char string;

public isolated function length(string str) returns int = external;

public isolated function toBytes(string str) returns byte[] = external;

public isolated function fromBytes(byte[] bytes) returns string|error = external;

public isolated function substring(string str, int startIndex, int endIndex = length(str)) returns string = external;

public isolated function equalsIgnoreCaseAscii(string str1, string str2) returns boolean = external;

public isolated function toLowerAscii(string str) returns string = external;

public isolated function toUpperAscii(string str) returns string = external;

public isolated function trim(string str) returns string = external;

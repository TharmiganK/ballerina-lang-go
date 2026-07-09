// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
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
import ballerina/io;

public function main() {
    int[3] numbers = [144, 232, 322];
    // `numbers`, of type `int[3]`, will be a subtype of `int[]`
    // since `T[n]` is a subtype of `T[]`
    io:println(numbers is int[]);

    byte[3] numbers2 = [1, 2, 3];
    // `numbers2`, of type byte[3], will be a subtype of `int[3]`
    // since `byte` is a subtype of `int` and lengths are the same
    io:println(numbers2 is int[3]);
    
    // `numbers2`, of type byte[3], will be a subtype of `int[]`
    // since `byte` is a subtype of `int` and `T[n]` is a subtype of `T[]`
    io:println(numbers2 is int[]);

    [byte, string] person = [1, "Mike"];
    // `[byte, string]` is a subtype of `[int, anydata]`
    io:println(person is [int, anydata]);
    
    // `[byte, string]` is a subtype of `[int, anydata...]`
    io:println(person is [int, anydata...]);
    
    // `int[3]` is a subtype of `[int, anydata...]`
    io:println(numbers is [int, anydata...]);
}

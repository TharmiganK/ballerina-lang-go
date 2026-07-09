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

// The `decimal` type represents the set of 128-bits IEEE 754R decimal floating point numbers.
decimal nanos = 1d/1000000000d;

function floatSurprise() {
    float f = 100.10 - 0.01;
    io:println(f);
}

public function main() {
    floatSurprise();
    io:println(nanos);

    // Numeric literals can use `d` or `D` suffix for them to be interpreted as `decimal` values.
    // (Similarly, the `f` or `F` suffix can be used for `float`).
    var d = 12345d;
    io:println(d is decimal);
}

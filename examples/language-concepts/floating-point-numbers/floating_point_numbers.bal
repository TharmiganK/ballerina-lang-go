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
    float x = 1.0;

    int n = 5;

    // Numeric literals can use `f` or `F` suffix for them to be interpreted as `float` values.
    // (Similarly, the `d` or `D` suffix can be used for `decimal`).
    var f = 12345f;
    io:println(f is float);

    // No implicit conversions between integers and floating point values are allowed.
    // You can use `<T>` for explicit conversions.
    float y = x + <float>n;

    io:println(y);
}

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

// This function definition has two parameters of type `int`.
// The `returns` clause specifies the type of the return value.
function add(int x, int y) returns int {
    int sum = x + y;
    // The `return` statement returns a value.
    return sum;
}

// The function parameters can have default values.
function calculateWeight(decimal mass, decimal gForce = 9.8) returns decimal {
    return mass * gForce;
}

// The function returns `nil`.
function print(anydata data) {
    io:println(data);
}

public function main() {
    // Invoke the function `add` by passing the arguments.
    int sum = add(5, 11);
    // A function with no return type does not need a variable assignment.
    print(sum);

    // Invoke the `calculateWeight` function with the default arguments.
    print(calculateWeight(5));

    // Invoke the `add` function with the named arguments.
    print(add(x = 5, y = 6));

    // The return value of the function can be ignored by assigning it to `_`.
    _ = calculateWeight(mass = 5, gForce = 10);
}

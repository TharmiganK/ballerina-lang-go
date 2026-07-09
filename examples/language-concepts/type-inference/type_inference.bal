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

// `var` says that the type of the variable is from the type of expression, which is used to initialize it.
var x = "str";

function printLines(string[] sv) {
    // Type inference with a `foreach` statement.
    foreach var s in sv {
        io:println(s);
    }

}

public function main() {
    string[] s = [x, x];
    printLines(s);

    // Infers `x`'s type as `MyClass`.
    var x = new MyClass();
    MyClass _ = x;

    // Infers the class for `new` as `MyClass`.
    MyClass _ = new;

}

class MyClass {
    function foo() {

    }
}

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

class Engineer {
    // A `final` field must be assigned exactly once.
    final string name;

    int age;

    // The `init` method initializes the object.
    function init(string name, int age) {
        // The `init` method can initialize the `final` field.
        self.name = name;
        self.age = age;
    }

    function getName() returns string {
        // Methods use `self` to access their fields.
        return self.name;
    }

    function getAge() returns int {
        return self.age;
    }
}

public function main() {
    // Arguments to `new` are passed as arguments to `init`.
    Engineer engineer = new Engineer("Alice", 52);

    io:println(engineer.getName());
    io:println(engineer.getAge());
}

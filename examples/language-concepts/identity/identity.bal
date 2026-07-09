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

class MyClass {
    int i = 0;
}

public function main() {
    MyClass obj1 = new MyClass();
    MyClass obj2 = new MyClass();
    
    // `b1` will be true.
    boolean b1 = (obj1 === obj1);
    io:println(b1);

    // `b2` will be false.
    boolean b2 = (obj1 === obj2);
    io:println(b2);

    // `b3` will be true.
    boolean b3 = ([1, 2, 3] == [1, 2, 3]);
    io:println(b3);

    // `b4` will be false.
    boolean b4 = ([1, 2, 3] === [1, 2, 3]);
    io:println(b4);

    // `b5` will be true.
    boolean b5 = (-0.0 == +0.0);
    io:println(b5);

    // `b6` will be false.
    boolean b6 = (-0.0 === +0.0);
    io:println(b6);
}

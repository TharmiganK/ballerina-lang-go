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

// Defines a class called `EvenNumberGenerator`, which implements the `next()` method.
// This will be invoked when the `next()` method of the stream gets invoked.
class EvenNumberGenerator {
    int i = 0;
    public isolated function next() returns record {|int value;|}|error? {
        self.i += 2;
        return {value: self.i};
    }
}

public function main() {
    EvenNumberGenerator evenGen = new ();

    // Creates a `stream` passing an `EvenNumberGenerator` object to the `stream` constructor.
    stream<int, error?> evenNumberStream = new (evenGen);

    var evenNumber = evenNumberStream.next();

    if (evenNumber !is error?) {
        io:println("Retrieved even number: ", evenNumber.value);
    }
}

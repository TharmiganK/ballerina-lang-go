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

type Options record {|
    boolean verbose = false;
    string? outputFile = ();
|};

// `foo` has a string parameter `inputFile` and an included record parameter of the
// `Options` record type.
function foo(string inputFile, *Options options) {
    io:println("Input File:", inputFile);
    io:println("Options:", options);
}

public function main() {
    // Call `foo()` by directly passing a value of the `Options` record type.
    foo("file.txt", {verbose: true});

    // Pass named arguments having the same names as the fields in the `Options` record.
    foo("file.txt", verbose = true);
}

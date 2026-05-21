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

# Prints `any` or `error` to the standard output stream.
# ```ballerina
# io:print("Start processing the CSV file from ", srcFileName);
# ```
#
# + values - The value(s) to be printed
public isolated function print(Printable... values) {
    externPrint(stdout, false, values);
}


# Prints `any` or `error` to the standard output stream and terminates the line.
# ```ballerina
# io:println("Start processing the CSV file from ", srcFileName);
# ```
#
# + values - The value(s) to be printed
public isolated function println(Printable... values) {
    externPrint(stdout, true, values);
}

# Prints `any`, `error`, or string templates value(s) to a given stream(STDOUT or STDERR).
# ```ballerina
# io:fprint(io:stderr, "Unexpected error occurred");
# ```
# + fileOutputStream - The output stream (`io:stdout` or `io:stderr`) content needs to be printed
# + values - The value(s) to be printed
public isolated function fprint(FileOutputStream fileOutputStream, Printable... values) {
    externPrint(fileOutputStream, false, values);
}

# Prints `any`, `error`, or string templates value(s) to a given stream(STDOUT or STDERR) and terminates the line.
# ```ballerina
# io:fprintln(io:stderr, "Unexpected error occurred");
# ```
# + fileOutputStream - The output stream (`io:stdout` or `io:stderr`) content needs to be printed
# + values - The value(s) to be printed
public isolated function fprintln(FileOutputStream fileOutputStream, Printable... values) {
    externPrint(fileOutputStream, true, values);
}

isolated function externPrint(FileOutputStream fileOutputStream, boolean newLine, Printable... values) = external;

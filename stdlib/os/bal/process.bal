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

public class Process {

    # Waits for the subprocess to exit and returns its exit code.
    # Returns `0` for a successful exit; a non-zero value otherwise.
    #
    # + return - Exit code of the subprocess, or an `os:Error` if waiting fails
    public isolated function waitForExit() returns int|Error = external;

    # Returns the output of the subprocess as a byte array.
    # If the process has not yet exited, this call waits for it to finish first.
    #
    # + fileOutputStream - The output stream to read: `io:stdout` (default) or `io:stderr`
    # + return - Output bytes, or an `os:Error` if reading fails
    public isolated function output(io:FileOutputStream fileOutputStream = io:stdout) returns byte[]|Error = external;

    # Terminates the subprocess immediately.
    public isolated function exit() = external;
}

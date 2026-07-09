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

const switchStatus = "ON";

function matchValue(any val, boolean isObstructed, float powerPercentage) returns string {
    // The value of the `val` variable is matched against the given value match patterns.
    match val {
        // The `if !isObstructed` match guard is used.
        1 if !isObstructed => {
            // This block will execute if `!isObstructed` is true.
            return "Move forward";
        }
        // Use `|` to match more than one value.
        2|3 => {
            return "Turn";
        }
        //The `if 25.0 < powerPercentage` match guard is used.
        4 if 25.0 < powerPercentage => {
            // This block will execute if `25.0 < powerPercentage` is true.
            return  "Increase speed";
        }
        "STOP" => {
            return "STOP";
        }
        switchStatus => {
            return "Switch ON";
        }
        // Use `_` to match type `any`.
        _ => {
            return "Invalid instruction";
        }
    }
}

public function main() {
    io:println(matchValue(1, false, 36.0));
    io:println(matchValue(4, false, 36.0));
}

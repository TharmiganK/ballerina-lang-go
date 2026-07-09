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
    // Since the filler value for int is `0`,
    // the `severity` array will be initialized as [0, 0, 0].
    int[3] severity = [];
    io:println(severity);
 
    // Since the filler value for `boolean` is `false` and the rest type can contain no members,
    // the `scores` will be initialized as `[false]`.
    [boolean, int...] scores = [];
    io:println(scores);
 
    // As the filler value for string is `""`,
    // the `names` array will be initialized as ["John", "Mike", ""].
    string[3] names = ["John", "Mike"];
    io:println(names);
 
    // As the filler value for the list is an empty list,
    // the `orderItems` tuple will be initialized as `[["carrot", "apple"], ["avacado", "egg"], ["", ""]]``.
    string[3][2] orderItems = [["carrot", "apple"], ["avocado", "egg"]];
    io:println(orderItems);
}

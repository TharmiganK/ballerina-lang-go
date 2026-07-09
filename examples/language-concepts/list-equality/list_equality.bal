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
    int[] a = [1];
    int[1] b = [1];
    // Output will be `true` as the values are the same.
    io:println(a == b);
    
    // Output will be `false` as the references are different.
    io:println(a === b);
    
    // Output will be `true` as the references are the same.
    io:println(a === a);
    
    // This will assign the reference `a` to `c`.
    int[] c = a;
    // Output will be `true` as the references are the same.
    io:println(a === c);

    string[3][2] orderItems = [["carrot", "apple"], ["avacado", "egg"], ["fish", "banana"]];
    string[3][2] orderItems2 = [["carrot", "apple"], ["avacado", "egg"], ["fish", "banana"]];
    // Output will be `true` as the order items are the same.
    io:println(orderItems == orderItems2);
    
    // Output will be `false` as the order items are the same.
    io:println(orderItems != orderItems2);
    
    // Output will be `true` as the references are different.
    io:println(orderItems !== orderItems2);

    string[3][2] orderItems3 = [["avacado", "egg"], ["carrot", "apple"], ["fish", "banana"]];
    // Output will be `false` as the order of the items are different.
    io:println(orderItems == orderItems3);
}

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

string url = "https://ballerina.io";

// `xml` values can be constructed using an XML template expression.
// Attribute values can have `string` values as interpolated expressions.
xml content = xml `<a href="${url}">Ballerina</a> is an <em>exciting</em> new language!`;

// Interpolated expressions can also be in content (`xml` or `string` values).
xml p = xml `<p>${content}</p>`;

public function main() {
    io:println(content);
    io:println(p);
}

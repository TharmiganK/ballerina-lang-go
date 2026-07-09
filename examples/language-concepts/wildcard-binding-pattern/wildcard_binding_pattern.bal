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
public function main() {
    // Since the basic type of the value returned by `getInt()` is `int`
    // which belongs to `any` type, this will not cause an assignment.
    int _ = getInt();

    // The type of the wildcard binding pattern is  derived as `any`
    // since it results in a successful match.
    _ = 3;
}

function getInt() returns int {
    return 0;
}


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

type R record {
    int v;
};

// The initialization expression of an `isolated` variable
// has to be an `isolated` expression, which itself will be
// an `isolated` root.
isolated R r = {v: 0};

isolated function setGlobal(int n) {
    // An `isolated` variable can be accessed within
    // a `lock` statement.
    lock {
        r.v = n;
    }
}

public function main() {
    setGlobal(200);
    // Accesses the `isolated` variable within a
    // `lock` statement.
    lock {
       io:println(r);
    }
}

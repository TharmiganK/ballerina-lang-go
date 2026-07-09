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

// An `isolated` object’s mutable state is `isolated` from the
// rest of the program.
isolated class Counter {
    // `n` is a mutable field.
    private int n = 0;

    isolated function get() returns int {
        lock {
            // `n` can only be accessed using `self`.
            return self.n;
        }
    }

    isolated function inc() {
        lock {
            self.n += 1;
        }
    }
}

public function main() {
    // The object’s mutable state is accessible only via the
    // object itself making it an “isolated root”.
    Counter c = new;
    c.inc();
    int v = c.get();
    io:println(v);
}

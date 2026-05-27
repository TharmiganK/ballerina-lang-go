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

import ballerina/http;
import ballerina/io;

service /echo on new http:Listener(19092) {
    resource function post body(http:Request req) returns http:Response|error {
        json payload = check req.getJsonPayload();
        http:Response resp = new;
        resp.setJsonPayload(payload);
        return resp;
    }
}

public function main() {
    io:println("ok"); // @output ok
}

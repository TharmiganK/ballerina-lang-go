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
import ballerina/log;

// Shared networking baseline (see performance/README.md): unlimited active
// connections; idle pool sized to 512 — above the suite's 500-user peak so
// backend keep-alive connections are reused rather than evicted and re-dialed
// between requests. This matches the effectively-unlimited pools of the
// runtimes whose HTTP stacks expose no idle cap (Netty, Reactor Netty, aiohttp,
// .NET SocketsHttpHandler); applied uniformly so passthrough stays comparable.
final http:Client nettyEP = checkpanic new ("http://localhost:8688", {
    httpVersion: "1.1",
    poolConfig: {
        maxActiveConnections: -1,
        maxIdleConnections: 512
    }
});

listener http:Listener httpListener = new (9090, {
    httpVersion: "1.1"
});

service /passthrough on httpListener {

    isolated resource function post .(http:Request req) returns http:Response|error {
        http:Response|error result = nettyEP->forward("/", req);
        if result is error {
            log:printError("Error forwarding request", 'error = result);
        }
        return result;
    }
}

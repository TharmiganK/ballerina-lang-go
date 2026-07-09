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
import ballerina/log;

public function main() {
    // These log messages will be formatted and filtered according to Config.toml
    log:printDebug("Debug message - application initialization");
    log:printInfo("Application started", version = "1.0.0");
    log:printWarn("High memory usage detected", memoryUsage = "85%");
    log:printError("Failed to connect to external service", serviceName = "PaymentAPI", timeout = "30s");

    // Logs will include the root context configured in Config.toml
    log:printInfo("User session created", userId = "user123", sessionId = "sess-456");
}

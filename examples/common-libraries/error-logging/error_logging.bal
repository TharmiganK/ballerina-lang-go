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

function processOrder(int orderId) returns error? {
    if orderId <= 0 {
        return error("Invalid order ID", orderId = orderId);
    }
    // Simulate processing logic here
}

function connectToDatabase() returns error? {
    error dbError = error("Connection timeout");
    return error("Failed to connect to database", dbError, retryCount = 3);
}

public function main() {
    // Basic error logging
    error simpleError = error("Something went wrong");
    log:printError("Application encountered an error", simpleError);

    // Error logging with additional context
    error? processOrderRes = processOrder(-1);
    if processOrderRes is error {
        log:printError("Order processing failed", processOrderRes,
                operation = "processOrder",
                timestamp = "2025-08-25T10:30:00Z");
    }

    // Error with causes and stack trace
    error? databaseConnectionRes = connectToDatabase();
    if databaseConnectionRes is error {
        log:printError("Database operation failed", databaseConnectionRes,
                serviceName = "OrderService",
                severity = "HIGH");
    }

    // Custom error with detailed information
    error customError = error("Validation failed",
                            'field = "email",
                            value = "invalid-email",
                            expectedFormat = "user@domain.com");
    log:printError("User input validation error", customError,
            userId = "user123",
            action = "registration");
}

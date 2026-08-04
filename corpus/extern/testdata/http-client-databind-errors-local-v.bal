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

type Person record {|
    string name;
    int age;
|};

public function main() returns error? {
    http:Client c = check new http:Client("http://testserver", {});

    // A 4xx response becomes an error whose message is the reason phrase.
    Person|error notFound = c->get("/missing");
    if notFound is error {
        io:println("4xx: ", notFound.message()); // @output 4xx: Not Found
    }

    // A 5xx response likewise.
    Person|error serverErr = c->get("/boom");
    if serverErr is error {
        io:println("5xx: ", serverErr.message()); // @output 5xx: Internal Server Error
    }

    // An http:Response target bypasses the status-code mapping entirely.
    http:Response raw = check c->get("/missing");
    io:println(raw.statusCode); // @output 404

    // A 3xx response is not an error, so binding still runs.
    string redirected = check c->get("/moved");
    io:println(redirected); // @output moved body

    // A payload that does not fit the target type fails binding.
    Person|error mismatch = c->get("/count");
    if mismatch is error {
        io:println(mismatch.message()); // @output Payload binding failed: '7' value cannot be converted to '{| age: int, name: string, never... |}'
    }

    // Malformed JSON fails to parse.
    Person|error malformed = c->get("/broken-json");
    if malformed is error {
        io:println(malformed.message()); // @output failed to parse JSON payload: invalid character 'o' in literal null (expecting 'u')
    }

    // A text/plain response cannot bind to a record.
    Person|error wrongMime = c->get("/text");
    if wrongMime is error {
        io:println(wrongMime.message()); // @output incompatible '{| age: int, name: string, never... |}' found for 'text/plain' mime type
    }

    // An xml response cannot be bound because the runtime has no xml type.
    string|error asXml = c->get("/xml");
    if asXml is error {
        io:println(asXml.message()); // @output payload binding failed: 'application/xml' responses are not supported because the xml type is not available
    }

    // An octet-stream response cannot bind to a string.
    string|error wrongBlob = c->get("/blob");
    if wrongBlob is error {
        io:println(wrongBlob.message()); // @output incompatible 'string' found for 'application/octet-stream' mime type
    }

    // A form-urlencoded response cannot bind to an int.
    int|error wrongForm = c->get("/form");
    if wrongForm is error {
        io:println(wrongForm.message()); // @output incompatible 'int' found for 'application/x-www-form-urlencoded' mime type
    }

    // A malformed form-urlencoded body fails to parse.
    map<string>|error badForm = c->get("/bad-form");
    if badForm is error {
        io:println(badForm.message()); // @output Payload binding failed: invalid URL escape "%zz"
    }

    // A 4xx body is extracted according to its own media type.
    byte[]|error goneBlob = c->get("/gone-blob");
    if goneBlob is error {
        io:println(goneBlob.message()); // @output Gone
    }

    // An empty body binds to () for a nilable target.
    string? emptyText = check c->get("/empty");
    io:println(emptyText is ()); // @output true

    // An empty octet-stream body binds to () for a nilable byte[] target.
    byte[]? emptyBlob = check c->get("/empty-blob");
    io:println(emptyBlob is ()); // @output true

    // An empty form body binds to () for a nilable map<string> target.
    map<string>? emptyForm = check c->get("/empty-form");
    io:println(emptyForm is ()); // @output true

    // With no Content-Type, an empty body still binds to () for nilable targets.
    string? untypedEmpty = check c->get("/no-type-empty");
    io:println(untypedEmpty is ()); // @output true

    byte[]? untypedEmptyBytes = check c->get("/no-type-empty");
    io:println(untypedEmptyBytes is ()); // @output true

    // An empty body with a non-nilable json target fails to parse.
    Person|error emptyRecord = c->get("/empty-json");
    if emptyRecord is error {
        io:println(emptyRecord.message()); // @output failed to parse JSON payload: EOF
    }

    // An empty body binds to () for a nilable record target.
    Person? emptyOptional = check c->get("/empty-json");
    io:println(emptyOptional is ()); // @output true

    return;
}

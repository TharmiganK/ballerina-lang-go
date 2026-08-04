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

// A tuple is a subtype of byte[], so the blob builder is selected and must reject a body
// whose length does not fit rather than hand back an over-long byte[].
type Pair [byte, byte];

// A closed all-string record is a subtype of map<string>, so the form builder is selected
// and must reject a map that does not fit the record.
type Form record {|
    string a;
    string b;
|};

enum Colour {
    RED = "red",
    GREEN = "green"
}

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
        io:println(asXml.message()); // @output Payload binding failed: 'application/xml' responses are not supported because the xml type is not available
    }

    // A body that is not a member of an enum target fails conversion instead of being
    // returned as a bare string.
    Colour|error notAColour = c->get("/text");
    if notAColour is error {
        io:println(notAColour.message()); // @output Payload binding failed: '"plain text body"' value cannot be converted to '"green"|"red"'
    }

    // A three-byte body does not fit a two-element tuple target.
    Pair|error tooLong = c->get("/blob");
    if tooLong is error {
        io:println(tooLong.message()); // @output Payload binding failed: '[int:Unsigned8...]' value cannot be converted to '[int:Unsigned8, int:Unsigned8, never...]'
    }

    // The nilable form of a narrow target fails the same way; only an absent body binds to
    // (), so a present body that does not fit the target is still an error.
    Colour?|error notAColourOpt = c->get("/text");
    if notAColourOpt is error {
        io:println(notAColourOpt.message()); // @output Payload binding failed: '"plain text body"' value cannot be converted to 'nil|"green"|"red"'
    }

    Pair?|error tooLongOpt = c->get("/blob");
    if tooLongOpt is error {
        io:println(tooLongOpt.message()); // @output Payload binding failed: '[int:Unsigned8...]' value cannot be converted to 'nil|[int:Unsigned8, int:Unsigned8, never...]'
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

    // A status code with no registered reason phrase names the code, so the message is
    // never empty. 499 is nginx's client-closed-request code.
    string|error unregistered = c->get("/nginx-499");
    if unregistered is error {
        io:println(unregistered.message()); // @output status code 499
    }

    // A status error whose Content-Type promises JSON but whose body is absent keeps its
    // reason phrase instead of reporting a payload extraction failure.
    Person|error emptyJsonError = c->get("/empty-json-401");
    if emptyJsonError is error {
        io:println(emptyJsonError.message()); // @output Unauthorized
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

    // Only a nilable target turns an absent body into (). A narrower-than-builder target that
    // is not nilable is handed the builder's empty value and must reject it, rather than
    // admitting "" or [] or {} as a member of the narrow type. One case per builder.
    Colour|error emptyColour = c->get("/empty");
    if emptyColour is error {
        io:println(emptyColour.message()); // @output Payload binding failed: '""' value cannot be converted to '"green"|"red"'
    }

    Pair|error emptyPair = c->get("/empty-blob");
    if emptyPair is error {
        io:println(emptyPair.message()); // @output Payload binding failed: '[int:Unsigned8...]' value cannot be converted to '[int:Unsigned8, int:Unsigned8, never...]'
    }

    Form|error emptyFormRecord = c->get("/empty-form");
    if emptyFormRecord is error {
        io:println(emptyFormRecord.message()); // @output Payload binding failed: '{| string... |}' value cannot be converted to '{| a: string, b: string, never... |}': field 'a' not present in value
    }

    return;
}

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

type Address record {|
    string city;
    int zip;
|};

type Employee record {|
    string name;
    Address address;
|};

public function main() returns error? {
    http:Client c = check new http:Client("http://testserver", {});

    // application/json → record.
    Person p = check c->get("/person");
    io:println(p.name, " ", p.age); // @output Alice 30

    // application/json → nested record.
    Employee e = check c->get("/employee");
    io:println(e.address.city); // @output Colombo

    // application/json → record array.
    Person[] people = check c->get("/people");
    io:println(people.length(), " ", people[1].name); // @output 2 Bob

    // application/json → map<json>.
    map<json> asMap = check c->get("/person");
    io:println(asMap["name"]); // @output Alice

    // application/json → json. The member order of a json map is not fixed, so the
    // shape is asserted rather than the rendered value.
    json asJson = check c->get("/person");
    io:println(asJson is map<json>); // @output true

    // application/json → scalar targets.
    int count = check c->get("/count");
    io:println(count); // @output 7
    boolean flag = check c->get("/flag");
    io:println(flag); // @output true

    // A json media type with a suffix still selects the json builder.
    Person suffixed = check c->get("/person-hal");
    io:println(suffixed.name); // @output Alice

    // text/plain → string.
    string text = check c->get("/text");
    io:println(text); // @output plain text body

    // text/plain → byte[].
    byte[] textBytes = check c->get("/text");
    io:println(textBytes.length()); // @output 15

    // text/plain → nilable byte[].
    byte[]? optTextBytes = check c->get("/text");
    io:println(optTextBytes is byte[]); // @output true

    // application/octet-stream → byte[].
    byte[] blob = check c->get("/blob");
    io:println(blob.length(), " ", blob[0]); // @output 3 1

    // application/octet-stream → nilable byte[].
    byte[]? optBlob = check c->get("/blob");
    io:println(optBlob is byte[]); // @output true

    // application/x-www-form-urlencoded → map<string>.
    map<string> form = check c->get("/form");
    io:println(form["a"], " ", form["b"]); // @output 1 two

    // application/x-www-form-urlencoded → nilable map<string>.
    map<string>? optForm = check c->get("/form");
    io:println(optForm is map<string>); // @output true

    // application/x-www-form-urlencoded → string keeps the raw body.
    string rawForm = check c->get("/form");
    io:println(rawForm); // @output a=1&b=two

    // application/x-www-form-urlencoded → nilable string.
    string? optRawForm = check c->get("/form");
    io:println(optRawForm); // @output a=1&b=two

    // An unknown media type falls back to the target type.
    string unknown = check c->get("/unknown");
    io:println(unknown); // @output opaque payload

    // No Content-Type at all also falls back to the target type.
    string untyped = check c->get("/no-type");
    io:println(untyped); // @output untyped body

    byte[] untypedBytes = check c->get("/no-type");
    io:println(untypedBytes.length()); // @output 12

    return;
}

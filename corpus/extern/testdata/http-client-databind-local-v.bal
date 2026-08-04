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

// A closed all-string record is a subtype of map<string>, so the form builder is selected
// and must convert its map to the record type rather than hand back a plain map<string>.
type Form record {|
    string a;
    string b;
|};

// A tuple is a subtype of byte[], so the blob builder is selected for it.
type Pair [byte, byte];

enum Colour {
    RED = "red",
    GREEN = "green"
}

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

    // A target that is a proper subtype of the builder's own type is converted to that
    // target, not left at the builder's type.
    Form formRecord = check c->get("/form");
    io:println(formRecord.a, " ", formRecord.b); // @output 1 two
    io:println(<any>formRecord is Form); // @output true

    Colour colour = check c->get("/colour");
    io:println(colour, " ", <any>colour is Colour); // @output red true

    Pair pair = check c->get("/blob2");
    io:println(pair.length(), " ", <any>pair is Pair); // @output 2 true

    // The same conversion applies on the fallback path, where no Content-Type is present.
    Colour fallbackColour = check c->get("/no-type-colour");
    io:println(fallbackColour, " ", <any>fallbackColour is Colour); // @output red true

    // The nilable form of a narrow target reaches the same builder: a body that fits is
    // converted to the target, and an absent body binds to ().
    Colour? optColour = check c->get("/colour");
    io:println(optColour, " ", <any>optColour is Colour); // @output red true
    Colour? noColour = check c->get("/empty");
    io:println(noColour is ()); // @output true

    Form? optFormRecord = check c->get("/form");
    io:println(optFormRecord?.a, " ", <any>optFormRecord is Form); // @output 1 true
    Form? noFormRecord = check c->get("/empty-form");
    io:println(noFormRecord is ()); // @output true

    Pair? optPair = check c->get("/blob2");
    io:println(<any>optPair is Pair); // @output true
    Pair? noPair = check c->get("/empty-blob");
    io:println(noPair is ()); // @output true

    Colour? optFallbackColour = check c->get("/no-type-colour");
    io:println(optFallbackColour, " ", <any>optFallbackColour is Colour); // @output red true
    Colour? noFallbackColour = check c->get("/no-type-empty");
    io:println(noFallbackColour is ()); // @output true

    // `var` provides no contextually expected type, so the target is passed explicitly.
    var explicitPerson = check c->get("/person", targetType = Person);
    io:println(explicitPerson.name); // @output Alice

    var explicitResponse = check c->get("/person", targetType = http:Response);
    io:println(explicitResponse.statusCode); // @output 200

    return;
}

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

public function main() {
    int a = 10;

    // Negate the value of `a`.
    int negatedInt = -a;
    io:println(negatedInt);
    
    // Invert the bits of `a`.
    int bitwiseInvertedInt = ~a;
    io:println(bitwiseInvertedInt);

    int:Signed8 b = 127;

    // Negate the value of `b`.
    int negatedSigned8Int = -b;
    io:println(negatedSigned8Int);

    float c = -10.5;

    // Negate the value of `c`.
    float negatedFloat = -c;
    io:println(negatedFloat);
    
    // Using the `+` operator returns the value of its operand expression.
    float unchangedFloat = +c;
    io:println(unchangedFloat);

    boolean d = true;

    // Invert the boolean value of `d`.
    boolean negatedBoolean = !d;
    io:println(negatedBoolean);
}

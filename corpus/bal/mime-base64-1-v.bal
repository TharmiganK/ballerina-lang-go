import ballerina/io;
import ballerina/mime;

public function main() {
    string|byte[]|mime:EncodeError enc = mime:base64Encode("Hello");
    if enc is string {
        io:println(enc);
    }

    string|byte[]|mime:DecodeError dec = mime:base64Decode("SGVsbG8=");
    if dec is string {
        io:println(dec);
    }

    byte[]|mime:EncodeError bEnc = mime:base64EncodeBlob([1, 2, 3]);
    if bEnc is byte[] {
        byte[]|mime:DecodeError bDec = mime:base64DecodeBlob(bEnc);
        if bDec is byte[] {
            io:println(bDec.length());
        }
    }
}
// @output SGVsbG8=
// @output Hello
// @output 3

// Copyright (c) 2026, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
//
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

isolated function getBytesFromUuid(string uuid) returns byte[]|Error {
    Uuid uuidRecord = check toRecord(uuid);

    int msb = check getMostSigBits(uuidRecord);
    int lsb = check getLeastSigBits(uuid, uuidRecord);
    return bitsToBytes(msb, lsb);
}

isolated function getMostSigBits(Uuid uuid) returns int|Error {
    int mostSigBits = uuid.timeLow & 0xffffffff;
    mostSigBits <<= 16;
    mostSigBits |= uuid.timeMid & 0xffff;
    mostSigBits <<= 16;
    mostSigBits |= uuid.timeHiAndVersion & 0xffff;
    return mostSigBits;
}

isolated function getLeastSigBits(string uuidString, Uuid uuidRecord) returns int|Error {
    // UUID format: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
    // clock-seq field spans positions 19-22 (0-indexed, exclusive end)
    string clockSeq = uuidString.substring(19, 23);
    int|error clockSeqInt = ints:fromHexString(clockSeq);
    int leastSigBits;
    if clockSeqInt is int {
        leastSigBits = clockSeqInt & 0xffff;
    } else {
        return error Error("Failed to get clock sequence value of the uuid");
    }

    leastSigBits <<= 48;
    leastSigBits |= uuidRecord.node & 0xffffffffffff;
    return leastSigBits;
}

isolated function getUuidFromBytes(byte[] uuid) returns string {
    int msb = ((uuid[0] & 0xFF) << 56) |
            ((uuid[1] & 0xFF) << 48) |
            ((uuid[2] & 0xFF) << 40) |
            ((uuid[3] & 0xFF) << 32) |
            ((uuid[4] & 0xFF) << 24) |
            ((uuid[5] & 0xFF) << 16) |
            ((uuid[6] & 0xFF) << 8) |
            ((uuid[7] & 0xFF) << 0);

    int lsb = ((uuid[8] & 0xFF) << 56) |
            ((uuid[9] & 0xFF) << 48) |
            ((uuid[10] & 0xFF) << 40) |
            ((uuid[11] & 0xFF) << 32) |
            ((uuid[12] & 0xFF) << 24) |
            ((uuid[13] & 0xFF) << 16) |
            ((uuid[14] & 0xFF) << 8) |
            ((uuid[15] & 0xFF) << 0);

    return bitsToUuid(msb, lsb);
}

isolated function bitsToBytes(int msb, int lsb) returns byte[] {
    byte[] result = [];

    result[0] = <byte>((msb >> 56) & 0xff);
    result[1] = <byte>((msb >> 48) & 0xff);
    result[2] = <byte>((msb >> 40) & 0xff);
    result[3] = <byte>((msb >> 32) & 0xff);
    result[4] = <byte>((msb >> 24) & 0xff);
    result[5] = <byte>((msb >> 16) & 0xff);
    result[6] = <byte>((msb >> 8) & 0xff);
    result[7] = <byte>((msb >> 0) & 0xff);

    result[8] = <byte>((lsb >> 56) & 0xff);
    result[9] = <byte>((lsb >> 48) & 0xff);
    result[10] = <byte>((lsb >> 40) & 0xff);
    result[11] = <byte>((lsb >> 32) & 0xff);
    result[12] = <byte>((lsb >> 24) & 0xff);
    result[13] = <byte>((lsb >> 16) & 0xff);
    result[14] = <byte>((lsb >> 8) & 0xff);
    result[15] = <byte>((lsb >> 0) & 0xff);

    return result;
}

// bitsToUuid converts MSB and LSB integers into a UUID string.
// Layout: (msb>>>32):8h-(msb>>>16)&ffff:4h-msb&ffff:4h-(lsb>>>48)&ffff:4h-lsb&ffffffffffff:12h
isolated function bitsToUuid(int mostSigBits, int leastSigBits) returns string {
    return constructComponent(ints:toHexString((mostSigBits >>> 32) & 0xffffffff), 8) + "-" +
           constructComponent(ints:toHexString((mostSigBits >>> 16) & 0xffff), 4) + "-" +
           constructComponent(ints:toHexString(mostSigBits & 0xffff), 4) + "-" +
           constructComponent(ints:toHexString((leastSigBits >>> 48) & 0xffff), 4) + "-" +
           constructComponent(ints:toHexString(leastSigBits & 0xffffffffffff), 12);
}

isolated function constructComponent(string hex, int length) returns string {
    string hexString = "";
    foreach int _ in 0 ..< (length - hex.length()) {
        hexString += "0";
    }
    return hexString + hex;
}

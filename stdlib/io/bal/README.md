# Ballerina IO Library

## Overview

This module provides I/O operations for Ballerina programs. The full jBallerina `io` module covers console output, file I/O (string, bytes, JSON, XML, CSV, lines), low-level byte/character/data channels, and stream-based reading. The Go Native Interpreter currently supports the console print subset.

## Key Functionalities

- Print `any` or `error` values to the standard output stream using `print` and `println`.
- Print to a specified output stream (stdout or stderr) using `fprint` and `fprintln`.
- Read file content as a string, line array, byte array, or JSON using `fileReadString`, `fileReadLines`, `fileReadBytes`, and `fileReadJson`.
- Write string, line array, byte array, or JSON content to a file using `fileWriteString`, `fileWriteLines`, `fileWriteBytes`, and `fileWriteJson`.
- Control write behaviour with the `FileWriteOption` enum (`OVERWRITE` or `APPEND`).

## Examples

```ballerina
import ballerina/io;

public function main() returns error? {
    io:println("Starting process...");
    io:print("Value: ", 42);
    io:fprint(io:stderr, "An unexpected error occurred");

    // Write and read a file
    check io:fileWriteString("/tmp/greet.txt", "Hello\nWorld");
    string content = check io:fileReadString("/tmp/greet.txt");
    io:println(content);

    // Append to a file
    check io:fileWriteString("/tmp/greet.txt", "\nAppended", io:APPEND);

    // Write and read lines
    check io:fileWriteLines("/tmp/lines.txt", ["Alpha", "Beta"]);
    string[] lines = check io:fileReadLines("/tmp/lines.txt");
    foreach string line in lines {
        io:println(line);
    }

    // Write and read bytes
    check io:fileWriteBytes("/tmp/data.bin", [72, 101, 108, 108, 111]);
    byte[] bytes = check io:fileReadBytes("/tmp/data.bin");
    io:println(bytes.length());

    // Write and read JSON
    check io:fileWriteJson("/tmp/data.json", {"name": "Alice", "age": 30});
    json result = check io:fileReadJson("/tmp/data.json");
    io:println(result);
}
```

## Go Native Interpreter Support Status

This library is currently being migrated to Go to support the Ballerina Native Interpreter. The table below outlines the current support level for various features of this library in the Go implementation.

Support Levels:

- **Supported**: Fully implemented and tested in the Go version.
- **Partially Supported**: Implemented but lacking some edge cases, options, or sub-features. (See comments).
- **Not Yet Supported**: Planned for migration, but not yet implemented.
- **Cannot Support**: Cannot be implemented in the Go version due to technical limitations or architectural differences. (See comments).

| Feature/API | Support Status | Comments / Limitations |
|---|---|---|
| Print to standard output | Supported | |
| Print to standard output with a newline | Supported | |
| Print to a specified output stream | Supported | |
| Print to a specified output stream with a newline | Supported | |
| String template support in print functions | Not Yet Supported | `PrintableRawTemplate` type is not yet defined; string templates cannot be passed directly to print functions. |
| File read — string (`fileReadString`) | Supported | Line endings normalised to `\n`; trailing newline stripped. See Notable Behavioural Changes. |
| File read — lines (`fileReadLines`) | Supported | Terminal carriage characters stripped; trailing empty line excluded. |
| File read — bytes (`fileReadBytes`) | Supported | Returns `byte[]`; jBallerina returns `readonly & byte[]`. See Notable Behavioural Changes. |
| File read — JSON (`fileReadJson`) | Supported | JSON object keys are sorted alphabetically on write. See Notable Behavioural Changes. |
| File read — stream of lines (`fileReadLinesAsStream`) | Not Yet Supported | `stream` type not yet supported. |
| File read — stream of blocks (`fileReadBlocksAsStream`) | Not Yet Supported | `stream` type not yet supported. |
| File write — string (`fileWriteString`) | Supported | `OVERWRITE` and `APPEND` modes supported. |
| File write — lines (`fileWriteLines`) | Supported | `OVERWRITE` and `APPEND` modes supported; `\n` appended after each line. |
| File write — bytes (`fileWriteBytes`) | Supported | `OVERWRITE` and `APPEND` modes supported. |
| File write — JSON (`fileWriteJson`) | Supported | Always overwrites; JSON object keys sorted alphabetically. See Notable Behavioural Changes. |
| File write — stream of lines (`fileWriteLinesFromStream`) | Not Yet Supported | `stream` type not yet supported. |
| File write — stream of blocks (`fileWriteBlocksFromStream`) | Not Yet Supported | `stream` type not yet supported. |
| File I/O — XML (`fileReadXml`, `fileWriteXml`) | Not Yet Supported | XML basic type not yet supported. |
| File I/O — CSV (`fileReadCsv`, `fileWriteCsv`, stream variants) | Not Yet Supported | `stream` type not yet supported; `typedesc` parameter handling complex. |
| `FileWriteOption` enum (`OVERWRITE`, `APPEND`) | Supported | |
| `io:Error` type | Partially Supported | Declared as a plain `error` alias; `distinct` error subtypes (`FileNotFoundError`, `GenericError`, `AccessDeniedError`, `EofError`, `ConfigurationError`, `TypeMismatchError`) not yet supported. |
| Byte channels (`ReadableByteChannel`, `WritableByteChannel`) | Not Yet Supported | Object-based channel system not implemented. |
| Character channels (`ReadableCharacterChannel`, `WritableCharacterChannel`) | Not Yet Supported | Not implemented. |
| Data channels | Not Yet Supported | Not implemented. |
| CSV channels | Not Yet Supported | Not implemented. |
| `openReadableFile`, `openWritableFile` | Not Yet Supported | Channel APIs not implemented. |

### Notable Behavioural Changes

| Feature | jBallerina behaviour | Go-native behaviour |
|---|---|---|
| `fileReadBytes` return type | Returns `readonly & byte[]` | Returns `byte[]` — `readonly &` intersection type is not yet supported by the interpreter. |
| `io:Error` subtypes | Raises distinct subtypes (`FileNotFoundError`, `GenericError`, etc.) depending on the failure | All file I/O errors surface as a plain `error` — `distinct` type descriptor is not yet supported. |
| `fileWriteJson` key ordering | JSON object keys written in insertion order | JSON object keys written in **alphabetical order** — Go's `encoding/json` sorts map keys. |
| `fileReadString` line-ending normalisation | `BufferedReader.lines()` strips `\r`, `\r\n`, and `\n`; joins with `\n`; trailing newline absent | Same semantic result on all platforms: `\r\n` and `\r` normalised to `\n` before splitting; trailing empty entry removed. |

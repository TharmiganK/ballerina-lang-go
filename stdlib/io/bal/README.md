# Ballerina IO Library

## Overview

This module provides I/O operations for Ballerina programs. The full jBallerina `io` module covers console output, file I/O (string, bytes, JSON, XML, CSV, lines), low-level byte/character/data channels, and stream-based reading. The Go Native Interpreter currently supports the console print subset.

## Key Functionalities

- Print `any` or `error` values to the standard output stream using `print` and `println`.
- Print to a specified output stream (stdout or stderr) using `fprint`.

## Examples

```ballerina
import ballerina/io;

public function main() {
    io:println("Starting process...");
    io:print("Value: ", 42);

    io:fprint(io:stderr, "An unexpected error occurred");
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
| Print to standard output | Supported | Fully implemented and tested in the Go version. |
| Print to standard output with a newline | Supported | Fully implemented and tested in the Go version. |
| Print to a specified output stream | Supported | Fully implemented and tested in the Go version. |
| Print to a specified output stream with a newline | Supported | Fully implemented and tested in the Go version. |
| String template support in print functions | Not Yet Supported | `PrintableRawTemplate` type is not yet defined; string templates cannot be passed directly to print functions. |
| File I/O — string and bytes | Not Yet Supported | Requires filesystem PAL support not yet available. |
| File I/O — lines | Not Yet Supported | Requires filesystem PAL support not yet available. |
| File I/O — JSON | Not Yet Supported | Requires filesystem PAL support not yet available. |
| File I/O — XML | Not Yet Supported | Requires filesystem PAL support not yet available. |
| File I/O — CSV | Not Yet Supported | Requires filesystem PAL support not yet available. |
| Byte channels | Not Yet Supported | Low-level channel abstractions not implemented. |
| Character channels | Not Yet Supported | Not implemented. |
| Data channels | Not Yet Supported | Not implemented. |
| CSV channels | Not Yet Supported | Not implemented. |
| Stream-based I/O | Not Yet Supported | Stream returns for file reads not implemented. |
| Specific error subtypes | Not Yet Supported | No io-specific error types; errors surface as generic runtime errors. |

### Notable Behavioural Changes

There are **no** notable behavioural changes in the Go-native version compared to the original jBallerina implementation for the currently supported features.

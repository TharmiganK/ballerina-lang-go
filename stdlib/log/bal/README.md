# Ballerina Log Library

## Overview

This module provides structured logging for Ballerina programs. The full jBallerina `log` module covers configurable log levels and formats (LOGFMT and JSON), multiple output destinations (stderr, stdout, rotating files), per-module level overrides, key-value pair annotations, sensitive data masking, a named `Logger` object API with child-logger support, and observability integration. The Go Native Interpreter supports the core module-level print functions with basic level filtering.

## Key Functionalities

- Print structured log messages at four severity levels using `printDebug`, `printInfo`, `printWarn`, and `printError`.
- Attach an optional `error` value to any log call via the `'error` named parameter.
- Level filtering at the default `INFO` level: `DEBUG` messages are silently suppressed; `INFO`, `WARN`, and `ERROR` messages are emitted.
- Log output is written to stderr in LOGFMT format: `time=<RFC3339> level=<LEVEL> module="" message="<msg>" [error=<err>]`.

## Examples

```ballerina
import ballerina/log;

public function main() {
    log:printInfo("server started");
    log:printWarn("connection slow");

    error e = error("disk full");
    log:printError("write failed", 'error = e);

    // DEBUG is silently dropped at the default INFO level
    log:printDebug("this will not appear");
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
| Print at DEBUG level | Supported | |
| Print at INFO level | Supported | |
| Print at WARN level | Supported | |
| Print at ERROR level | Supported | |
| Optional error parameter (`'error`) | Supported | |
| Default level filtering (INFO) | Supported | `DEBUG` messages suppressed; `INFO`, `WARN`, `ERROR` emitted. |
| LOGFMT output format | Supported | Written to stderr. Format: `time=<RFC3339> level=<LEVEL> module="" message="<msg>"`. |
| JSON output format | Not Yet Supported | `JSON_FORMAT` enum constant is declared; switching format requires `configurable` variable support. |
| Configurable log level | Not Yet Supported | Level is hardcoded to `INFO`; `configurable Level level` requires configurable variable support. |
| Configurable log format | Not Yet Supported | Format is hardcoded to LOGFMT; `configurable LogFormat format` requires configurable variable support. |
| Key-value pair annotations (`*KeyValues`) | Not Yet Supported | `log:printInfo("msg", port = 8080)` style calls are blocked by a language gap: arbitrary named arguments for included record parameters with rest fields (`anydata...`) are not yet supported by the interpreter. |
| Per-module level overrides | Not Yet Supported | Requires `configurable table<Module>` support (tables not yet supported). |
| Multiple output destinations | Not Yet Supported | `configurable OutputDestination[] destinations` not supported; output is always written to stderr. |
| File output destination | Not Yet Supported | Requires `lock` statements and file I/O integration not yet implemented. |
| Log rotation | Not Yet Supported | Depends on file output support. |
| `Logger` object interface | Not Yet Supported | Requires `isolated` object support. Affects `root()`, `fromConfig`, `withContext`, and `LoggerRegistry`. |
| Child loggers (`withContext`) | Not Yet Supported | Depends on `Logger` object support. |
| Logger registry (`getLoggerRegistry`) | Not Yet Supported | Depends on `Logger` object support. |
| Sensitive data masking | Not Yet Supported | `@Sensitive` annotation and `toMaskedString` not implemented. |
| Template message support | Not Yet Supported | `PrintableRawTemplate` type requires template expression support (not yet supported). |
| `stackTrace` parameter | Not Yet Supported | Omitted from function signatures; stack trace access differs from JVM. |
| `ballerina/observe` integration | Not Yet Supported | `ballerina/observe` module not yet available; tracing context fields omitted from log records. |
| Deprecated `setOutputFile` function | Not Yet Supported | Deprecated in jBallerina; not implemented. |
| `log:Error` type | Partially Supported | Declared as a plain `error` alias; `distinct` error types not yet supported. |

### Notable Behavioural Changes

- **Module name always empty.** jBallerina uses JVM `StackWalker` to detect the calling module name at runtime; the Go-native version has no equivalent mechanism, so `module=""` in all log records.
- **Error field format.** jBallerina serialises a full `FullErrorDetails` record (message, stack trace, cause chain) for the `error` field; the Go-native version formats the error as `error("message")` using the Ballerina `toBalString` representation of the error value.

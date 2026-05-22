# Ballerina OS Library

## Overview

This module provides operating-system interaction for Ballerina programs. It covers environment variable management, current-user queries, and subprocess execution. The Go Native Interpreter supports the full surface of the jBallerina `os` module.

## Key Functionalities

- Read, set, unset, and list environment variables with `getEnv`, `setEnv`, `unsetEnv`, and `listEnv`.
- Query the current user's name and home directory with `getUsername` and `getUserHome`.
- Spawn a subprocess with `exec` and interact with it through the `Process` object: wait for exit (`waitForExit`), capture stdout/stderr (`output`), and terminate the process (`exit`).

## Examples

```ballerina
import ballerina/io;
import ballerina/os;

public function main() returns error? {
    // Environment variables
    check os:setEnv("MY_KEY", "hello");
    string val = os:getEnv("MY_KEY");
    io:println(val);            // hello
    check os:unsetEnv("MY_KEY");

    map<string> env = os:listEnv();
    io:println(env.length() > 0); // true

    // User info
    io:println(os:getUsername() != "");  // true
    io:println(os:getUserHome() != "");  // true

    // Execute a subprocess
    os:Process p = check os:exec({value: "echo", arguments: ["world"]});
    int code = check p.waitForExit();
    io:println(code);           // 0

    byte[] out = check p.output();
    io:println(out.length() > 0); // true
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
| `getEnv(name)` | Supported | Returns empty string when variable is unset. |
| `setEnv(key, value)` | Supported | Validates that `key` is not empty or `"=="`. |
| `unsetEnv(key)` | Supported | Validates that `key` is not empty. |
| `listEnv()` | Supported | Returns a `map<string>` snapshot of all environment variables at call time. |
| `getUsername()` | Supported | Returns empty string if the OS query fails. |
| `getUserHome()` | Supported | Returns empty string if the OS query fails. |
| `exec(command, *envProperties)` | Supported | Merges parent environment with any overrides passed via `envProperties`. |
| `Process.waitForExit()` | Supported | Returns the exit code; non-zero for failure. |
| `Process.output(fileOutputStream)` | Supported | Reads stdout (default) or stderr after the process exits. |
| `Process.exit()` | Supported | Sends SIGKILL to the subprocess immediately. |
| `os:Error` type | Partially Supported | Declared as a plain `error` alias; `distinct` error subtypes not yet supported. |
| `EnvProperties` `never command?` exclusion guard | Not Yet Supported | The `never`-typed field that prevents accidental shadowing of the `command` parameter is omitted; `distinct` field handling is not yet implemented. |

### Notable Behavioural Changes

- **`os:Error` subtypes.** jBallerina raises distinct subtypes depending on the failure; the Go-native version surfaces all errors as a plain `error` — `distinct` type descriptor is not yet supported.
- **`EnvProperties.command` exclusion.** jBallerina's `never command?` field prevents callers from passing an env var named `command`; the Go-native version omits this field, so callers can accidentally pass `command` as an env override.
- **Isolated thread-local env.** jBallerina uses per-strand env maps for isolation; the Go implementation uses the process-wide env (`os.Setenv` / `os.Getenv`), which is safe for single-threaded Ballerina programs.

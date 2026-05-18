# Add `ballerina/http` client support with full HTTP methods, TLS, and response API

## Purpose
Implements the `ballerina/http` client module for the Go-based Ballerina runtime, enabling Ballerina programs to make outbound HTTP/HTTPS requests. This covers HTTP method dispatch, client configuration (timeout, redirect, HTTP version, TLS/mTLS), response header and payload APIs, and HTTP header parsing utilities.

## Approach
The implementation is split across two layers:
- **Compile-time** (`lib/http/compile/http.go`): type registration, extern function wiring, and semantic analysis hooks for `ballerina/http` symbols.
- **Runtime** (`lib/http/runtime/http.go`): PAL-backed Go HTTP client that executes remote method calls (`get`, `post`, `put`, `patch`, `delete`, `head`, `options`, `execute`) via a single `Execute(method, url, body, contentType, headers)` interface using Go's `net/http` package.
>
Key design decisions:
- `HttpVersion "2.0"` enables HTTP/2 (ALPN) and h2c via Go 1.24+ `Transport.Protocols`; `"1.1"` restricts to HTTP/1.x only.
- `secureSocket` maps to Go TLS config: `cert` sets a custom CA PEM, `key`/`certFile`/`keyFile` enables mTLS, `verifyHostName=false` sets `InsecureSkipVerify`.
- CN-based TLS hostname fallback is included for legacy self-signed certificates without SANs.
- `http:Response` header API (`hasHeader`, `getHeader`, `getHeaders`, `getHeaderNames`) stores headers as lists to preserve multi-value semantics; `TRAILING` position is accepted but silently ignored.
- `getJsonPayload()` uses a `UseNumber` JSON decoder to preserve integer precision.
- All outgoing requests carry a `User-Agent: ballerina` header.
>
A support reference document (`lib/http/client-support.md`) describes the supported API subset and known limitations.

## User stories
- As a Ballerina developer, I can create an `http:Client` and call `get`, `post`, `put`, `patch`, `delete`, `head`, `options`, and `execute` methods to make outbound HTTP requests.
- As a Ballerina developer, I can configure the HTTP client with a timeout, redirect policy, HTTP version (1.1 or 2.0), and TLS/mTLS settings via `ClientConfiguration`.
- As a Ballerina developer, I can read response headers using `hasHeader`, `getHeader`, `getHeaders`, and `getHeaderNames` on an `http:Response`.
- As a Ballerina developer, I can extract response payloads as `string`, `json`, or `byte[]` using `getTextPayload`, `getJsonPayload`, and `getBinaryPayload`.
- As a Ballerina developer, I can parse HTTP header values using `http:parseHeader`.

## Release note
Added `ballerina/http` client support to the Go-based Ballerina runtime. Programs can now make outbound HTTP and HTTPS requests using the standard `http:Client` API, including all HTTP methods, `ClientConfiguration` (timeout, redirect, HTTP version, TLS/mTLS via `secureSocket`), and a full `http:Response` header and payload API.

## Documentation
- `lib/http/client-support.md` — in-repo support reference documenting the supported API subset, type definitions, known limitations, and implementation notes.

## Training
N/A

## Certification
N/A — this change adds runtime support for a standard library module. No new exam-relevant certification questions arise from an implementation change of this nature.

## Marketing
N/A

## Automation tests
- Unit tests
  Corpus tests added for all supported `ballerina/http` scenarios: `http-client-v`, `http-client-methods-v`, `http-client-post-v`, `http-client-tls-v`, `http-client-response-headers-v`, `http-client-response-payload-v`, `http-parse-header-v`. Error cases covered: `http-client-e`, `http-client-config-e`, `http-client-tls-e`, `http-parse-header-e`. AST, BIR, CFG, and desugared corpus outputs are all updated.
- Integration tests
  Extern integration tests in `extern-test/http_client_test.go` cover: `Get`, `Post`, all HTTP methods (`Methods`), and TLS with insecure verify (`TLSInsecure`). Tests run against a live local HTTP/HTTPS test server spun up within the test harness.

## Security checks
- Followed secure coding standards in http://wso2.com/technical-reports/wso2-secure-engineering-guidelines? yes
- Confirmed that this PR doesn't commit any keys, passwords, tokens, usernames, or other secrets? yes

## Samples
Ballerina source samples are provided as corpus test inputs under `corpus/bal/subset8/08-network/` and `extern-test/testdata/`, demonstrating client creation, HTTP method calls, TLS configuration, and response payload/header extraction.

## Related PRs
- #408 — Add workspace project/repository support (merged into this branch from upstream)

## Migrations (if applicable)
N/A — new feature; no existing API changed.

## Test environment
- Go 1.26.0, darwin/arm64 (Apple Silicon)
- Corpus tests: `go test ./corpus/...`
- Extern tests: `go test ./extern-test/...`

## Learning
- [Ballerina HTTP client spec](https://lib.ballerina.io/ballerina/http/latest) — reference for supported type definitions and method signatures.
- Go `net/http` transport documentation for HTTP/2 (`Transport.Protocols`) and TLS configuration (`tls.Config`).
- `encoding/json` `UseNumber` decoder for integer-preserving JSON parsing.

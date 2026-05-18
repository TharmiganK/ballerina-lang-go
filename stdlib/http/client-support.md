# `ballerina/http` Client — Support Reference

_Version_: v0.05.0 \
_Created_: 2026/05/14 \
_Updated_: 2026/05/14 

## Supported

### Client — remote methods

All eight remote methods are supported: `get`, `post`, `put`, `patch`, `delete`, `head`, `options`, and `execute`. Each method accepts optional request headers as a `map<string|string[]>`. Methods that carry a body (`post`, `put`, `patch`, `delete`, `execute`) additionally accept an optional media type override.

### Client — initialisation

The client can be initialised with a URL and an optional `ClientConfiguration` record. The configuration supports:

| Field | Notes |
|---|---|
| `timeout` | Request timeout as a decimal (seconds); default is `30` |
| `httpVersion` | `"1.1"` or `"2.0"` (default). HTTP/2 is enabled over both TLS (via ALPN) and cleartext (h2c) |
| `followRedirects` | Full `FollowRedirects` record: `enabled`, `maxCount` (default 5), `allowAuthHeaders` |
| `secureSocket` | See TLS section below |

### Request message body

The `message` parameter is typed as `json`, which in Ballerina includes `string`, `byte[]`, and all JSON-compatible values. The runtime infers `Content-Type` from the value:

- `string` — sent as `text/plain`
- `byte[]` (a list where every element is an integer in 0–255) — sent as `application/octet-stream`
- All other `json`-compatible values (`nil`, `boolean`, `int`, `float`, `decimal`, nested maps and lists, JSON arrays) — serialised and sent as `application/json`

The `mediaType` parameter overrides the inferred `Content-Type` in all cases.

### Response — fields

| Field | Notes |
|---|---|
| `statusCode` | HTTP status code of the response |

### Response — methods

| Method | Notes |
|---|---|
| `getTextPayload()` | Returns the response body as a string |
| `getJsonPayload()` | Parses the body as JSON; returns `json\|error` |
| `getBinaryPayload()` | Returns the body as a byte array; returns `byte[]\|error` |
| `hasHeader(name, position?)` | Returns `true` if the header is present |
| `getHeader(name, position?)` | Returns the first value for the header, or an error if absent |
| `getHeaders(name, position?)` | Returns all values for the header, or an error if absent |
| `getHeaderNames(position?)` | Returns the names of all response headers |

The `position` parameter accepts `http:LEADING` (default) or `http:TRAILING`. Trailing headers are accepted at compile time but not modelled at runtime — all operations act on transport headers.

### TLS (`secureSocket`)

| Setting | Notes |
|---|---|
| `enable` / `verifyHostName` | Disabling either turns off certificate/hostname verification |
| `cert` (string path) | Custom CA trust store from a PEM file; CN-based hostname fallback supported for legacy self-signed certificates |
| `key` (`CertKey`) | Mutual TLS using `certFile` and `keyFile` (unencrypted PEM) |
| `serverName` | Overrides the SNI hostname sent during the TLS handshake |
| `ciphers` | IANA cipher suite names applied to TLS 1.2 connections; unknown names are silently skipped |
| `handshakeTimeout` | Maximum duration allowed for the TLS handshake |
| `shareSession = false` | Disables TLS session ticket reuse |
| `protocol.versions` | Accepts `"TLSv1.0"`, `"TLSv1.1"`, `"TLSv1.2"`, `"TLSv1.3"` to set minimum and maximum TLS versions |

---

## Not Supported

### Client — remote methods

| Method | Reason |
|---|---|
| `forward` | Requires an `http:Request` object, which is not implemented |
| `submit` / `getResponse` | Asynchronous request model (`HttpFuture`) is not implemented |
| `hasPromise` / `getNextPromise` / `getPromisedResponse` / `rejectPromise` | HTTP/2 server push is not implemented |

Resource function syntax (`client->/path.get(...)`) is not supported; use the remote method form instead.

### Client — configuration

| Field | Reason |
|---|---|
| `circuitBreaker` | Circuit breaker pattern not implemented |
| `retryConfig` | Automatic retry not implemented |
| `cookieConfig` | Cookie store not implemented |
| `cache` | HTTP response caching not implemented |
| `compression` | Compression negotiation not implemented |
| `auth` | Auth handlers not implemented |
| `http1Settings` | HTTP/1.x-specific settings (keep-alive, chunking, proxy) not implemented |
| `http2Settings` | HTTP/2-specific settings (prior knowledge, window size) not implemented |
| `responseLimits` | Response size limits not implemented |
| `socketConfig` | TCP socket configuration not implemented |
| `validation` / `laxDataBinding` | Payload validation not implemented |

`httpVersion: "1.0"` is a compile error — Go's HTTP client does not support sending HTTP/1.0 requests.

### Response — fields

`reasonPhrase`, `resolvedRequestedURI`, `server`, and `cacheControl` are not exposed. The raw `headers` map is not exposed; use the header methods instead.

### Response — methods

All write methods (`addHeader`, `setHeader`, `removeHeader`, `removeAllHeaders`, `setJsonPayload`, `setPayload`, etc.) are not supported — `Response` objects are only received from the server, never constructed by user code.

| Method | Reason |
|---|---|
| `getXmlPayload` | XML values are not representable at runtime |
| `getByteStream` | Streaming response body not implemented |
| `getSseEventStream` | Server-Sent Events not implemented |
| `getBodyParts` | Multipart (`mime:Entity[]`) not implemented |
| `getContentType` / `setContentType` | Not exposed |
| `getEntity` / `setEntity` | MIME entity access not exposed |
| `getStatusCodeRecord` | Status code response type binding not implemented |
| Cookie methods | Cookie handling not implemented |

### Response data binding (`targetType`)

The `targetType` parameter present on upstream methods (which enables automatic binding of the response body to `string`, `byte[]`, `json`, custom record types, or `stream<SseEvent, error?>`) is not supported. All methods return `Response|error` and the caller must extract the payload explicitly using `getTextPayload()`, `getJsonPayload()`, or `getBinaryPayload()`.

### Request message body types

| Type | Reason |
|---|---|
| `http:Request` objects | `Request` class is not implemented |
| `xml` | XML values are not representable at runtime |
| `stream<byte[], io:Error?>` | Streaming request body not implemented |
| `mime:Entity[]` | Multipart not implemented; requires `ballerina/mime` |

### TLS (`secureSocket`)

| Setting | Reason |
|---|---|
| `cert` as `crypto:TrustStore` | Requires `ballerina/crypto`, which is not implemented |
| `key` as `crypto:KeyStore` | Requires `ballerina/crypto`, which is not implemented |
| `keyPassword` in `CertKey` | Password-protected private keys are not supported; the key file must be unencrypted PEM |
| `certValidation` | OCSP/CRL certificate revocation checks are not supported in Go's standard TLS library |
| `sessionTimeout` | Not configurable in Go's TLS stack |
| `protocol.name` | Go only supports TLS; `"SSL"` and `"DTLS"` are accepted at compile time but have no effect at runtime |

### Error types

Errors returned by client methods are plain `error` values. The upstream distinct error types (`http:ClientError`, `http:HeaderNotFoundError`, etc.) are not declared — type narrowing with `is http:ClientError` or `is http:HeaderNotFoundError` will not work.

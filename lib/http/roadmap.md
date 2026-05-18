# `ballerina/http` Client — Roadmap

Tasks are grouped into releases by dependency order and implementation effort. Effort labels map to calendar time assuming one engineer working on the interpreter:

| Label | Duration |
|---|---|
| Small | 1–3 days |
| Medium | 1–2 weeks |
| Large | 3–4 weeks |
| X-Large | 1–2 months (often gated on a lang-level prerequisite) |

---

## v0.2 — Reliability Essentials

**Goal:** Fill the most visible gaps in error handling, transport configuration, and connection behaviour without requiring new language-level features.

| Task | Effort | Estimate | Notes |
|---|---|---|---|
| Distinct error types (`http:ClientError`, `http:HeaderNotFoundError`) | Medium | 1 week | Requires exposing `errorDistinct` in the `semtypes` package so distinct IDs can be allocated from outside the package. Enables `is http:ClientError` type narrowing. |
| Retry configuration (`retryConfig`) | Medium | 1 week | Retry loop around the PAL `Execute` call with `count`, `interval`, exponential `backOffFactor`, `maxWaitInterval`, and `statusCodes`. No new lang features needed. |
| `responseLimits` configuration | Small | 2 days | Max response header and body sizes map directly to `http.Transport` and response-reading limits in the native client. |
| `socketConfig` configuration | Small | 2–3 days | TCP dial settings (`connectTimeOut`, `keepAlive`, `tcpNoDelay`) map to `net.Dialer` fields passed into `http.Transport`. |
| `http1Settings` (keep-alive, proxy) | Medium | 1 week | `keepAlive` controls connection reuse. `proxy` (`ProxyConfig`) maps to `http.Transport.Proxy`. `chunking` maps to `http.Request.TransferEncoding`. |
| `http2Settings` | Small | 2 days | `http2PriorKnowledge` and `http2InitialWindowSize` map to `golang.org/x/net/http2` transport fields already transitively available. |
| Compression negotiation | Small | 1 day | Go handles `Accept-Encoding` / `Content-Encoding` transparently when `http.Transport.DisableCompression` is false. Wire up the `compression` config field. |
| Response metadata fields (`reasonPhrase`, `resolvedRequestedURI`, `server`) | Small | 2 days | Populate from the Go `http.Response` fields (`Status`, `Request.URL`, `Header["Server"]`) inside `buildResponse`. |
| Encrypted private keys (`keyPassword` in `CertKey`) | Small | 1 day | Use `x509.DecryptPEMBlock` (deprecated but functional) before calling `tls.X509KeyPair`. Covers the common OpenSSL `genrsa -aes256` case. |

**Total estimated effort: ~4–5 weeks**

---

## v0.3 — Request Model and Auth

**Goal:** Introduce the `http:Request` object and authentication handlers, which unblock `forward`, request header manipulation, and secure API access.

| Task | Effort | Estimate | Notes |
|---|---|---|---|
| `http:Request` object | Medium | 1–2 weeks | Define a `Request` class with `setHeader`, `addHeader`, `removeHeader`, `setPayload`, `setJsonPayload`, `setTextPayload`, `setBinaryPayload`. Required by `forward` and by accepting `RequestMessage` as `http:Request`. |
| `forward` remote method | Small | 1 day | Straightforward once `http:Request` exists — pass the request object's headers and body directly to `Execute`. |
| Response header write methods (`addHeader`, `setHeader`, `removeHeader`, `removeAllHeaders`) | Small | 2–3 days | Only useful if users ever need to modify a received `Response` before re-sending, but completing the `Response` API removes the asymmetry. |
| Auth handlers — Basic and Bearer token | Medium | 1 week | Intercept requests at the PAL level (or in a wrapper client) to inject the `Authorization` header. Define `CredentialsConfig` and `BearerTokenConfig` sub-types of `ClientAuthConfig`. |
| Cookie management (`cookieConfig`) | Medium | 1–2 weeks | Use Go's `http.CookieJar` (e.g., `cookiejar.New`). Wire `CookieConfig.enabled`, `maxCookiesPerDomain`, `maxTotalCookieCount`, and `blockThirdPartyCookies` to a custom jar implementation. |

**Total estimated effort: ~4–6 weeks**

---

## v0.4 — Advanced Client Features

**Goal:** Add production-grade resilience patterns and HTTP caching.

| Task | Effort | Estimate | Notes |
|---|---|---|---|
| Circuit breaker (`circuitBreaker`) | Large | 3–4 weeks | Implement a state machine with `CLOSED`, `OPEN`, and `HALF_OPEN` states. Maintain a rolling window of buckets tracking failure counts. Wire `failureThreshold`, `resetTime`, `statusCodes`, and `rollingWindow` from `CircuitBreakerConfig`. |
| OAuth2 auth handler | Large | 2–3 weeks | Client credentials and token exchange flows. Requires token caching and refresh logic. Depends on the auth handler infrastructure from v0.3. |
| HTTP response caching | Large | 3–4 weeks | Honour `Cache-Control`, `ETag`, `Last-Modified`, `If-None-Match`, and `If-Modified-Since`. Requires an in-memory (and optionally persistent) cache store. This is the most complex item in this release. |

**Total estimated effort: ~8–11 weeks**

---

## v0.5 — Type System Integration

**Goal:** Support `targetType`-based response data binding and streaming. Both items are gated on language-level features that must be implemented in the interpreter core before the HTTP-specific work can begin.

| Task | Effort | Estimate | Notes |
|---|---|---|---|
| `targetType` / response data binding | X-Large | 1–2 months | **Lang prerequisite:** `typedesc<T>` must be representable as a Ballerina runtime value (`TypeDesc` value kind), and parameterised return type inference must be wired through the type resolver and BIR gen. Once those exist, the HTTP side maps the resolved `targetType` to `getJsonPayload`, `getTextPayload`, `getBinaryPayload`, or record construction (via the constraint module). This is the single highest-value missing feature. |
| Streaming request body (`stream<byte[], io:Error?>`) | Large | 2–3 weeks | **Lang prerequisite:** `stream<T, E>` must be a runtime value type. Once available, pipe the stream through Go's `io.Reader` interface in `Execute`. Enables large file uploads without buffering the entire body in memory. |
| Streaming response body (`getByteStream`) | Medium | 1–2 weeks | **Lang prerequisite:** same as above. On the Go side, return the `http.Response.Body` reader wrapped as a Ballerina stream rather than buffering it. |
| Server-Sent Events (`getSseEventStream`) | Large | 3–4 weeks | **Lang prerequisite:** `stream<T, E>` runtime type. Additionally requires an SSE frame parser (splitting the `text/event-stream` byte stream into `SseEvent` records). |

**Total estimated effort: ~3–5 months** *(the majority is the lang-level prerequisite work)*

---

## v0.6 — Module Integrations

**Goal:** Unlock features that require sibling module implementations. Each item in this release is blocked on the corresponding module being available in the interpreter.

| Task | Effort | Estimate | Blocked on |
|---|---|---|---|
| `crypto:TrustStore` and `crypto:KeyStore` for TLS | Large | 2–3 weeks | `ballerina/crypto` module |
| `xml` request body and `getXmlPayload()` on Response | Large | 3–4 weeks | XML runtime value type (`values.Xml`) |
| Multipart request body (`mime:Entity[]`) and `getBodyParts()` on Response | Large | 2–3 weeks | `ballerina/mime` module |
| Payload validation (`validation`, `laxDataBinding`) | Medium | 1–2 weeks | `ballerina/constraint` module |
| Status code response type binding (`getStatusCodeRecord`) | Medium | 1–2 weeks | `targetType` (v0.5) |

**Total estimated effort: ~9–14 weeks** *(after module prerequisites are met)*

---

## Future / Long-term

These items are technically complex, have significant external dependencies, or deliver value only to a narrow set of use cases. They are tracked here but not scheduled.

| Task | Complexity | Blocker |
|---|---|---|
| Async HTTP (`submit`, `getResponse`, `HttpFuture`) | High | Goroutine/future model in the interpreter |
| HTTP/2 server push (`hasPromise`, `getNextPromise`, `getPromisedResponse`, `rejectPromise`) | Very High | Go's standard `net/http` server push support is limited and deprecated in HTTP/2 clients; may require `golang.org/x/net/http2` directly |
| Resource function syntax (`client->/path.get(...)`) | Very High | Significant AST/BIR changes to support path parameter expressions |
| `http:Client` and `http:Response` runtime type narrowing (`c is http:Client`, `r is http:Response`) | High | Requires consistent runtime semtype propagation through `execNewObject` |

---

## Dependency Graph

```
v0.2  ──► v0.3 (http:Request) ──► v0.4 (circuit breaker, OAuth2)
                                         │
v0.5 (typedesc<T> lang work) ────────────┤
                                         │
v0.6 (mime / crypto / xml modules) ──────┘
                                         │
                                    Future items
```

Items within each release are largely independent of each other and can be parallelised.

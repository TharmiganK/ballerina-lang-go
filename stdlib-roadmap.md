# Standard Library Roadmap

This document covers the standard library modules planned for the native Ballerina interpreter, beyond the HTTP client already in progress. Modules are grouped into waves based on implementation dependency order, effort, and the value delivered to the most common usage patterns.

## Effort Scale

| Label | Duration |
|---|---|
| Small | 1–3 days |
| Medium | 1–2 weeks |
| Large | 3–4 weeks |
| X-Large | 1–3 months |

## Common Usage Patterns Considered

- **REST client workflows** — HTTP + JSON type binding + auth + logging
- **Data processing / ETL** — CSV, JSON, XML parsing and transformation
- **System automation** — OS process execution, environment config, file I/O, scheduling
- **Microservice infrastructure** — gRPC, messaging (Kafka, RabbitMQ, NATS), caching
- **Security** — Hashing, signing, JWT, OAuth2
- **Real-time communication** — WebSocket, TCP, UDP
- **Legacy integration** — FTP, SMTP/email
- **Database access** — SQL (MySQL, PostgreSQL), Redis, MongoDB

---

## Wave 1 — Core Utilities

These modules have no dependencies on other standard library modules, are needed by almost every non-trivial program, and are straightforward to implement using Go's standard library. They should be prioritised above everything else.

### `ballerina/log`

**Effort:** Small — 1 week  
**Importance:** Critical

Structured levelled logging (`DEBUG`, `INFO`, `WARN`, `ERROR`) to stderr. Every real-world program needs this. The implementation maps directly to Go's `log/slog` package. Key functions: `printDebug`, `printInfo`, `printWarn`, `printError` with optional key-value pairs.

Used in: every pattern.

---

### `ballerina/os`

**Effort:** Small — 1 week  
**Importance:** Critical

Environment variable access (`getEnv`, `setEnv`), process exit (`exit`), command-line argument access, and basic process execution (`exec`). Essential for 12-factor application configuration and scripting. Maps cleanly to `os.Getenv`, `os.Exit`, and `os/exec.Command` in Go.

Used in: system automation, configuration management.

---

### `ballerina/uuid`

**Effort:** Small — 2–3 days  
**Importance:** High

UUID v1 (time-based) and v4 (random) generation, plus parsing and validation. Universally needed for request correlation IDs, entity keys, and trace identifiers. Trivial to implement using `github.com/google/uuid` or Go 1.24's `crypto/rand.Text`.

Used in: REST clients, microservices, database record creation.

---

### `ballerina/time`

**Effort:** Medium — 1–2 weeks  
**Importance:** High

Civil time (`time:Civil`), UTC (`time:Utc`), duration arithmetic, formatting (RFC 3339, RFC 1123, custom patterns), and parsing. Used in HTTP date headers, log timestamps, scheduled tasks, database timestamps, and token expiry checks. Maps to Go's `time` package with careful handling of Ballerina's decimal-seconds representation.

Used in: REST clients, scheduling, logging, auth (JWT expiry), database.

---

### `ballerina/regex`

**Effort:** Medium — 1–2 weeks  
**Importance:** High

Pattern matching, find, replace, split, and group capture. Very commonly used for input validation, parsing structured strings (log lines, config values), and data transformation. Go's `regexp` package provides a direct implementation path.

Used in: data processing, input validation, log parsing.

---

### `ballerina/file`

**Effort:** Medium — 1–2 weeks  
**Importance:** High

File and directory operations: read, write, append, copy, move, delete, list directory, check existence, get metadata. Needed for certificate file handling, configuration files, data import/export, and log archiving. Maps to Go's `os` and `io/fs` packages.

Used in: ETL, system automation, TLS certificate management, configuration.

---

## Wave 2 — Data Handling and Cryptography

These modules unlock data-centric usage patterns and are prerequisites for the authentication modules in Wave 3.

### `ballerina/crypto`

**Effort:** Large — 3–4 weeks  
**Importance:** Critical (prerequisite for auth, jwt, oauth2, and full TLS support)

Hashing (MD5, SHA1, SHA256, SHA384, SHA512), HMAC, CRC32, AES encryption/decryption, RSA and EC key operations (sign, verify), and PEM/DER encoding. Maps to Go's `crypto/*` packages. This module is a hard dependency of `auth`, `jwt`, `oauth2`, and the `crypto:TrustStore`/`crypto:KeyStore` variants in HTTP TLS configuration.

Used in: authentication, TLS, digital signatures, data integrity checks.

---

### `ballerina/mime`

**Effort:** Medium — 1–2 weeks  
**Importance:** High (prerequisite for HTTP multipart and email)

MIME type resolution, content-type parsing, `multipart/form-data` and `multipart/mixed` construction and parsing, and `mime:Entity` record operations. Required by HTTP multipart request/response handling and email attachment support.

Used in: HTTP file uploads, email, content negotiation.

---

### `ballerina/data.jsondata`

**Effort:** X-Large — 6–8 weeks  
**Importance:** Critical (gated on `typedesc<T>` lang-level support)

Type-safe JSON binding: `fromJsonWithType`, `toJson`, `parseString`, `parseStream`. This is Ballerina's most distinctive feature — converting JSON payloads directly into typed records without manual field extraction. The HTTP client's `targetType` binding is built on top of this module. 

**Lang prerequisite:** `typedesc<T>` must be a representable runtime value and the type resolver must support parameterised return types. Until that is done, the HTTP side cannot use this module. The module implementation itself (JSON parsing and record construction) is approximately 3–4 weeks; the lang-level work adds another 3–4 weeks.

Used in: REST client workflows, configuration loading, data processing — the single highest-value data module.

---

### `ballerina/data.csv`

**Effort:** Medium — 1–2 weeks  
**Importance:** Medium-High

CSV parsing with header row support, type coercion (string to int/decimal/boolean), and CSV generation from record arrays. Very common in ETL pipelines, reporting, and data interchange. Does not require `typedesc<T>` for basic string parsing, though typed binding would benefit from it.

Used in: ETL, reporting, data import/export.

---

### `ballerina/data.xmldata`

**Effort:** Large — 3–4 weeks  
**Importance:** Medium (gated on XML runtime value type)

XML-to-record binding and record-to-XML conversion. Required by `getXmlPayload` in the HTTP response and XML-based web service integrations (SOAP, legacy REST). 

**Lang prerequisite:** `values.Xml` runtime type must exist before this module can produce or consume XML values.

Used in: legacy system integration, SOAP, XML configuration files.

---

### `ballerina/constraint`

**Effort:** Medium — 1–2 weeks  
**Importance:** Medium (works best alongside `data.jsondata`)

Annotation-based validation of record fields (`@constraint:String`, `@constraint:Int`, `@constraint:Array`, etc.) with min/max length, pattern, range, and custom validator support. Used in HTTP payload validation (`ClientConfiguration.validation`) and general data integrity enforcement.

Used in: HTTP request/response validation, form processing, data ingestion.

---

### `ballerina/cache`

**Effort:** Medium — 1–2 weeks  
**Importance:** Medium

In-memory key-value cache with TTL, capacity, and eviction policy (LRU). Used for token caching in OAuth2, HTTP response caching, and general memoisation. Implementation uses a Go map with a background eviction goroutine.

Used in: OAuth2 token management, HTTP caching, database query results.

---

## Wave 3 — Authentication and Network Protocols

These modules depend on Wave 2 (particularly `crypto`) and represent the authentication stack and transport protocols beyond HTTP.

### `ballerina/auth`

**Effort:** Medium — 1–2 weeks  
**Importance:** High (prerequisite for jwt, oauth2)  
**Depends on:** `ballerina/crypto`

HTTP authentication handler interfaces: `BasicAuthConfig` (username/password, base64 encoding), `BearerTokenConfig` (header injection), and `CredentialStore` (file-based and in-memory). This is the foundation that `jwt` and `oauth2` build on top of.

Used in: any HTTP client or server requiring authentication.

---

### `ballerina/jwt`

**Effort:** Large — 3–4 weeks  
**Importance:** High  
**Depends on:** `ballerina/crypto`, `ballerina/auth`

JWT generation (signing with RS256, RS384, RS512, ES256, HS256), parsing, and validation (signature, expiry, issuer, audience). Required by OAuth2 and any service using JWT-based API keys or identity tokens. Maps to a Go JWT library (e.g., `golang-jwt/jwt`).

Used in: OAuth2, API gateway integration, service-to-service auth, identity management.

---

### `ballerina/oauth2`

**Effort:** Large — 3–4 weeks  
**Importance:** High  
**Depends on:** `ballerina/auth`, `ballerina/jwt`, `ballerina/http`, `ballerina/cache`

OAuth2 flows: client credentials, password grant, refresh token, and authorization code. Token caching and automatic refresh. This is essential for integrating with any external API (Google, GitHub, Azure, Salesforce, etc.).

Used in: external API integration, SSO, API gateway.

---

### `ballerina/tcp`

**Effort:** Medium — 1–2 weeks  
**Importance:** Medium

TCP client and server: connect, send, receive, close. Byte-oriented streaming with configurable timeouts and TLS support. Needed for custom protocol implementations, telnet-style tools, and any non-HTTP network integration. Maps directly to Go's `net.Dial` and `net.Listen`.

Used in: custom protocols, legacy system integration, network tooling.

---

### `ballerina/udp`

**Effort:** Small — 1 week  
**Importance:** Medium

UDP client and server: send datagram, receive datagram, multicast. Lower complexity than TCP due to connectionless semantics. Used for DNS queries, SNMP, syslog, and real-time telemetry. Maps to Go's `net.PacketConn`.

Used in: telemetry, syslog, DNS, IoT sensor data.

---

### `ballerina/email`

**Effort:** Large — 3–4 weeks  
**Importance:** High

SMTP client for sending emails: plain text, HTML, attachments (via `ballerina/mime`), CC/BCC, reply-to. IMAP/POP3 client for receiving emails. Authentication via PLAIN, LOGIN, and OAuth2. Maps to Go's `net/smtp` for sending and `emersion/go-imap` for IMAP.

Used in: notifications, alerts, report delivery, customer communication workflows.

**Depends on:** `ballerina/mime` (for attachments), `ballerina/crypto` (TLS).

---

### `ballerina/ftp`

**Effort:** Medium — 1–2 weeks  
**Importance:** Medium

FTP and SFTP client: connect, list, get, put, delete, rename. Passive and active mode, TLS (FTPS), and SSH key authentication (SFTP). Still heavily used in enterprise data exchange, EDI, and legacy integration. Maps to `github.com/jlaffaye/ftp` and `golang.org/x/crypto/ssh`.

Used in: enterprise data exchange, EDI, legacy system integration, automated file processing.

---

## Wave 4 — Real-Time and Messaging

### `ballerina/websocket`

**Effort:** Large — 3–4 weeks  
**Importance:** High

WebSocket client (and server listener): connect, send text/binary frames, receive, ping/pong, close. TLS support. Used for real-time dashboards, chat applications, collaborative tools, and live data feeds. Maps to `nhooyr.io/websocket` or `gorilla/websocket` in Go.

Used in: real-time notifications, live dashboards, collaborative apps, streaming APIs.

---

### `ballerina/nats`

**Effort:** Large — 3–4 weeks  
**Importance:** Medium

NATS publish/subscribe, request/reply, and JetStream (persistent messaging). Simpler than Kafka, excellent for microservice fan-out, event notification, and service mesh patterns. Maps to `nats-io/nats.go`.

Used in: microservice event distribution, lightweight pub/sub, service mesh.

---

### `ballerina/rabbitmq`

**Effort:** Large — 3–4 weeks  
**Importance:** Medium-High

AMQP 0-9-1 producer and consumer: exchange declaration, queue binding, message publishing, consumer acknowledgement, dead-letter queues. The dominant enterprise message broker. Maps to `rabbitmq/amqp091-go`.

Used in: task queues, work distribution, event-driven architectures, enterprise integration.

---

### `ballerina/kafka`

**Effort:** X-Large — 6–8 weeks  
**Importance:** High

Kafka producer and consumer: topic management, partitioning, consumer groups, offset management, schema registry integration. The dominant stream processing platform. Complex due to the Kafka protocol and consumer group coordination. Maps to `confluentinc/confluent-kafka-go` or `segmentio/kafka-go`.

Used in: event streaming, log aggregation, data pipelines, microservice choreography.

---

### `ballerina/task`

**Effort:** Medium — 1–2 weeks  
**Importance:** Medium

Scheduled and one-shot job execution: cron expressions, fixed-interval polling, one-time delays. Uses Go goroutines and `time.Ticker`/`time.AfterFunc`. Needed for polling integrations, report generation, cache refresh, and health checks.

Used in: scheduled reports, polling integrations, cache warm-up, background maintenance.

---

## Wave 5 — Database

Database modules are the most impactful for backend application development but are also the most complex to implement correctly, particularly around connection pooling, transaction management, and type mapping.

### `ballerina/sql` (abstraction layer)

**Effort:** X-Large — 2–3 months  
**Importance:** Critical (prerequisite for all DB drivers)

The `sql` module defines the common interface (`sql:Client`, `sql:ParameterizedQuery`, `sql:Column`, connection pooling, transaction API) that all database drivers implement. Must be implemented first. Internally maps to Go's `database/sql` package.

---

### `ballerina/mysql`

**Effort:** Large — 3–4 weeks (after `sql`)  
**Importance:** High  
**Depends on:** `ballerina/sql`

MySQL and MariaDB driver. Maps to `go-sql-driver/mysql`. Supports connection pooling, TLS, prepared statements, and stored procedures.

---

### `ballerina/postgresql`

**Effort:** Large — 3–4 weeks (after `sql`)  
**Importance:** High  
**Depends on:** `ballerina/sql`

PostgreSQL driver. Maps to `jackc/pgx`. Supports connection pooling, TLS, LISTEN/NOTIFY, and PostgreSQL-specific types (arrays, JSONB, UUID).

---

### `ballerina/redis`

**Effort:** Large — 3–4 weeks  
**Importance:** High

Redis client: string, hash, list, set, sorted set, pub/sub, streams, Lua scripting, Cluster and Sentinel support. Used for caching, session storage, leaderboards, rate limiting, and real-time pub/sub. Maps to `redis/go-redis`.

Used in: session management, rate limiting, leaderboards, real-time analytics, distributed caching.

---

### `ballerina/mongodb`

**Effort:** Large — 3–4 weeks  
**Importance:** Medium

MongoDB client: CRUD operations, aggregation pipeline, indexing, GridFS, change streams. Maps to `mongodb/mongo-go-driver`.

Used in: document storage, content management, product catalogues, event stores.

---

## Wave 6 — Service Infrastructure

### `ballerina/grpc`

**Effort:** X-Large — 2–3 months  
**Importance:** High

gRPC client (and service skeleton): unary, server-streaming, client-streaming, and bidirectional-streaming RPCs. Protobuf encoding/decoding. TLS with client certificates. This is the dominant inter-service communication protocol in microservice architectures. Requires both a Protobuf runtime and the gRPC wire protocol, making it the most complex single module on this list.

Used in: microservice communication, mobile backends, internal APIs.

---

### `ballerina/observe`

**Effort:** Large — 3–4 weeks  
**Importance:** Medium-High

Metrics (counter, gauge, histogram), distributed tracing (OpenTelemetry spans, trace context propagation), and log correlation. Exports to Prometheus, Jaeger, Zipkin, and OpenTelemetry Collector. Essential for operating services in production.

Used in: production observability, SLA monitoring, distributed debugging.

---

## Summary by Priority

| Priority | Module | Wave | Effort | Key Dependency |
|---|---|---|---|---|
| 1 | `ballerina/log` | 1 | Small | — |
| 2 | `ballerina/os` | 1 | Small | — |
| 3 | `ballerina/uuid` | 1 | Small | — |
| 4 | `ballerina/time` | 1 | Medium | — |
| 5 | `ballerina/regex` | 1 | Medium | — |
| 6 | `ballerina/file` | 1 | Medium | — |
| 7 | `ballerina/crypto` | 2 | Large | — |
| 8 | `ballerina/mime` | 2 | Medium | — |
| 9 | `ballerina/data.jsondata` | 2 | X-Large | `typedesc<T>` lang support |
| 10 | `ballerina/data.csv` | 2 | Medium | — |
| 11 | `ballerina/constraint` | 2 | Medium | — |
| 12 | `ballerina/cache` | 2 | Medium | — |
| 13 | `ballerina/auth` | 3 | Medium | `crypto` |
| 14 | `ballerina/jwt` | 3 | Large | `crypto`, `auth` |
| 15 | `ballerina/oauth2` | 3 | Large | `auth`, `jwt`, `http`, `cache` |
| 16 | `ballerina/email` | 3 | Large | `mime`, `crypto` |
| 17 | `ballerina/tcp` | 3 | Medium | — |
| 18 | `ballerina/udp` | 3 | Small | — |
| 19 | `ballerina/ftp` | 3 | Medium | `crypto` |
| 20 | `ballerina/websocket` | 4 | Large | — |
| 21 | `ballerina/rabbitmq` | 4 | Large | — |
| 22 | `ballerina/nats` | 4 | Large | — |
| 23 | `ballerina/task` | 4 | Medium | `time` |
| 24 | `ballerina/kafka` | 4 | X-Large | — |
| 25 | `ballerina/sql` | 5 | X-Large | — |
| 26 | `ballerina/redis` | 5 | Large | — |
| 27 | `ballerina/mysql` | 5 | Large | `sql` |
| 28 | `ballerina/postgresql` | 5 | Large | `sql` |
| 29 | `ballerina/mongodb` | 5 | Large | — |
| 30 | `ballerina/data.xmldata` | 2 | Large | XML runtime type |
| 31 | `ballerina/observe` | 6 | Large | — |
| 32 | `ballerina/grpc` | 6 | X-Large | Protobuf runtime |

---

## Dependency Graph

```
Wave 1: log, os, uuid, time, regex, file
           │
Wave 2: crypto ──────────────────────────────────────────────────────────────┐
        mime                                                                  │
        data.jsondata (needs typedesc<T>)                                     │
        data.csv, constraint, cache                                           │
           │                                                                  │
Wave 3: auth ◄── crypto                                                       │
        jwt  ◄── crypto, auth                                                 │
        oauth2 ◄─ auth, jwt, http, cache                                      │
        email ◄── mime, crypto                                                │
        tcp, udp, ftp ◄── crypto (TLS)                                        │
           │                                                                  │
Wave 4: websocket                                                             │
        rabbitmq, nats, kafka                                                 │
        task ◄── time                                                         │
           │                                                                  │
Wave 5: sql ──► mysql, postgresql                                             │
        redis, mongodb                                                        │
           │                                                                  │
Wave 6: grpc (needs Protobuf runtime)                                         │
        observe                                                               │
           └──────────────────────────────────────────────────────────────────┘
                              all modules benefit from observe
```

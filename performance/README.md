# Ballerina Nutcracker — HTTP Performance Benchmarks

This suite compares **Ballerina Nutcracker** (the Go-native interpreter in this repo) against other runtimes on realistic HTTP workloads, on a single machine. It launches each runtime's service as a native process, drives load with [`wrk`](https://github.com/wg/wrk), samples memory/CPU, and emits a Markdown report.

## Runtimes compared

| Key | Runtime | Launched as |
|---|---|---|
| `nutcracker` | Ballerina Nutcracker (this repo) | `<repo>/bal run` |
| `nutcracker-native` | Ballerina Nutcracker, `bal build` executable | `<repo>/bal build` binary |
| `swanlake` | Ballerina Swan Lake (jBallerina) | jBallerina `bal run` |
| `swanlake-graalvm` | Ballerina Swan Lake, GraalVM native image | `bal build --graalvm` binary |
| `go` | Go (`net/http`) | compiled binary |
| `rust` | Rust (axum + tokio) | compiled binary |
| `node` | Node.js (`http`) | `node` |
| `node-express` | Node.js + Express | `node` |
| `bun` | Bun (`Bun.serve`) | `bun` |
| `python` | Python (`http.server`) | `python3` |
| `python-flask` | Python + Flask | `waitress-serve` (WSGI) |
| `python-fastapi` | Python + FastAPI | `uvicorn` (ASGI, uvloop + httptools, one worker per core) |
| `java-netty` | Java + Netty | `java -jar` |
| `graalvm-netty` | Java + Netty, GraalVM native image | `native-image` binary |
| `java-spring` | Java + Spring Boot WebFlux (Reactor Netty) | `java -jar` |
| `dotnet` | C# / ASP.NET Core (Kestrel minimal API) | `dotnet` |

By default the suite runs the primary Ballerina runtimes against one industry-leading stack per language: `nutcracker`, `nutcracker-native`, `swanlake`, `go`, `rust`, `node`, `python-fastapi`, `java-spring`, `dotnet`. The stdlib/legacy baselines (`python`, `python-flask`, `node-express`, `bun`, `java-netty`) and the remaining native-image variants (`swanlake-graalvm`, `graalvm-netty`) join in with `--runtimes all` or an explicit `--runtimes` list.

`nutcracker-native` runs the same `services/ballerina/{hello,passthrough}.bal` sources compiled ahead-of-time via this repo's `bal build` into a standalone executable, rather than interpreted through `bal run`. Its executables are written to `services/ballerina/nutcracker-native/<stem>` — a dedicated directory kept separate from `swanlake-graalvm`'s images (which share `services/ballerina/<stem>`), so the two never clobber each other. `bal build` packs onto a `balrt` runner stub; for a local repo build the suite builds that stub next to `<repo>/bal` automatically (requires the Go toolchain).

## Scenarios

1. **hello-service** — `GET /hello` returns a fixed `Hello, World!` body. No backend. Measures raw framework throughput across concurrent-user counts.
2. **passthrough** — `POST /passthrough` forwards the request body to a shared Netty echo backend on port `8688`. Measures proxy throughput across payload sizes × concurrent-user counts.

The two Ballerina runtimes share one source tree (`services/ballerina/{hello,passthrough}.bal`); only the runtime differs. Every service binds the same port (`9090`), speaks HTTP/1.1 with keep-alive, and forwards to the same backend, so the comparison is apples-to-apples.

## Networking configuration

For a fair comparison every runtime is configured to the same networking baseline — the jBallerina `http:Client` defaults, which the Go passthrough was hand-tuned to mirror:

| Setting | Value |
|---|---|
| Connection reuse (HTTP keep-alive) | enabled |
| Max active connections per host | unlimited |
| Max idle connections per host | 100 |
| Idle / socket timeout | 300s |
| Connect timeout | 15s |
| TCP `TCP_NODELAY` | on |
| Client-side TCP `SO_KEEPALIVE` | off |
| Response decompression | off |

How each runtime maps onto it:

| Runtime | Pool / connection config |
|---|---|
| `nutcracker`, `swanlake`, `swanlake-graalvm` | `http:Client` `poolConfig` set explicitly to `maxActiveConnections = -1`, `maxIdleConnections = 100` (also the jBallerina default). |
| `go` | `http.Transport`: `MaxIdleConnsPerHost = 100`, `MaxConnsPerHost = 0`, `IdleConnTimeout = 300s`, dial `KeepAlive = -1`, 32 KB buffers, `DisableCompression`. |
| `rust` | `reqwest` client: `pool_max_idle_per_host = 100`, `pool_idle_timeout = 300s`, 15s connect timeout, `TCP_NODELAY` on, no compression features enabled. |
| `bun` | Bun's built-in `fetch`: upstream keep-alive on by default; no user-facing pool configuration. |
| `node`, `node-express` | `http.Agent`: `keepAlive`, `maxSockets = 0`, `maxFreeSockets = 100`, `timeout = 300000`. |
| `python-flask` | `requests` session with `HTTPAdapter(pool_maxsize = 100)`. |
| `python` | stdlib has no shared pool; one reused keep-alive connection per worker thread (300s timeout). |
| `python-fastapi` | `aiohttp.ClientSession` with `TCPConnector(limit = 0, keepalive_timeout = 300)`, 15s connect timeout, decompression off. |
| `java-netty`, `graalvm-netty` | Netty `SimpleChannelPool` (unlimited active, connections reused), `TCP_NODELAY` on, `SO_KEEPALIVE` off, 15s connect timeout. |
| `java-spring` | Reactor Netty `ConnectionProvider`: `maxConnections = 10000` (effectively unlimited), `maxIdleTime = 300s`, 15s connect timeout, compression off. |
| `dotnet` | `SocketsHttpHandler`: `MaxConnectionsPerServer` unlimited, `PooledConnectionIdleTimeout = 300s`, 15s connect timeout, no decompression. |

The honest deviations, imposed by what each stack can express: the plain-`python` runtime has no central pool (per-thread connection); several pools have no fixed *idle*-connection cap and instead reuse all released connections (Netty's `SimpleChannelPool`, Reactor Netty, aiohttp, .NET's `SocketsHttpHandler`); each uvicorn worker process holds its own aiohttp pool (Python's multi-process scaling model); and Bun's built-in `fetch` keeps connections alive but exposes no pool knobs at all. Everything else is aligned.

## Metrics

Per runtime × scenario × configuration:

| Metric | Source |
|---|---|
| Startup time (s) | wall-clock from launch until the port accepts connections |
| Throughput (req/s) | wrk `Requests/sec` |
| Average latency (ms) | wrk `Latency` avg |
| p99 latency (ms) | wrk `Latency Distribution` 99% |
| Latency std-dev (ms) | wrk `Latency` stdev |
| Max latency (ms) | wrk `Latency` max |
| Max memory (MB) | peak RSS sampled every 0.1s (`lsof` + `ps`, server + children) |
| Max CPU (%) | peak aggregate CPU sampled every 0.1s |
| Error rate (%) | wrk socket errors + non-2xx/3xx ÷ total requests |

## Prerequisites

Install what you need for the runtimes you plan to run:

- **`wrk`** (load generator) and **`lsof`** — always required.
- **Go** 1.26+ — for `go`, and to build this repo's `bal` (`go build -o bal ./cli/cmd` from the repo root). Also used by `nutcracker-native` to build the `balrt` runner stub `bal build` packs onto (done automatically on first run).
- **Rust** (rustup/`cargo`) — for `rust` (`cargo build --release` runs automatically on first run).
- **Bun** — for `bun`.
- **.NET SDK 9** — for `dotnet` (`dotnet publish` runs automatically on first run).
- **jBallerina** (Swan Lake) on `PATH` as `bal` — for `swanlake` and `swanlake-graalvm`. Override with `SWAN_BAL=/path/to/bal`.
- **GraalVM** JDK with `native-image` on `PATH` — for `swanlake-graalvm` and `graalvm-netty`. These native images are built on first run (each takes a minute or two); if `native-image` is absent the two GraalVM runtimes are skipped with a warning.
- **Java 21** + **Maven** — for `java-netty`, `graalvm-netty`, `java-spring`, and the Netty backend (built automatically on first run).
- **Node.js** + **npm** — for `node` and `node-express` (`npm install` runs automatically for Express).
- **Python 3** — for `python`; plus `pip install -r services/python-flask/requirements.txt` for `python-flask`, and `pip install -r services/python-fastapi/requirements.txt` for `python-fastapi`.

Build artifacts (Go binaries, jars, `node_modules`) are produced on first run and are git-ignored — nothing precompiled is committed.

## Running

```bash
# Both scenarios, default runtime set (Ballerina vs industry leaders), default grid.
./performance/run.sh

# Every runtime, including stdlib/legacy baselines and GraalVM native images.
./performance/run.sh --runtimes all

# A focused run.
./performance/run.sh --scenario passthrough --runtimes nutcracker,go,swanlake \
    --users 100,200,500 --payloads 1KB,10KB,50KB --warmup 30s --duration 60s

# Just Nutcracker vs Go, hello world.
./performance/run.sh --scenario hello-service --runtimes nutcracker,go --users 100,500
```

Options: `--scenario hello-service|passthrough|all`, `--runtimes <list>|all|default`, `--users <list>`, `--payloads <list>`, `--warmup`, `--duration`, `--threads`, `--output`. See `./performance/run.sh --help`.

Each run writes a full timestamped report to `results/` (git-ignored). Curated cross-runtime summaries live in [`benchmarks/`](benchmarks/).

## Load-tool note

`wrk` runs closed-loop: `--users` maps to wrk connections (`-c`), matching the "concurrent users" model. It is a tiny C binary, so on a single VM it does not starve the service-under-test the way a JVM-based generator would — important for accurate max-CPU/memory readings. `wrk` v1 is subject to **coordinated omission**, so tail-latency (p99) under saturation is optimistic; for open-loop constant-rate testing use `wrk2` (`-R`) or k6.

## Layout

```
performance/
├── run.sh              # orchestrator
├── scripts/            # lib.sh, parse_wrk.sh, report.sh, post_payload.lua
├── backend/            # shared Netty echo backend (Maven, Java 21)
├── services/           # one dir per runtime (hello + passthrough)
├── payloads/           # 1KB..1MB request-body fixtures
├── results/            # raw timestamped reports (git-ignored)
└── benchmarks/         # curated summary reports (committed)
```

## Future work

The harness currently runs the load generator and all services on one machine. A distributed setup — dedicated load-generator host(s) separate from the service-under-test, over the network — is out of scope for now; the layout keeps that path open.

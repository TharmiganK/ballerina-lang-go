# Ballerina Nutcracker — HTTP Performance Benchmarks

This suite compares **Ballerina Nutcracker** (the Go-native interpreter in this repo) against other runtimes on realistic HTTP workloads, on a single machine. It launches each runtime's service as a native process, drives load with [`wrk`](https://github.com/wg/wrk), samples memory/CPU, and emits a Markdown report.

## Runtimes compared

| Key | Runtime | Launched as |
|---|---|---|
| `nutcracker` | Ballerina Nutcracker, `bal build` executable (this repo) | `<repo>/bal build` binary |
| `nutcracker-run` | Ballerina Nutcracker, interpreted (this repo) | `<repo>/bal run` |
| `swanlake` | Ballerina Swan Lake (jBallerina) | jBallerina `bal build` jar, launched with `java -jar` |
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
| `dotnet-aot` | C# / ASP.NET Core, .NET Native AOT | native binary |

By default the suite runs the recommended Ballerina runtime against one industry-leading stack per language: `nutcracker`, `swanlake`, `go`, `rust`, `java-spring`, `dotnet`, `node`, `python-fastapi`. Every default runtime is launched as its production artifact (a compiled binary, a prebuilt jar/DLL, or the ecosystem's recommended server), so none recompiles on start. The interpreted `bal run` variant (`nutcracker-run`), the stdlib/legacy baselines (`python`, `python-flask`, `node-express`, `bun`, `java-netty`), and the remaining native-image variants (`swanlake-graalvm`, `graalvm-netty`, `dotnet-aot`) join in with `--runtimes all` or an explicit `--runtimes` list.

`nutcracker` (the default, recommended for production) runs the `services/ballerina/{hello,passthrough}.bal` sources compiled ahead-of-time via this repo's `bal build` into a standalone executable; `nutcracker-run` runs the same sources interpreted through `bal run` and is kept out of the default list. The `nutcracker` executables are written to `services/ballerina/nutcracker-native/<stem>` — a dedicated directory kept separate from `swanlake-graalvm`'s images (which share `services/ballerina/<stem>`), so the two never clobber each other. `bal build` packs onto a `balrt` runner stub; for a local repo build the suite builds that stub next to `<repo>/bal` automatically (requires the Go toolchain).

## Scenarios

1. **hello-service** — `GET /hello` returns a fixed `Hello, World!` body. No backend. Measures raw framework throughput across concurrent-user counts.
2. **passthrough** — `POST /passthrough` forwards the request body to a shared Netty echo backend on port `8688`. Measures proxy throughput across payload sizes × concurrent-user counts.

The two Ballerina runtimes share one source tree (`services/ballerina/{hello,passthrough}.bal`); only the runtime differs. Every service binds the same port (`9090`), speaks HTTP/1.1 with keep-alive, and forwards to the same backend, so the comparison is apples-to-apples.

## Networking configuration

For a fair comparison every runtime is configured to the same networking baseline. The idle pool is sized to **512** — above the suite's 500-user peak — so backend keep-alive connections are reused rather than evicted and re-dialed between requests. (The earlier jBallerina/Go default of 100 idle throttled every runtime whose stack *has* an idle cap by ~20% at 200 users through connection churn, while the stacks with no cap — Netty, Reactor Netty, aiohttp, .NET — reused everything; 512 levels that so the comparison stays fair and representative of a real deployment.)

| Setting | Value |
|---|---|
| Connection reuse (HTTP keep-alive) | enabled |
| Max active connections per host | unlimited |
| Max idle connections per host | 512 (≥ peak load) |
| Idle / socket timeout | 300s |
| Connect timeout | 15s |
| TCP `TCP_NODELAY` | on |
| Client-side TCP `SO_KEEPALIVE` | off |
| Response decompression | off |

How each runtime maps onto it:

| Runtime | Pool / connection config |
|---|---|
| `nutcracker`, `nutcracker-run`, `swanlake`, `swanlake-graalvm` | `http:Client` `poolConfig` set explicitly to `maxActiveConnections = -1`, `maxIdleConnections = 512`. |
| `go` | `http.Transport`: `MaxIdleConnsPerHost = 512`, `MaxConnsPerHost = 0`, `IdleConnTimeout = 300s`, dial `KeepAlive = -1`, 32 KB buffers, `DisableCompression`. |
| `rust` | `reqwest` client: `pool_max_idle_per_host = 512`, `pool_idle_timeout = 300s`, 15s connect timeout, `TCP_NODELAY` on, no compression features enabled. |
| `bun` | Bun's built-in `fetch`: upstream keep-alive on by default; no user-facing pool configuration. |
| `node`, `node-express` | `http.Agent`: `keepAlive`, `maxSockets = 0`, `maxFreeSockets = 512`, `timeout = 300000`. |
| `python-flask` | `requests` session with `HTTPAdapter(pool_maxsize = 512)`. |
| `python` | stdlib has no shared pool; one reused keep-alive connection per worker thread (300s timeout). |
| `python-fastapi` | `aiohttp.ClientSession` with `TCPConnector(limit = 0, keepalive_timeout = 300)`, 15s connect timeout, decompression off. |
| `java-netty`, `graalvm-netty` | Netty `SimpleChannelPool` (unlimited active, connections reused), `TCP_NODELAY` on, `SO_KEEPALIVE` off, 15s connect timeout. |
| `java-spring` | Reactor Netty `ConnectionProvider`: `maxConnections = 10000` (effectively unlimited), `maxIdleTime = 300s`, 15s connect timeout, compression off. |
| `dotnet` | `SocketsHttpHandler`: `MaxConnectionsPerServer` unlimited, `PooledConnectionIdleTimeout = 300s`, 15s connect timeout, no decompression. |

The honest deviations, imposed by what each stack can express: the plain-`python` runtime has no central pool (per-thread connection); several pools have no fixed *idle*-connection cap and instead reuse all released connections (Netty's `SimpleChannelPool`, Reactor Netty, aiohttp, .NET's `SocketsHttpHandler`); each uvicorn worker process holds its own aiohttp pool (Python's multi-process scaling model); and Bun's built-in `fetch` keeps connections alive but exposes no pool knobs at all. Everything else is aligned.

## Metrics

Each `(scenario, runtime, user-count, payload)` combination is measured on its **own freshly cold-started service process** — startup is timed once per `(scenario, runtime)`, then a new instance is launched (and warmed up) before every measured run. This keeps runs independent: heaps are high-water-mark, so a process shared across ascending user counts would carry earlier growth into the later memory readings. Because a discarded warmup precedes every measured run, JIT runtimes still reach steady state — but the warmup (`--warmup`) must be long enough to fully re-warm a cold JVM/GraalVM, or their throughput/latency will read low.

Per runtime × scenario × configuration:

| Metric | Source |
|---|---|
| Startup time (s) | min over 3 cold starts (`--startup-runs`) of the wall-clock from launch until the port accepts connections, polled every 1ms |
| Throughput (req/s) | wrk `Requests/sec` |
| Average latency (ms) | wrk `Latency` avg |
| p99 latency (ms) | wrk `Latency Distribution` 99% |
| Latency std-dev (ms) | wrk `Latency` stdev |
| Max latency (ms) | wrk `Latency` max |
| Max memory (MB) | peak RSS sampled every 0.1s (`lsof` + `ps`, server + children) |
| Max CPU (%) | peak aggregate CPU sampled every 0.1s |
| Error rate (%) | wrk socket errors + non-2xx/3xx ÷ total requests |
| Startup RSS (MB) | `--cold-start` only: RSS of the listening process sampled once, before any load |
| First-request latency (ms) | `--cold-start` only: round-trip of the single first HTTP request against the cold service (`curl %{time_total}`, which excludes curl's own startup). The readiness wait is a bare TCP probe, so this request pays the JVM's class-load + first-hit handler JIT. For passthrough the JVM backend is pre-warmed first (see below) so this number reflects the runtime under test, not the backend's cold start |
| Cold-start warmup curve (req/s) | `--cold-start` only: throughput over `--cold-windows` back-to-back `1s` windows at `--cold-users`, from a cold process with **no** discarded warmup |

### Cold start & warmup (`--cold-start`)

The steady-state grid above deliberately re-warms every runtime before measuring, so it reports each runtime at its peak. That flatters JIT runtimes: in cloud scale-to-zero / autoscaling there is **no** warmup window — a fresh instance must serve request #1 at full tilt. `--cold-start` measures that regime. On the freshly launched (JIT-cold) instance it samples startup RSS, then drives a short series of back-to-back windows with no discarded warmup and reports throughput per window. AOT runtimes (`go`, `rust`, `nutcracker`, `swanlake-graalvm`) are flat from window 1; JIT runtimes (`swanlake`, `java-spring`, `dotnet`, `node`) ramp as tiers compile — that gap is the cold-start penalty the steady-state numbers hide. The curve runs on the already-launched instance, so it adds only `--cold-windows × 1s` per runtime. Keep JVM/CLR flags at their realistic defaults — hobbling the JIT would make the comparison dishonest; note too that GraalVM native-image is AOT-for-Java and closes most of this gap.

**Passthrough backend fairness.** The passthrough backend is itself a cold JVM that JITs on its first requests. Whichever runtime is measured first would otherwise be charged for that backend cold-start — a ~20 ms first-request penalty later runtimes never see (an observed 26 ms first request for the first runtime collapsed to ~2 ms once the backend was warm). So under `--cold-start` the harness fires a short `wrk` burst at the backend before any runtime is measured, isolating the runtime-under-test's own cold cost. (Steady-state runs are unaffected: each discards its own warmup, which already warms the backend.)

## Prerequisites

Install what you need for the runtimes you plan to run:

- **`wrk`** (load generator) and **`lsof`** — always required.
- **Go** 1.26+ — for `go`, and to build this repo's `bal` (`go build -o bal ./cli/cmd` from the repo root). Also used by `nutcracker` to build the `balrt` runner stub `bal build` packs onto (done automatically on first run).
- **Rust** (rustup/`cargo`) — for `rust` (`cargo build --release` runs automatically on first run).
- **Bun** — for `bun`.
- **.NET SDK 9** — for `dotnet` (`dotnet publish` runs automatically on first run). `dotnet-aot` additionally needs a C toolchain (`clang`/`ld`; on macOS the Xcode Command Line Tools, on Linux `clang` + `zlib`) for the Native AOT link step, and its `dotnet publish -p:PublishAot` first build takes a minute or two.
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

# Add the AOT-vs-JIT cold-start story (startup RSS + warmup curve).
./performance/run.sh --scenario hello-service --runtimes nutcracker,swanlake --cold-start

# Only the cold-start metrics, skipping the (much longer) steady-state grid.
./performance/run.sh --runtimes nutcracker,swanlake,go,dotnet --cold-start-only
```

Options: `--scenario hello-service|passthrough|all`, `--runtimes <list>|all|default`, `--users <list>`, `--payloads <list>`, `--warmup`, `--duration`, `--threads`, `--output`, `--cold-start` (+ `--cold-windows`, `--cold-users`), `--cold-start-only`. See `./performance/run.sh --help`.

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

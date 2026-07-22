# Ballerina Nutcracker — HTTP Performance Benchmarks

This suite compares **Ballerina Nutcracker** (the Go-native interpreter in this repo) against other runtimes on realistic HTTP workloads, on a single machine. It launches each runtime's service as a native process, drives load with [`wrk`](https://github.com/wg/wrk), samples memory/CPU, and emits a Markdown report.

## Runtimes compared

| Key | Runtime | Launched as |
|---|---|---|
| `nutcracker` | Ballerina Nutcracker (this repo) | `<repo>/bal run` |
| `swanlake` | Ballerina Swan Lake (jBallerina) | jBallerina `bal run` |
| `swanlake-graalvm` | Ballerina Swan Lake, GraalVM native image | `bal build --graalvm` binary |
| `go` | Go (`net/http`) | compiled binary |
| `node` | Node.js (`http`) | `node` |
| `node-express` | Node.js + Express | `node` |
| `python` | Python (`http.server`) | `python3` |
| `python-flask` | Python + Flask | `waitress-serve` (WSGI) |
| `java-netty` | Java + Netty | `java -jar` |
| `graalvm-netty` | Java + Netty, GraalVM native image | `native-image` binary |

## Scenarios

1. **hello-service** — `GET /hello` returns a fixed `Hello, World!` body. No backend. Measures raw framework throughput across concurrent-user counts.
2. **passthrough** — `POST /passthrough` forwards the request body to a shared Netty echo backend on port `8688`. Measures proxy throughput across payload sizes × concurrent-user counts.

The two Ballerina runtimes share one source tree (`services/ballerina/{hello,passthrough}.bal`); only the runtime differs. Every service binds the same port (`9090`), speaks HTTP/1.1 with keep-alive, and forwards to the same backend, so the comparison is apples-to-apples.

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
- **Go** 1.26+ — for `go`, and to build this repo's `bal` (`go build -o bal ./cli/cmd` from the repo root).
- **jBallerina** (Swan Lake) on `PATH` as `bal` — for `swanlake` and `swanlake-graalvm`. Override with `SWAN_BAL=/path/to/bal`.
- **GraalVM** JDK with `native-image` on `PATH` — for `swanlake-graalvm` and `graalvm-netty`. These native images are built on first run (each takes a minute or two); if `native-image` is absent the two GraalVM runtimes are skipped with a warning.
- **Java 21** + **Maven** — for `java-netty`, `graalvm-netty`, and the Netty backend (built automatically on first run).
- **Node.js** + **npm** — for `node` and `node-express` (`npm install` runs automatically for Express).
- **Python 3** — for `python`; plus `pip install -r services/python-flask/requirements.txt` for `python-flask`.

Build artifacts (Go binaries, jars, `node_modules`) are produced on first run and are git-ignored — nothing precompiled is committed.

## Running

```bash
# Everything: both scenarios, all runtimes, default grid.
./performance/run.sh

# A focused run.
./performance/run.sh --scenario passthrough --runtimes nutcracker,go,swanlake \
    --users 100,200,500 --payloads 1KB,10KB,50KB --warmup 30s --duration 60s

# Just Nutcracker vs Go, hello world.
./performance/run.sh --scenario hello-service --runtimes nutcracker,go --users 100,500
```

Options: `--scenario hello-service|passthrough|all`, `--runtimes <list>|all`, `--users <list>`, `--payloads <list>`, `--warmup`, `--duration`, `--threads`, `--output`. See `./performance/run.sh --help`.

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

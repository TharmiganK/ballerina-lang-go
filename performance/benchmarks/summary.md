# Performance Summary — Nutcracker vs. the industry leaders

**Version** · `v0.6.0-2d2a871-20260724`

> **Draft — preliminary.** How **Ballerina Nutcracker** compares to the industry's leading web runtimes as traffic climbs from **100 → 200 → 500 concurrent users**. Short version: **near-instant startup, a small footprint, and competitive performance — a native, no-JVM alternative to the JVM-based Swan Lake distribution.**

> **Experimental project. Ballerina Swan Lake remains the production distribution.**

**Test at a glance:** a lightweight “hello” HTTP service · **100, 200 & 500** concurrent users · **30-minute** measured runs (10-minute warm-up) · AWS EC2 m6a.xlarge (4 vCPU, 16 GiB, Amazon Linux 2023) · load via wrk. **Every runtime completed all requests with 0 errors.**

**Runtimes & versions:** Ballerina Nutcracker v0.6.0 · Ballerina Swan Lake 2201.13.4 · Rust 1.97.1 · .NET 9.0.118 · Go 1.26.5 · Java 21 / Spring Boot 3.5.4 · Node.js 18.20.8 · Python 3.9.25 (FastAPI).

**Two ways to run Nutcracker.** Nutcracker appears twice. **`bal run`** interprets on the fly. **`bal build`** compiles your code to BIR ahead of time and packages that BIR alongside the same Go interpreter into one standalone binary — it is *not* native machine code; at launch it simply unpacks the BIR and feeds it to the interpreter, skipping the compiler front-end. So the two share an execution engine (near-identical throughput), and the build just trims startup and footprint.

## How to read these charts

The load charts give each runtime **three bars — 100, 200, 500 users** (left → right): read a row to see how it **scales with load**, read a column to compare **runtimes at the same load**. Startup is a one-time value (single bar). Every chart is **ranked best-first**. Both **Nutcracker** rows are in bold; _Swan Lake_ is in italics.

## Time to start serving — seconds _(lower is better; measured once at launch)_

| Runtime | | sec |
|---|---|---:|
| Rust | `▏` | 0.013 |
| Go | `▏` | 0.016 |
| **Ballerina Nutcracker (bal build)** | `▏` | 0.022 |
| Node.js | `▏` | 0.042 |
| **Ballerina Nutcracker (bal run)** | `▏` | 0.044 |
| .NET (ASP.NET Core) | `█` | 0.235 |
| Python (FastAPI) | `██` | 0.599 |
| Java (Spring Boot) | `███████` | 2.234 |
| _Ballerina Swan Lake_ | `███████████████` | 4.739 |

**Takeaway:** Nutcracker is ready in ~0.04 s (and ~0.02 s as a `bal build` binary) — in the instant-start group with Rust, Go and Node — while the JVM-based Swan Lake needs ~4.7 s, roughly **108× longer**.

## Traffic handled — requests/sec _(higher is better)_

| Runtime | 100 users | 200 users | 500 users |
|---|---|---|---|
| Rust | `███████████████` 152,074 | `███████████████` 155,133 | `███████████████` 154,527 |
| .NET (ASP.NET Core) | `███████████` 108,954 | `███████████` 115,215 | `████████████` 119,776 |
| Go | `█████████` 94,937 | `█████████` 95,622 | `█████████` 97,449 |
| **Ballerina Nutcracker (bal run)** | `██████` 64,607 | `██████` 66,241 | `██████` 65,893 |
| **Ballerina Nutcracker (bal build)** | `██████` 62,445 | `██████` 64,987 | `██████` 65,164 |
| Java (Spring Boot) | `██████` 61,037 | `██████` 60,822 | `██████` 61,546 |
| _Ballerina Swan Lake_ | `████` 37,748 | `████` 39,620 | `████` 40,585 |
| Node.js | `███` 27,119 | `███` 27,299 | `███` 26,049 |
| Python (FastAPI) | `█` 11,134 | `█` 10,841 | `█` 9,651 |

**Takeaway:** on 4 cores every runtime is at its ceiling by 100 users, so throughput stays essentially **flat** as load grows 5×. The compiled/tuned stacks (Rust, .NET, Go) lead; Nutcracker holds a steady ~65k req/s — ahead of Node.js and Python, and now a step above Java / Spring Boot. `bal run` and `bal build` land within ~1% of each other, as expected from a shared interpreter.

## Response time — average latency in ms _(lower is better)_

| Runtime | 100 users | 200 users | 500 users |
|---|---|---|---|
| Rust | `▏` 0.63 | `▏` 1.24 | `█` 3.14 |
| .NET (ASP.NET Core) | `▏` 0.89 | `▏` 1.59 | `█` 3.70 |
| Go | `▏` 1.31 | `█` 2.39 | `██` 5.43 |
| Java (Spring Boot) | `█` 2.35 | `█` 3.73 | `██` 8.10 |
| **Ballerina Nutcracker (bal run)** | `█` 1.93 | `█` 3.52 | `██` 8.37 |
| **Ballerina Nutcracker (bal build)** | `█` 1.95 | `█` 3.57 | `██` 8.46 |
| _Ballerina Swan Lake_ | `█` 2.72 | `█` 5.12 | `████` 12.33 |
| Node.js | `█` 3.69 | `██` 7.34 | `██████` 19.28 |
| Python (FastAPI) | `███` 9.14 | `█████` 18.52 | `███████████████` 51.84 |

**Takeaway:** latency rises in step with concurrency for all — expected when a server is saturated. Nutcracker climbs gently (~2 → ~8 ms) and tracks Spring Boot closely; Rust, .NET and Go stay the lowest.

## Tail latency — p99 in ms _(lower is better)_

| Runtime | 100 users | 200 users | 500 users |
|---|---|---|---|
| .NET (ASP.NET Core) | `█` 3.56 | `█` 4.61 | `█` 9.52 |
| Rust | `▏` 2.36 | `█` 5.01 | `██` 12.12 |
| Java (Spring Boot) | `██` 12.30 | `██` 14.53 | `███` 21.30 |
| Go | `█` 6.96 | `██` 10.91 | `███` 22.16 |
| Node.js | `█` 4.76 | `█` 9.47 | `████` 24.19 |
| _Ballerina Swan Lake_ | `█` 8.91 | `██` 14.92 | `█████` 32.12 |
| **Ballerina Nutcracker (bal run)** | `█` 8.92 | `██` 15.02 | `█████` 32.79 |
| **Ballerina Nutcracker (bal build)** | `█` 8.58 | `██` 14.94 | `█████` 33.19 |
| Python (FastAPI) | `████` 25.02 | `██████` 39.72 | `███████████████` 98.15 |

**Takeaway:** the 99th-percentile (slowest 1 in 100) tail. Nutcracker's tail sits mid-pack — close to Swan Lake and Spring Boot — well clear of Python, while the compiled stacks (.NET, Rust, Go) keep the tightest tails.

## Memory used — megabytes _(lower is better)_

| Runtime | 100 users | 200 users | 500 users |
|---|---|---|---|
| Rust | `▏` 6.7 | `▏` 10.8 | `▏` 19.8 |
| Go | `▏` 16.1 | `▏` 18.9 | `▏` 29.1 |
| **Ballerina Nutcracker (bal build)** | `▏` 26.2 | `▏` 29.5 | `█` 47.7 |
| **Ballerina Nutcracker (bal run)** | `█` 40.3 | `█` 44.9 | `█` 63.7 |
| Node.js | `█` 80.4 | `█` 84.0 | `█` 90.8 |
| .NET (ASP.NET Core) | `█` 71.3 | `█` 89.8 | `██` 116.0 |
| Python (FastAPI) | `███` 218.0 | `███` 223.7 | `████` 238.8 |
| Java (Spring Boot) | `████████` 539.2 | `████████` 540.4 | `██████████` 615.5 |
| _Ballerina Swan Lake_ | `██████████` 628.4 | `█████████████` 832.8 | `███████████████` 964.5 |

**Takeaway:** the sharpest contrast in the test. **Nutcracker stays lean under load** (40 → 64 MB with `bal run`, 26 → 48 MB as a `bal build` binary), alongside Rust and Go — while **Swan Lake climbs toward 1 GB** and Spring Boot reaches ~615 MB.

## Nutcracker, across the load range

| Users | Throughput | Avg latency | p99 | Memory | Errors |
|---|---:|---:|---:|---:|---:|
| 100 | 64,607 req/s | 1.93 ms | 8.92 ms | 40.3 MB | 0% |
| 200 | 66,241 req/s | 3.52 ms | 15.02 ms | 44.9 MB | 0% |
| 500 | 65,893 req/s | 8.37 ms | 32.79 ms | 63.7 MB | 0% |

**Nutcracker vs. Swan Lake (at 500 users):** ~**1.6×** the throughput · ~**108×** faster to start · ~**15×** less memory.

**`bal run` vs `bal build` (at 500 users):** throughput within ~1% (65,893 vs 65,164 req/s) · **~2× faster startup** (0.044 → 0.022 s) · **~25% less memory** (63.7 → 47.7 MB).

## What it means

- **Near-instant startup.** Ready in ~0.04 s with no JVM warm-up — around 108× faster than Swan Lake — and throughput then holds ~65k req/s from 100 to 500 users, with no errors.
- **Small footprint / lightweight.** Memory barely moves (40 → 64 MB), keeping company with Rust and Go, while the JVM-based runtimes (Spring Boot ~615 MB, Swan Lake ~965 MB) grow heavy under the same load.
- **Competitive performance.** Sustained ~65k req/s over HTTP with zero errors — comfortably ahead of Node.js and Python, and now edging past Java / Spring Boot. The compiled/native stacks (Rust, .NET, Go) push more raw throughput, but Nutcracker owns the startup-plus-footprint niche the project targets.
- **Ahead-of-time build.** `bal build` packages pre-compiled BIR with the same interpreter into one standalone binary (not native machine code). Same throughput as `bal run`, with a smaller footprint (down to ~26 MB) and ~2× faster startup (~0.02 s).

<details>
<summary>Show the full numbers (per user count)</summary>

**100 users**

| Runtime | Throughput | Avg (ms) | p99 (ms) | Std-dev (ms) | Memory (MB) | Errors |
|---|---:|---:|---:|---:|---:|---:|
| Rust | 152,074 | 0.63 | 2.36 | 0.48 | 6.7 | 0% |
| .NET (ASP.NET Core) | 108,954 | 0.89 | 3.56 | 0.71 | 71.3 | 0% |
| Go | 94,937 | 1.31 | 6.96 | 1.51 | 16.1 | 0% |
| Ballerina Nutcracker (bal run) | 64,607 | 1.93 | 8.92 | 2.04 | 40.3 | 0% |
| Ballerina Nutcracker (bal build) | 62,445 | 1.95 | 8.58 | 2.00 | 26.2 | 0% |
| Java (Spring Boot) | 61,037 | 2.35 | 12.30 | 2.73 | 539.2 | 0% |
| Ballerina Swan Lake | 37,748 | 2.72 | 8.91 | 1.75 | 628.4 | 0% |
| Node.js | 27,119 | 3.69 | 4.76 | 0.72 | 80.4 | 0% |
| Python (FastAPI) | 11,134 | 9.14 | 25.02 | 3.62 | 218.0 | 0% |

**200 users**

| Runtime | Throughput | Avg (ms) | p99 (ms) | Std-dev (ms) | Memory (MB) | Errors |
|---|---:|---:|---:|---:|---:|---:|
| Rust | 155,133 | 1.24 | 5.01 | 0.98 | 10.8 | 0% |
| .NET (ASP.NET Core) | 115,215 | 1.59 | 4.61 | 0.87 | 89.8 | 0% |
| Go | 95,622 | 2.39 | 10.91 | 2.46 | 18.9 | 0% |
| Ballerina Nutcracker (bal run) | 66,241 | 3.52 | 15.02 | 3.47 | 44.9 | 0% |
| Ballerina Nutcracker (bal build) | 64,987 | 3.57 | 14.94 | 3.47 | 29.5 | 0% |
| Java (Spring Boot) | 60,822 | 3.73 | 14.53 | 3.16 | 540.4 | 0% |
| Ballerina Swan Lake | 39,620 | 5.12 | 14.92 | 3.07 | 832.8 | 0% |
| Node.js | 27,299 | 7.34 | 9.47 | 2.26 | 84.0 | 0% |
| Python (FastAPI) | 10,841 | 18.52 | 39.72 | 5.54 | 223.7 | 0% |

**500 users**

| Runtime | Throughput | Avg (ms) | p99 (ms) | Std-dev (ms) | Memory (MB) | Errors |
|---|---:|---:|---:|---:|---:|---:|
| Rust | 154,527 | 3.14 | 12.12 | 2.52 | 19.8 | 0% |
| .NET (ASP.NET Core) | 119,776 | 3.70 | 9.52 | 1.66 | 116.0 | 0% |
| Go | 97,449 | 5.43 | 22.16 | 4.93 | 29.1 | 0% |
| Ballerina Nutcracker (bal run) | 65,893 | 8.37 | 32.79 | 7.48 | 63.7 | 0% |
| Ballerina Nutcracker (bal build) | 65,164 | 8.46 | 33.19 | 7.56 | 47.7 | 0% |
| Java (Spring Boot) | 61,546 | 8.10 | 21.30 | 4.32 | 615.5 | 0% |
| Ballerina Swan Lake | 40,585 | 12.33 | 32.12 | 6.53 | 964.5 | 0% |
| Node.js | 26,049 | 19.28 | 24.19 | 10.24 | 90.8 | 0% |
| Python (FastAPI) | 9,651 | 51.84 | 98.15 | 15.02 | 238.8 | 0% |

</details>

---

_Preliminary results from a single scenario (a lightweight “hello” HTTP service). Broader scenarios — larger payloads and proxy workloads — are still to come; figures are indicative, not final._

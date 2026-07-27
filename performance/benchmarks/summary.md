# Performance Summary — Nutcracker vs. the industry leaders

**Version** · `v0.6.0` · run 2026-07-26

> **Draft — preliminary.** How **Ballerina Nutcracker** compares to the industry's leading web runtimes as traffic climbs from **100 → 200 → 500 concurrent users**. Short version: **near-instant startup, a small footprint, and competitive performance — a native, no-JVM alternative to the JVM-based Swan Lake distribution.**

> **Experimental project. Ballerina Swan Lake remains the production distribution.**

**Test at a glance:** a lightweight “hello” HTTP service · **100, 200 & 500** concurrent users · **30-minute** measured runs (10-minute warm-up) · AWS EC2 m6a.xlarge (4 vCPU, 16 GiB, Amazon Linux 2023) · load via wrk. **Every runtime completed all requests with 0 errors.**

**Runtimes & versions:** Ballerina Nutcracker v0.6.0 · Ballerina Swan Lake 2201.13.4 · Rust 1.97.1 · .NET 9.0.118 · Go 1.26.5 · Java 21 / Spring Boot 3.5.4 · Node.js 18.20.8 · Python 3.9.25 (FastAPI).

**How Nutcracker is run.** Nutcracker is built ahead of time with **`bal build`**, which compiles your code to BIR and packages that BIR alongside the Go interpreter into one standalone binary — it is *not* native machine code; at launch it simply unpacks the BIR and feeds it to the interpreter, skipping the compiler front-end. That is the deployment recommended for production.

## How to read these charts

The load charts give each runtime **three bars — 100, 200, 500 users** (left → right): read a row to see how it **scales with load**, read a column to compare **runtimes at the same load**. Startup is a one-time value (single bar). Every chart is **ranked best-first**. The **Nutcracker** row is in bold; _Swan Lake_ is in italics.

## Time to start serving — seconds _(lower is better; measured once at launch)_

| Runtime | | sec |
|---|---|---:|
| Rust | `▏` | 0.013 |
| Go | `▏` | 0.016 |
| **Ballerina Nutcracker** | `▏` | 0.023 |
| Node.js | `▏` | 0.041 |
| .NET (ASP.NET Core) | `██` | 0.232 |
| Python (FastAPI) | `████` | 0.606 |
| _Ballerina Swan Lake_ | `██████` | 0.956 |
| Java (Spring Boot) | `███████████████` | 2.221 |

**Takeaway:** Nutcracker is ready in ~0.02 s — in the instant-start group with Rust, Go and Node — while the JVM-based Swan Lake, even as a prebuilt `bal build` jar, needs ~1 s, roughly **42× longer**.

## Traffic handled — requests/sec _(higher is better)_

| Runtime | 100 users | 200 users | 500 users |
|---|---|---|---|
| Rust | `███████████████` 151,764 | `███████████████` 155,046 | `███████████████` 153,995 |
| .NET (ASP.NET Core) | `███████████` 109,306 | `███████████` 114,337 | `████████████` 119,332 |
| Go | `█████████` 95,474 | `█████████` 96,306 | `██████████` 98,852 |
| **Ballerina Nutcracker** | `███████` 69,666 | `███████` 72,093 | `███████` 71,222 |
| Java (Spring Boot) | `██████` 59,848 | `██████` 59,390 | `██████` 61,995 |
| _Ballerina Swan Lake_ | `████` 38,669 | `████` 42,364 | `████` 41,728 |
| Node.js | `███` 26,849 | `███` 27,348 | `███` 26,079 |
| Python (FastAPI) | `█` 11,019 | `█` 10,820 | `█` 9,584 |

**Takeaway:** on 4 cores every runtime is at its ceiling by 100 users, so throughput stays essentially **flat** as load grows 5×. The compiled/tuned stacks (Rust, .NET, Go) lead; Nutcracker holds a steady ~71k req/s — ahead of Node.js and Python, and a step above Java / Spring Boot.

## Response time — average latency in ms _(lower is better)_

| Runtime | 100 users | 200 users | 500 users |
|---|---|---|---|
| Rust | `▏` 0.63 | `▏` 1.24 | `█` 3.16 |
| .NET (ASP.NET Core) | `▏` 0.88 | `▏` 1.60 | `█` 3.72 |
| Go | `▏` 1.30 | `█` 2.36 | `██` 5.33 |
| **Ballerina Nutcracker** | `█` 1.75 | `█` 3.18 | `██` 7.53 |
| Java (Spring Boot) | `█` 2.38 | `█` 3.77 | `██` 8.04 |
| _Ballerina Swan Lake_ | `█` 2.65 | `█` 4.77 | `███` 11.99 |
| Node.js | `█` 3.72 | `██` 7.32 | `██████` 19.26 |
| Python (FastAPI) | `███` 9.22 | `█████` 18.54 | `███████████████` 52.18 |

**Takeaway:** latency rises in step with concurrency for all — expected when a server is saturated. Nutcracker climbs gently (~1.8 → ~7.5 ms) and now edges just ahead of Spring Boot; Rust, .NET and Go stay the lowest.

## Tail latency — p99 in ms _(lower is better)_

| Runtime | 100 users | 200 users | 500 users |
|---|---|---|---|
| .NET (ASP.NET Core) | `█` 3.47 | `█` 4.65 | `██` 9.56 |
| Rust | `▏` 2.34 | `█` 4.99 | `██` 12.01 |
| Java (Spring Boot) | `██` 12.32 | `██` 14.25 | `███` 21.28 |
| Go | `█` 6.80 | `██` 10.68 | `███` 21.67 |
| Node.js | `█` 4.76 | `██` 9.59 | `████` 24.58 |
| **Ballerina Nutcracker** | `█` 8.01 | `██` 13.43 | `█████` 28.25 |
| _Ballerina Swan Lake_ | `█` 8.67 | `██` 13.99 | `█████` 31.46 |
| Python (FastAPI) | `████` 24.85 | `██████` 38.74 | `███████████████` 93.80 |

**Takeaway:** the 99th-percentile (slowest 1 in 100) tail. Nutcracker's tail sits mid-pack — now just inside Swan Lake's and a touch above Spring Boot's — well clear of Python, while the compiled stacks (.NET, Rust, Go) keep the tightest tails.

## Memory used — megabytes _(lower is better)_

| Runtime | 100 users | 200 users | 500 users |
|---|---|---|---|
| Rust | `▏` 7.0 | `▏` 10.9 | `▏` 17.7 |
| Go | `▏` 16.0 | `▏` 18.8 | `▏` 28.2 |
| **Ballerina Nutcracker** | `▏` 24.2 | `▏` 29.1 | `█` 45.9 |
| Node.js | `█` 80.1 | `█` 84.7 | `█` 88.8 |
| .NET (ASP.NET Core) | `█` 72.9 | `██` 92.8 | `██` 118.3 |
| Python (FastAPI) | `████` 218.0 | `████` 223.3 | `████` 237.2 |
| Java (Spring Boot) | `███████` 439.9 | `████████` 489.3 | `████████` 475.1 |
| _Ballerina Swan Lake_ | `███████████` 635.2 | `████████████` 723.1 | `███████████████` 900.9 |

**Takeaway:** the sharpest contrast in the test. **Nutcracker stays lean under load** (24 → 46 MB), alongside Rust and Go — while **Swan Lake climbs toward 900 MB** and Spring Boot reaches ~490 MB.

## Nutcracker, across the load range

| Users | Throughput | Avg latency | p99 | Memory | Max CPU | Errors |
|---|---:|---:|---:|---:|---:|---:|
| 100 | 69,666 req/s | 1.75 ms | 8.01 ms | 24.2 MB | 427% | 0% |
| 200 | 72,093 req/s | 3.18 ms | 13.43 ms | 29.1 MB | 331% | 0% |
| 500 | 71,222 req/s | 7.53 ms | 28.25 ms | 45.9 MB | 403% | 0% |

_Max CPU is the peak aggregate across all cores; **400% = the box's 4 vCPUs fully used**. Nutcracker's peak sits around 400% under load — it spreads work across all four cores (the figure is a sampled peak, so it varies run to run)._

**Nutcracker vs. Swan Lake (at 500 users):** ~**1.7×** the throughput · ~**42×** faster to start · ~**20×** less memory.

## What it means

- **Near-instant startup.** Ready in ~0.02 s with no JVM warm-up — around 42× faster than Swan Lake even when Swan Lake runs as a prebuilt jar — and throughput then holds ~71k req/s from 100 to 500 users, with no errors.
- **Small footprint / lightweight.** Memory barely moves (24 → 46 MB), keeping company with Rust and Go, while the JVM-based runtimes (Spring Boot ~490 MB, Swan Lake ~900 MB) grow heavy under the same load.
- **Competitive performance.** Sustained ~71k req/s over HTTP with zero errors — comfortably ahead of Node.js and Python, and now edging past Java / Spring Boot. The compiled/native stacks (Rust, .NET, Go) push more raw throughput, but Nutcracker owns the startup-plus-footprint niche the project targets.
- **Standalone binary.** `bal build` packages your pre-compiled BIR with the interpreter into one self-contained binary (not native machine code) — ~0.02 s startup and a ~24 MB footprint.

<details>
<summary>Show the full numbers (per user count)</summary>

_**Max CPU (%)** is the peak aggregate across cores — **400% = all 4 vCPUs**. Values above 400% are sampling peaks from runtimes that spread work across many OS threads/processes (FastAPI runs one worker per core; the JVM's GC/JIT threads spike the sampler). None of the runtimes is pinned._

**100 users**

| Runtime | Throughput | Avg (ms) | p99 (ms) | Std-dev (ms) | Memory (MB) | Max CPU (%) | Errors |
|---|---:|---:|---:|---:|---:|---:|---:|
| Rust | 151,764 | 0.63 | 2.34 | 0.47 | 7.0 | 329 | 0% |
| .NET (ASP.NET Core) | 109,306 | 0.88 | 3.47 | 0.70 | 72.9 | 471 | 0% |
| Go | 95,474 | 1.30 | 6.80 | 1.47 | 16.0 | 244 | 0% |
| Ballerina Nutcracker | 69,666 | 1.75 | 8.01 | 1.83 | 24.2 | 427 | 0% |
| Java (Spring Boot) | 59,848 | 2.38 | 12.32 | 2.74 | 439.9 | 360 | 0% |
| Ballerina Swan Lake | 38,669 | 2.65 | 8.67 | 1.70 | 635.2 | 347 | 0% |
| Node.js | 26,849 | 3.72 | 4.76 | 0.73 | 80.1 | 165 | 0% |
| Python (FastAPI) | 11,019 | 9.22 | 24.85 | 3.26 | 218.0 | 604 | 0% |

**200 users**

| Runtime | Throughput | Avg (ms) | p99 (ms) | Std-dev (ms) | Memory (MB) | Max CPU (%) | Errors |
|---|---:|---:|---:|---:|---:|---:|---:|
| Rust | 155,046 | 1.24 | 4.99 | 0.97 | 10.9 | 249 | 0% |
| .NET (ASP.NET Core) | 114,337 | 1.60 | 4.65 | 0.88 | 92.8 | 296 | 0% |
| Go | 96,306 | 2.36 | 10.68 | 2.41 | 18.8 | 401 | 0% |
| Ballerina Nutcracker | 72,093 | 3.18 | 13.43 | 3.10 | 29.1 | 331 | 0% |
| Java (Spring Boot) | 59,390 | 3.77 | 14.25 | 3.08 | 489.3 | 389 | 0% |
| Ballerina Swan Lake | 42,364 | 4.77 | 13.99 | 2.87 | 723.1 | 464 | 0% |
| Node.js | 27,348 | 7.32 | 9.59 | 2.05 | 84.7 | 122 | 0% |
| Python (FastAPI) | 10,820 | 18.54 | 38.74 | 5.36 | 223.3 | 621 | 0% |

**500 users**

| Runtime | Throughput | Avg (ms) | p99 (ms) | Std-dev (ms) | Memory (MB) | Max CPU (%) | Errors |
|---|---:|---:|---:|---:|---:|---:|---:|
| Rust | 153,995 | 3.16 | 12.01 | 2.52 | 17.7 | 342 | 0% |
| .NET (ASP.NET Core) | 119,332 | 3.72 | 9.56 | 1.66 | 118.3 | 377 | 0% |
| Go | 98,852 | 5.33 | 21.67 | 4.83 | 28.2 | 241 | 0% |
| Ballerina Nutcracker | 71,222 | 7.53 | 28.25 | 6.47 | 45.9 | 403 | 0% |
| Java (Spring Boot) | 61,995 | 8.04 | 21.28 | 4.35 | 475.1 | 429 | 0% |
| Ballerina Swan Lake | 41,728 | 11.99 | 31.46 | 6.40 | 900.9 | 348 | 0% |
| Node.js | 26,079 | 19.26 | 24.58 | 10.12 | 88.8 | 161 | 0% |
| Python (FastAPI) | 9,584 | 52.18 | 93.80 | 13.13 | 237.2 | 514 | 0% |

</details>

---

_Preliminary results from a single scenario (a lightweight “hello” HTTP service). Broader scenarios — larger payloads and proxy workloads — are still to come; figures are indicative, not final._

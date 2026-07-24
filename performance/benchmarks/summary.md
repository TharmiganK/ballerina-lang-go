# Performance Summary — Nutcracker vs. the industry leaders

**Version** · `v0.6.0-3bbfc89-20260723`
_Format: `<nutcracker-version>-<build-commit, omitted when run against a stable release>-<test-date YYYYMMDD>`_

> **Draft — preliminary.** How **Ballerina Nutcracker** compares to the industry's leading web runtimes as traffic climbs from **100 → 200 → 500 concurrent users**. Short version: **near-instant startup, a small footprint, and competitive performance — a native, no-JVM alternative to the JVM-based Swan Lake distribution.**

> **Experimental project. Ballerina Swan Lake remains the production distribution.**

**Test at a glance:** a lightweight “hello” HTTP service · **100, 200 & 500** concurrent users · **30-minute** measured runs (10-minute warm-up) · AWS EC2 m6a.xlarge (4 vCPU, 16 GiB, Amazon Linux 2023) · load via wrk. **Every runtime completed all requests with 0 errors.**

**Runtimes & versions:** Ballerina Nutcracker v0.6.0 · Ballerina Swan Lake 2201.13.4 · Rust 1.97.1 · .NET 9.0.118 · Go 1.26.5 · Java 21 / Spring Boot 3.5.4 · Node.js 18.20.8 · Python 3.9.25 (FastAPI).

## How to read these charts

The load charts give each runtime **three bars — 100, 200, 500 users** (left → right): read a row to see how it **scales with load**, read a column to compare **runtimes at the same load**. Startup is a one-time value (single bar). Every chart is **ranked best-first**. **▶ Nutcracker** is highlighted; _Swan Lake_ is in italics.

## Time to start serving — seconds _(lower is better; measured once at launch)_

| Runtime | | sec |
|---|---|---:|
| Rust | `▏` | 0.11 |
| Go | `▏` | 0.11 |
| Node.js | `▏` | 0.11 |
| **▶ Ballerina Nutcracker** | `▏` | **0.11** |
| .NET (ASP.NET Core) | `█` | 0.35 |
| Python (FastAPI) | `██` | 0.60 |
| Java (Spring Boot) | `███████` | 2.09 |
| _Ballerina Swan Lake_ | `███████████████` | 4.32 |

**Takeaway:** Nutcracker is ready in ~0.1 s — in the instant-start group with Rust, Go and Node — while the JVM-based Swan Lake needs ~4.3 s, roughly **40× longer**.

## Traffic handled — requests/sec _(higher is better)_

| Runtime | 100 users | 200 users | 500 users |
|---|---|---|---|
| Rust | `███████████████` 150,481 | `███████████████` 154,715 | `███████████████` 154,409 |
| .NET (ASP.NET Core) | `███████████` 108,949 | `███████████` 115,783 | `████████████` 119,732 |
| Go | `█████████` 94,626 | `█████████` 95,312 | `█████████` 97,765 |
| Java (Spring Boot) | `██████` 59,345 | `██████` 59,449 | `██████` 60,014 |
| **▶ Ballerina Nutcracker** | `█████` **51,042** | `█████` **52,617** | `█████` **50,159** |
| _Ballerina Swan Lake_ | `████` 37,189 | `████` 39,158 | `████` 38,360 |
| Node.js | `███` 27,221 | `███` 27,277 | `██` 25,706 |
| Python (FastAPI) | `█` 10,276 | `█` 10,149 | `█` 9,507 |

**Takeaway:** on 4 cores every runtime is at its ceiling by 100 users, so throughput stays essentially **flat** as load grows 5×. The compiled/tuned stacks (Rust, .NET, Go) lead; Nutcracker holds a steady ~50k req/s — ahead of Node.js and Python, and a touch above Swan Lake.

## Response time — average latency in ms _(lower is better)_

| Runtime | 100 users | 200 users | 500 users |
|---|---|---|---|
| Rust | `▏` 0.64 | `▏` 1.24 | `█` 3.14 |
| .NET (ASP.NET Core) | `▏` 0.89 | `▏` 1.58 | `█` 3.71 |
| Go | `▏` 1.32 | `█` 2.41 | `██` 5.41 |
| Java (Spring Boot) | `█` 2.38 | `█` 3.78 | `██` 8.29 |
| **▶ Ballerina Nutcracker** | `█` **2.32** | `█` **4.42** | `███` **11.49** |
| _Ballerina Swan Lake_ | `█` 2.77 | `█` 5.17 | `████` 13.03 |
| Node.js | `█` 3.67 | `██` 7.34 | `██████` 19.53 |
| Python (FastAPI) | `███` 9.99 | `██████` 19.88 | `███████████████` 52.61 |

**Takeaway:** latency rises in step with concurrency for all — expected when a server is saturated. Nutcracker climbs gently (2 → 11 ms) and tracks the mainstream runtimes; Rust, .NET and Go stay the lowest.

## Memory used — megabytes _(lower is better)_

| Runtime | 100 users | 200 users | 500 users |
|---|---|---|---|
| Rust | `▏` 6.7 | `▏` 10.4 | `▏` 19.2 |
| Go | `▏` 15.7 | `▏` 18.8 | `▏` 28.2 |
| **▶ Ballerina Nutcracker** | `█` **43.6** | `█` **48.6** | `█` **66.6** |
| Node.js | `█` 82.1 | `█` 85.8 | `█` 92.7 |
| .NET (ASP.NET Core) | `█` 72.3 | `█` 92.3 | `██` 119.4 |
| Python (FastAPI) | `███` 221.3 | `███` 227.4 | `███` 242.3 |
| Java (Spring Boot) | `███████` 452.8 | `███████` 505.6 | `████████` 572.8 |
| _Ballerina Swan Lake_ | `████████████` 804.1 | `███████████` 796.7 | `███████████████` 1,042.6 |

**Takeaway:** the sharpest contrast in the test. **Nutcracker stays lean under load** (44 → 67 MB), alongside Rust and Go — while **Swan Lake climbs past 1 GB** and Spring Boot reaches ~573 MB.

## Nutcracker, across the load range

| Users | Throughput | Avg latency | Memory | Errors |
|---|---:|---:|---:|---:|
| 100 | 51,042 req/s | 2.32 ms | 43.6 MB | 0% |
| 200 | 52,617 req/s | 4.42 ms | 48.6 MB | 0% |
| 500 | 50,159 req/s | 11.49 ms | 66.6 MB | 0% |

**Nutcracker vs. Swan Lake (at 500 users):** ~**1.3×** the throughput · ~**40×** faster to start · ~**16×** less memory.

## What it means

- **Near-instant startup.** Ready in ~0.1 s with no JVM warm-up — about 40× faster than Swan Lake — and throughput then holds ~50k req/s from 100 to 500 users, with no errors.
- **Small footprint / lightweight.** Memory barely moves (44 → 67 MB), keeping company with Rust and Go, while the JVM-based runtimes (Spring Boot ~573 MB, Swan Lake > 1 GB) grow heavy under the same load.
- **Competitive performance.** Sustained ~50k req/s over HTTP with zero errors — comfortably ahead of Node.js and Python. The compiled/tuned stacks (Rust, .NET, Go) push more raw throughput, but Nutcracker wins the startup-plus-footprint niche the project targets.

<details>
<summary>Show the full numbers (per user count)</summary>

**100 users**

| Runtime | Throughput | Avg (ms) | p99 (ms) | Memory (MB) | Errors |
|---|---:|---:|---:|---:|---:|
| Rust | 150,481 | 0.64 | 2.38 | 6.7 | 0% |
| .NET (ASP.NET Core) | 108,949 | 0.89 | 3.50 | 72.3 | 0% |
| Go | 94,626 | 1.32 | 7.03 | 15.7 | 0% |
| Java (Spring Boot) | 59,345 | 2.38 | 12.21 | 452.8 | 0% |
| Ballerina Nutcracker | 51,042 | 2.32 | 9.97 | 43.6 | 0% |
| Ballerina Swan Lake | 37,189 | 2.77 | 9.24 | 804.1 | 0% |
| Node.js | 27,221 | 3.67 | 4.76 | 82.1 | 0% |
| Python (FastAPI) | 10,276 | 9.99 | 29.99 | 221.3 | 0% |

**200 users**

| Runtime | Throughput | Avg (ms) | p99 (ms) | Memory (MB) | Errors |
|---|---:|---:|---:|---:|---:|
| Rust | 154,715 | 1.24 | 4.90 | 10.4 | 0% |
| .NET (ASP.NET Core) | 115,783 | 1.58 | 4.61 | 92.3 | 0% |
| Go | 95,312 | 2.41 | 10.98 | 18.8 | 0% |
| Java (Spring Boot) | 59,449 | 3.78 | 14.25 | 505.6 | 0% |
| Ballerina Nutcracker | 52,617 | 4.42 | 19.27 | 48.6 | 0% |
| Ballerina Swan Lake | 39,158 | 5.17 | 15.21 | 796.7 | 0% |
| Node.js | 27,277 | 7.34 | 9.56 | 85.8 | 0% |
| Python (FastAPI) | 10,149 | 19.88 | 46.86 | 227.4 | 0% |

**500 users**

| Runtime | Throughput | Avg (ms) | p99 (ms) | Memory (MB) | Errors |
|---|---:|---:|---:|---:|---:|
| Rust | 154,409 | 3.14 | 12.03 | 19.2 | 0% |
| .NET (ASP.NET Core) | 119,732 | 3.71 | 9.62 | 119.4 | 0% |
| Go | 97,765 | 5.41 | 22.04 | 28.2 | 0% |
| Java (Spring Boot) | 60,014 | 8.29 | 21.29 | 572.8 | 0% |
| Ballerina Nutcracker | 50,159 | 11.49 | 47.49 | 66.6 | 0% |
| Ballerina Swan Lake | 38,360 | 13.03 | 34.09 | 1,042.6 | 0% |
| Node.js | 25,706 | 19.53 | 24.43 | 92.7 | 0% |
| Python (FastAPI) | 9,507 | 52.61 | 96.40 | 242.3 | 0% |

</details>

---

_Preliminary results from a single scenario (a lightweight “hello” HTTP service). Broader scenarios — larger payloads and proxy workloads — are still to come; figures are indicative, not final._

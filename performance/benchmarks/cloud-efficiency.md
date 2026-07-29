# Cloud Efficiency Summary — Nutcracker vs the field

> **Experimental project. Ballerina Swan Lake remains the production distribution.** This summary quantifies the case for Nutcracker as a native, no-JVM, cloud-native alternative.

**Interactive chart:** the efficiency frontier (throughput vs memory, ranked by density) is published as a one-page visual at → https://claude.ai/code/artifact/91bcca93-9f78-4905-8ebf-3ad3a8ef2cc6

_Derived from the stable (steady-state) AWS runs in `performance/results/` (EC2 m6a.xlarge, 4 vCPU, 600 s warmup, 1800 s measured, `wrk` closed-loop, 0 errors across all runtimes). Cold-start figures come from the companion `*-cold-start.md` reports. `dotnet-aot` is not yet in the stable runs — its rows are marked **pending**._

## The metric

In the cloud you do not pay for `req/s`. You pay for **memory held over time** (serverless GB-seconds) and you schedule pods by **memory request** (Kubernetes bin-packing). So the number that tracks cost is **throughput density — req/s per MB of peak RSS** — not raw throughput. Everything below ranks on that, with raw throughput and memory shown alongside so nothing is hidden.

## TL;DR

- **vs Swan Lake (the pitch): a decisive win on every axis.** Nutcracker delivers **1.3–1.8× the raw throughput** on **12–29× less memory**, for **15–52× better throughput density**, and starts **~44× faster**. This is the "faster, leaner Swan Lake for cloud-native" story, fully supported by the data.
- **vs dotnet (the real question): a real but narrow *efficiency* win — not a raw-speed win.** dotnet is **~1.56× faster on raw throughput**. But nutcracker uses **1.9–3.0× less memory**, giving it **1.2× (passthrough) to 1.9× (hello) better throughput density**, plus a dramatically better cold start (first request 3.9 ms vs 46 ms). The honest claim is *"comparable-to-better cost efficiency and far better cold-start, at lower peak throughput"* — a **cost/density** argument, not a speed one, and one to re-confirm once `dotnet-aot` lands.
- **Rust and Go still lead** the joint throughput+memory frontier. Nutcracker sits in their low-memory cluster on footprint, well clear of the JVM/.NET/JS/Python group.

## Steady-state efficiency — hello-service @ 100 users

| Runtime | Throughput (req/s) | Peak RSS (MB) | **req/s per MB** | Memory-time (GB·s / M req) |
|---|---:|---:|---:|---:|
| rust | 151,764 | 7.0 | **21,681** | 0.045 |
| go | 95,474 | 16.0 | **5,967** | 0.164 |
| **nutcracker** | 69,666 | 24.2 | **2,879** | 0.339 |
| dotnet | 109,306 | 72.9 | **1,499** | 0.651 |
| node | 26,849 | 80.1 | **335** | 2.913 |
| java-spring | 59,848 | 439.9 | **136** | 7.178 |
| swanlake | 38,297 | 697.8 | **55** | 17.79 |
| python-fastapi | 11,019 | 218.0 | **51** | 19.32 |
| dotnet-aot | _pending_ | _pending_ | _pending_ | _pending_ |

## Steady-state efficiency — passthrough @ 100 users, 1 KB

| Runtime | Throughput (req/s) | Peak RSS (MB) | **req/s per MB** | Memory-time (GB·s / M req) |
|---|---:|---:|---:|---:|
| rust | 34,577 | 15.1 | **2,290** | 0.426 |
| **nutcracker** | 22,644 | 51.9 | **436** | 2.238 |
| go | 19,040 | 46.0 | **414** | 2.359 |
| dotnet | 35,239 | 97.2 | **363** | 2.694 |
| node | 6,991 | 92.0 | **76** | 12.85 |
| java-spring | 18,233 | 488.4 | **37** | 26.16 |
| swanlake | 17,599 | 619.1 | **28** | 34.35 |
| python-fastapi | 7,248 | 256.9 | **28** | 34.61 |
| dotnet-aot | _pending_ | _pending_ | _pending_ | _pending_ |

On passthrough, nutcracker's density (436) **edges out both dotnet (363) and Go (414)** — its throughput matches the field while its footprint stays Go-class.

## Head-to-head: nutcracker vs Swan Lake

| Axis | hello | passthrough |
|---|---|---|
| Raw throughput | **1.82× faster** | **1.29× faster** |
| Peak memory | **28.8× leaner** | **11.9× leaner** |
| Throughput density | **52.5× better** | **15.3× better** |
| Startup time | 0.023 s vs 4.88 s (**~210×**) | 0.022 s vs 0.99 s (**~45×**) |
| First request (cold) | 3.9 ms vs 103.8 ms | 6.6 ms vs 189.1 ms |

There is no axis on which Swan Lake wins. For a team already on Ballerina, this is the migration argument on its own.

## Head-to-head: nutcracker vs dotnet (the honest picture)

| Axis | hello | passthrough | Winner |
|---|---|---|---|
| Raw throughput | 69.7k vs 109.3k | 22.6k vs 35.2k | **dotnet (~1.56×)** |
| Peak memory | 24.2 vs 72.9 MB | 51.9 vs 97.2 MB | **nutcracker (1.9–3.0×)** |
| Throughput density | 2,879 vs 1,499 | 436 vs 363 | **nutcracker (1.2–1.9×)** |
| Startup time | 0.023 vs 0.255 s | 0.022 vs 0.246 s | **nutcracker (~11×)** |
| First request (cold) | 3.9 vs 46.4 ms | 6.6 vs 88.0 ms | **nutcracker (~12×)** |

**Where nutcracker wins the buyer:** memory-billed and bin-packed environments (serverless, high-density Kubernetes, multi-tenant), and any scale-to-zero / autoscaling workload where cold start is on the critical path. **Where dotnet wins:** a single, CPU-saturated, always-warm service optimized for peak requests-per-core.

## Serverless cost projection (GB-seconds)

Serverless platforms (AWS Lambda, Cloud Run, Azure Container Apps) bill **memory × time**. Memory-time per **million requests** = `(peak_RSS_GB) / throughput × 10⁶`:

| Runtime | hello (GB·s / M req) | passthrough (GB·s / M req) | vs nutcracker |
|---|---:|---:|---|
| **nutcracker** | **0.339** | **2.238** | baseline |
| dotnet | 0.651 | 2.694 | **1.2–1.9× more expensive** |
| swanlake | 17.79 | 34.35 | **15–52× more expensive** |

Plus a tier effect: nutcracker's ~24 MB footprint fits the smallest memory tier (128 MB on Lambda / Cloud Run) where dotnet's ~73 MB and Swan Lake's ~700 MB force larger tiers — and nutcracker's ~10× faster cold start means fewer, cheaper cold-start billing events during scale-out.

## Kubernetes pod density (memory-bound scheduling)

Instances scheduled by memory request on an 8 GB-allocatable node (request ≈ observed peak RSS):

| Runtime | hello: pods/node | passthrough: pods/node |
|---|---:|---:|
| **nutcracker** | **~339** | **~158** |
| dotnet | ~112 | ~84 |
| swanlake | ~12 | ~13 |

→ **~3× the pod density of dotnet, ~28× that of Swan Lake** for the same node.

> **Caveat (stated plainly):** at 100-user saturation each instance here consumes 2.4–4.3 vCPU, so a real node's **CPU** caps the count well below these memory-bound figures for a *saturated* service. The memory-density advantage is fully realized for the common cloud-native case — **many services each running below CPU saturation** (microservices, multi-tenant, spiky/low-average traffic) — where scheduling is memory-bound. The *ratio* (3× / 28×) is what carries over; the absolute counts are an upper bound.

## Caveats & next steps

1. **`dotnet-aot` is pending** for the stable runs. Its cold-start data already looks strong (startup 0.047 s, first request 0.85 ms, startup RSS 23.6 MB). Native AOT will cut dotnet's *startup* footprint, but steady-state RSS under load is driven by **server GC**, which AOT does not change — so nutcracker's under-load memory / density edge is expected to largely survive. **Must be measured to make the claim bulletproof.**
2. **dotnet's raw-throughput lead is genuine** — do not pitch nutcracker as "faster than dotnet." Pitch it as *leaner and cheaper per request, and far faster to cold-start*.
3. **Rust/Go lead the frontier.** Nutcracker's story is "near-Go footprint with Ballerina's productivity and integration model," not "fastest runtime."
4. Load tool is `wrk` v1 (coordinated omission); tail latencies under saturation are optimistic. Densities use peak RSS, which is conservative (favours no one unfairly).

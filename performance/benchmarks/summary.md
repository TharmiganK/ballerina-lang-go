# Benchmark Summary

Curated cross-runtime comparison for the Ballerina Nutcracker HTTP performance suite. Regenerate the underlying data with `performance/run.sh` (raw reports land in `performance/results/`), then distil the representative run here.

> **Illustrative sample only.** The tables below come from a short smoke run on a developer machine (macOS, 12 cores) with 2s warmup / 3s measured — enough to show shape and format, **not** official numbers. Publish real figures from a full run on the dedicated benchmark VM (longer warmup/duration, the full user × payload grid). Lower is better for latency/memory/CPU/startup; higher is better for throughput.

## Scenario: hello-service (50 concurrent users)

| Metric | nutcracker | swanlake | go | node | node-express | python | python-flask | java-netty |
|---|---|---|---|---|---|---|---|---|
| Startup (s) | 0.34 | 6.34 | 0.81 | 0.35 | 0.13 | 0.13 | 0.13 | 0.24 |
| Throughput (req/s) | 77510 | 73097 | 80504 | 98650 | 26570 | 26352 | 5943 | 94352 |
| Avg Latency (ms) | 0.62 | 5.73 | 0.60 | 0.49 | 1.86 | 1.85 | 12.26 | 0.50 |
| p99 Latency (ms) | 1.58 | 90.23 | 1.09 | 1.06 | 2.87 | 6.92 | 83.14 | 0.59 |
| Latency Std-Dev (ms) | 0.28 | 15.75 | 0.36 | 0.23 | 1.25 | 1.49 | 16.10 | 0.04 |
| Max Memory (MB) | 42.5 | 669.1 | 22.2 | 61.2 | 109.7 | 22.6 | 35.1 | 451.1 |
| Max CPU (%) | 532.7 | 1028.5 | 438.1 | 105.5 | 109.0 | 148.4 | 117.1 | 511.1 |
| Error Rate (%) | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |

## Scenario: passthrough (50 concurrent users, 1KB payload)

| Metric | nutcracker | swanlake | go | node | node-express | python | python-flask | java-netty |
|---|---|---|---|---|---|---|---|---|
| Startup (s) | 0.34 | 7.81 | 0.70 | 0.35 | 0.12 | 0.13 | 0.24 | 0.24 |
| Throughput (req/s) | 39814 | 41512 | 28280 | 31166 | 15675 | 8323 | 1892 | 56102 |
| Avg Latency (ms) | 1.20 | 21.73 | 1.70 | 1.55 | 3.11 | 5.39 | 27.50 | 0.82 |
| p99 Latency (ms) | 2.50 | 177.60 | 2.71 | 2.23 | 7.07 | 13.70 | 127.21 | 1.61 |
| Latency Std-Dev (ms) | 0.34 | 41.09 | 0.42 | 0.50 | 1.20 | 2.81 | 22.01 | 0.28 |
| Max Memory (MB) | 55.3 | 640.2 | 30.4 | 82.3 | 112.5 | 23.6 | 42.0 | 483.5 |
| Max CPU (%) | 550.1 | 991.7 | 467.6 | 110.2 | 110.0 | 151.0 | 118.4 | 782.9 |
| Error Rate (%) | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |

## Reading the sample

- **Nutcracker vs Swan Lake** — comparable throughput on both scenarios, but Nutcracker starts ~20× faster (0.34s vs 6–8s) and uses ~12–15× less memory (42–55MB vs 640–669MB), with far tighter tail latency. This is the headline the suite exists to track.
- **Nutcracker vs native runtimes** — competitive with Go and within range of Node/Java-Netty on throughput, at low memory and startup.
- Python/Flask are the expected slow, low-throughput baselines.

Re-run to refresh; keep only the representative full-VM run committed here.

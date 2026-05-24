# Ballerina Standard Library — Go Native Support

This directory contains the Go-native implementations of Ballerina standard library packages. Each package is compiled into embedded `.sym`/`.bir` artefacts by `tools/gen-embedded-libs`.

Packages are organised into **dependency levels** that control compilation order (packages within a level compile in parallel; each level waits for the previous to finish):

- **L1** — no cross-stdlib imports
- **L2** — may import L1 packages

## Packages

Support % is computed as `Supported / Total`, where *Total* is the number of rows in each package's support table (Supported + Partially Supported + Not Yet Supported + Cannot Support).

| Package | Level | Supported | Partially Supported | Not Yet Supported | Support % |
|---|---|---|---|---|---|
| [http](http/bal/README.md) | L1 | 14 | 1 | 53 | 21% |
| [io](io/bal/README.md) | L1 | 13 | 1 | 12 | 50% |
| [log](log/bal/README.md) | L1 | 7 | 1 | 16 | 29% |
| [math.vector](math.vector/bal/README.md) | L1 | 5 | 0 | 0 | 100% |
| [random](random/bal/README.md) | L1 | 3 | 1 | 1 | 60% |
| [time](time/bal/README.md) | L1 | 27 | 0 | 5 | 84% |
| [url](url/bal/README.md) | L1 | 2 | 1 | 1 | 50% |
| [crypto](crypto/bal/README.md) | L2 | 26 | 0 | 5 | 84% |
| [os](os/bal/README.md) | L2 | 10 | 1 | 1 | 83% |
| **Total** | | **107** | **6** | **94** | **52%** |

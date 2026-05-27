# Ballerina Standard Library — Go Native Support

This directory contains the Go-native implementations of Ballerina standard library packages. Each package is compiled into embedded `.sym`/`.bir` artefacts by `tools/gen-embedded-libs`.

Packages are organised into **dependency levels** that control compilation order (packages within a level compile in parallel; each level waits for the previous to finish):

- **L1** — no cross-stdlib imports
- **L2** — may import L1 packages
- **L3** — may import L2 packages

## Packages

Support % is computed as `Supported / Total`, where *Total* is the number of rows in each package's support table (Supported + Partially Supported + Not Yet Supported + Cannot Support).

| Package | Level | Supported | Partially Supported | Not Yet Supported | Cannot Support | Support % |
|---|---|---|---|---|---|---|
| [http](http/bal/README.md) | L1 | 17 | 6 | 45 | 0 | 25% |
| [io](io/bal/README.md) | L1 | 13 | 1 | 12 | 0 | 50% |
| [log](log/bal/README.md) | L1 | 7 | 1 | 16 | 0 | 29% |
| [math.vector](math.vector/bal/README.md) | L1 | 5 | 0 | 0 | 0 | 100% |
| [random](random/bal/README.md) | L1 | 3 | 1 | 1 | 0 | 60% |
| [time](time/bal/README.md) | L1 | 27 | 0 | 5 | 0 | 84% |
| [url](url/bal/README.md) | L1 | 2 | 1 | 1 | 0 | 50% |
| [crypto](crypto/bal/README.md) | L2 | 26 | 1 | 5 | 0 | 81% |
| [mime](mime/bal/README.md) | L2 | 13 | 1 | 2 | 0 | 81% |
| [os](os/bal/README.md) | L2 | 10 | 1 | 1 | 0 | 83% |
| [file](file/bal/README.md) | L3 | 20 | 0 | 0 | 1 | 95% |
| [uuid](uuid/bal/README.md) | L3 | 19 | 1 | 0 | 0 | 95% |
| **Total** | | **162** | **14** | **88** | **1** | **61%** |

# Architecture

Ballerina Nutcracker compiles a `.bal` program to **Ballerina Intermediate Representation (BIR)** and then interprets that BIR. Almost everything below is a Go package inside the single static `bal` binary; only Ballerina Central and the host OS sit outside it.

![Ballerina Nutcracker architecture, left to right: the bal CLI feeds the compilation pipeline (parse, AST, symbols and types, desugar, emit BIR), whose BIR is executed by the runtime (dispatch loop, strands and frames, values, extern bridge), which reaches the host only through the Platform Adaptation Layer. The library of language and standard modules is resolved both at compile time and at run time. Ballerina Central and the host OS are the only boundaries outside the binary.](../img/architecture.svg)

## Compilation pipeline

Source becomes BIR in five phases, which map directly onto source directories:

| Phase | Directory | What happens |
| --- | --- | --- |
| Parse | [`parser/`](../../parser/) | Lexing and parsing into a syntax tree, with error recovery |
| AST | [`ast/`](../../ast/) | Syntax tree lowered to an abstract syntax tree |
| Symbols, types & analysis | [`semantics/`](../../semantics/) | Symbol resolution, type resolution, semantic analysis, CFG construction and analysis — drawing on the `semtypes/` type system |
| Desugar | [`desugar/`](../../desugar/) | Syntactic sugar lowered to core constructs |
| Generate BIR | [`bir/`](../../bir/) | BIR model, generation, and codec |

Expanded into the stages that actually run — 1–10 produce BIR, and 11 is the runtime executing it:

1. Generate syntax tree
2. Generate abstract syntax tree (AST)
3. Symbol resolution
4. Type resolution of top-level nodes
5. Type resolution of inner nodes (function bodies, type narrowing)
6. Semantic analysis
7. Generate control flow graph (CFG)
8. Analyze CFG (reachability, explicit return)
9. Desugar AST
10. Generate BIR
11. Interpret BIR

Stages 1–2 run per module in any order. Stages 3–4 are topologically sorted, since a module's symbol and type resolution depends on its dependencies. If any module reports an error in stages 1–4, the pipeline stops before stage 5. Stages 5–10 then run concurrently per module, and if any module has errors after stage 10, no BIR is loaded and stage 11 is skipped entirely.

The sequential/concurrent orchestration and the stop-before-stage-5 rule live in `projects/package_compilation.go`; the per-module stage bodies are in `projects/module_context.go`, and `test_util/testphases/phases.go` drives them for corpus tests. See [AGENTS.md](../../AGENTS.md) for the precise error-handling rules.

## Runtime

[`runtime/`](../../runtime/) holds the BIR interpreter — the dispatch loop, strands and call frames, and module lifecycle. [`values/`](../../values/) holds the runtime representation of Ballerina values (lists, maps, XML, objects, errors). The extern bridge in `runtime/extern` is how BIR calls reach native Go implementations.

`semtypes/`, the structural type system, cuts across both pipeline and runtime rather than sitting at one stage — it is used by `ast/` and `semantics/` for type resolution, and again by `desugar/`, `bir/`, `runtime/`, and `values/`. It does not reach `parser/`, which is purely syntactic.

## Library

[`lib/langlibs/`](../../lib/langlibs/) is the **language library** (`lang.array`, `lang.map`, `lang.string`, …) — built-in operations on core types, required by every program. [`lib/stdlibs/`](../../lib/stdlibs/) is the **standard library** (`http`, `io`, `os`, `crypto`, …) — optional capability modules, versioned like regular packages. [`lib/langinternal/`](../../lib/langinternal/) holds compiler- and runtime-only symbols that are not public API.

Both libraries are declared in Ballerina, and they are not only a runtime dependency — the pipeline resolves against them during symbol and type resolution too.

Where a module needs native code, its Go implementation is registered by [`lib/rt`](../../lib/rt/). Some modules (`lang.value`, `lang.object`, `math.vector`) are pure Ballerina with no `external` functions at all.

## Platform Adaptation Layer

[`platform/pal/`](../../platform/pal/) defines the interface — `pal.Platform` has exactly six fields: `IO`, `FS`, `OS`, `Time`, `HTTP` and `Signals`. [`platform/palnative/`](../../platform/palnative/) implements them for a native host.

Everything the **runtime and the library** do to the outside world goes through this seam rather than calling the OS or the Go standard library directly.

The rule binds the interpreter, not the whole binary. The toolchain half — `cli/`, `projects/`, `compiler-tools/` — reads and writes files and talks to Ballerina Central with `os` and `net/http` directly.

The seam also exists so that a non-native host could be swapped in. Only `palnative` exists today and there is no `js/wasm` platform implementation, but CI runs the whole test suite under `GOOS=js GOARCH=wasm` to keep the code portable — see [DEVELOPING.md](DEVELOPING.md#wasm).

## Supporting packages

| Path | Role |
| --- | --- |
| [`cli/`](../../cli/) | The `bal` command-line entry point |
| [`projects/`](../../projects/) | Manifest parsing, package and dependency resolution, `.bala` archives |
| [`model/`](../../model/) | Symbols, package and flag metadata |
| [`context/`](../../context/) | Compiler context and environment shared across stages |
| [`tools/diagnostics/`](../../tools/diagnostics/) | Errors and warnings surfaced by every stage |
| [`corpus/`](../../corpus/) | Ballerina test sources and per-stage golden files |
| [`compiler-tools/`](../../compiler-tools/) | Standalone tools: the `tree-gen` generator, `cfgviz`, and the benchmark harness |
| [`cli/internal/nativeexec/`](../../cli/internal/nativeexec/) | Builds a project-specific interpreter when a dependency ships its own native Go code, using the interpreter source embedded by `interpsrc.go` |

## Boundaries

Solid arrows in the diagram are function calls inside one process. Two things sit outside the binary:

- **Ballerina Central** — the remote `.bala` registry, reached over the network by `projects/centralclient` when resolving dependencies. This is the only remote the toolchain itself talks to; a running Ballerina program makes its own calls through `pal.HTTP`.
- **The host OS** — filesystem, network, environment and signals, reached by the runtime only through the Platform Adaptation Layer.

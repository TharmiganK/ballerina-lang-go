## Purpose

Migrates the `ballerina/http` client library from Go compile structures to the `.bal`-based paradigm introduced by `pack_bal_libs`, and fixes several compiler bugs exposed by that migration that affect any stdlib/langlib package containing classes with `init` functions and records with field defaults.

## Approach

The `pack_bal_libs` branch established a clean pattern: libraries are authored in `.bal`, compiled to `.sym`/`.bir` by `gen-embedded-libs`, and loaded at runtime via the embedded registry. This PR extends that pattern to `ballerina/http`:

**HTTP library migration**
- Adds `stdlib/http/bal/http.bal` — the full HTTP client type surface (`ClientConfiguration`, `ClientSecureSocket`, `FollowRedirects`, `Response`, `Client`) authored as Ballerina, documented against the upstream Java module with Go-runtime limitations noted inline.
- Moves the HTTP Go externs from `lib/http/runtime/` to `stdlib/http/externs/`, following the `langlib/*/externs` convention.
- Deletes `lib/http/compile/http.go` — the hand-written Go type definitions are no longer needed.
- Removes the HTTP special-case in `semantics/symbol_resolver.go`; `ballerina/http` is now resolved through the same embedded registry path as all other platform modules.

**Fixes on top of `pack_bal_libs`** (general, not HTTP-specific)

| File | Fix |
|---|---|
| `model/symbolpool/deserializer.go` | `readSymbolRef` was stamping the current space's `SpaceIndex` onto every deserialized ref, including zero refs. A zero ref (empty package, index 0) used to signal "no default" in `FieldDescriptor.DefaultFnRef`, but after deserialization its `SpaceIndex` became non-zero, making `DefaultFnRef != SymbolRef{}` always true. This caused every optional record field to be treated as having a default, generating invalid function lookup keys at runtime (`"/:HeaderValue"` style). Fix: return the true zero `SymbolRef` when the serialized org and index are both zero. |
| `semantics/symbol_resolver.go` | For public classes, `init` was placed only in the class scope (not the module scope), so its `SymbolRef` was not serializable in `.sym` exports. This broke `padNewExprArgTypesForDefaults` for imported classes — it could not find `init` to pad optional constructor arguments. Fix: mirror the same module-scope placement already used for remote methods. Also added `isPublic \|\| isRemote` for remote method implicit-public promotion so remote methods are properly serialized. |
| `semantics/type_resolver.go` | `classMembers()` iterated only `classDef.Methods`, excluding `InitFunction`. `init` therefore never appeared in the class's inclusion members, was not serialized into `.sym`, and was unavailable to `padNewExprArgTypesForDefaults` when loading from the registry. Fix: append an `init` `MethodDescriptor` alongside the other methods. |
| `desugar/desugar.go` | `desugarClassMethodDefaults` processed parameter defaults for `class.Methods` only, not `class.InitFunction`. Default lambdas for `init` parameters (e.g. `config = {}`) were never added to `pkg.Functions`, causing "function not found" panics at runtime. Fix: include `InitFunction` in the defaults pass. |
| `bir/bir_gen.go` | `transformClassDefinition` always called `transformFunctionInner` for `init`, panicking when `init` is native (`= external`). Fix: guard with `IsNative()` and emit a stub `BIRFunction` instead (same pattern already used for non-init native methods). |

## User stories

- As a Ballerina developer targeting the Go runtime, I can use `import ballerina/http` and call `http:Client`, its remote methods, and `http:Response` payload/header APIs — compiled from a `.bal` source that lives alongside the other langlib/stdlib packages.
- As a contributor extending another stdlib package with a class that has an `init` function and optional parameters, the compiler correctly serializes the class and resolves constructors when importing from the embedded registry.

## Release note

`ballerina/http` client library is now compiled from a `.bal` source file (`stdlib/http/bal/http.bal`) using the same embedded-registry infrastructure introduced for langlibs. This aligns the HTTP module with the standard stdlib authoring pattern. Supported API surface is unchanged; see `lib/http/client-support.md` for the full feature matrix.

Four compiler bugs affecting class serialization, record field default resolution, and constructor argument padding are fixed as a side-effect of this migration. These bugs would affect any future stdlib or langlib package that defines a public class with an `init` function having optional parameters, or a closed record type with field defaults.

## Documentation

`stdlib/http/bal/http.bal` carries inline Ballerina `#` doc comments on all public functions, the `Client` class, and `Response` class, derived from the upstream `module-ballerina-http` documentation and annotated for Go-runtime limitations.

`lib/http/client-support.md` (existing) documents the supported/not-supported API surface in detail.

N/A for external product docs.

## Training

N/A

## Certification

N/A

## Marketing

N/A

## Automation tests

- **Unit tests**: All existing corpus tests pass (`go test ./...`). BIR generation, desugared AST, and parser golden files for the six `http-client-*.bal` corpus tests are updated to reflect the new default-lambda lookup keys (`$desugar$N`). Three pack_bal_libs corpus additions (`vector1-v.bal`, `unknown-ballerina-import-e.bal`, `isolated-local-else-v.bal`) have their parser golden files generated.
- **Integration tests**: `TestHttpClientGet`, `TestHttpClientPost`, `TestHttpClientMethods`, `TestHttpClientTLSInsecure` all pass against the embedded `.bal`-compiled symbols and Go externs.

## Security checks

- Followed secure coding standards: yes
- No keys, passwords, tokens, usernames, or secrets committed: yes

## Samples

`corpus/extern/testdata/http-client-v.bal`, `http-client-post-v.bal`, `http-client-methods-v.bal`, and `http-client-tls-v.bal` demonstrate the full supported client API and serve as runnable integration tests.

## Related PRs

N/A

## Migrations (if applicable)

No migration required. The public API surface of `ballerina/http` is unchanged. Existing `.bal` files using `import ballerina/http` continue to compile without modification. Internal: `lib/http/compile/http.go` and `lib/http/runtime/http.go` are removed; the Go externs move to `stdlib/http/externs/http.go`.

## Test environment

- Go 1.26.0 darwin/arm64
- macOS 15.3 (Darwin 25.3.0, Apple Silicon)

## Learning

The core challenge was that `pack_bal_libs` established the serialization contract for langlib types but had no stdlib class with a non-trivial `init`. Working through the HTTP `Client` class revealed four serialization/deserialization bugs in the compiler's class and record handling that are orthogonal to HTTP itself. The fix to `readSymbolRef` is the most subtle: a zero `SymbolRef` used as a sentinel ("no default function") was being given a non-zero `SpaceIndex` on deserialization, silently breaking the `!= SymbolRef{}` nil check across all deserialized record field descriptors.

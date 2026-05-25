# Ballerina Language Features

## Overview

This document tracks the implementation status of Ballerina language features in the Go Native Interpreter.
It is generated from the [Ballerina Interpreter Release Management](https://github.com/orgs/ballerina-platform/projects/383) project board.

Support Levels:

- **Supported**: The tracking issue is closed — the feature is fully implemented.
- **Not Yet Supported**: The tracking issue is still open — implementation is pending or in progress.

## Milestone Summary

| Milestone | Total Issues | Closed | Status |
|-----------|:------------:|:------:|--------|
| v0.01.0 | 15 | 15 | Supported |
| v0.02.0 | 14 | 14 | Supported |
| v0.03.0 | 17 | 17 | Supported |
| v0.04.0 | 24 | 24 | Supported |
| v0.05.0 | 24 | 24 | Supported |
| v0.06.0 | 23 | 2 | Partially Supported (2/23 closed) |
| v0.07.0 | 12 | 1 | Partially Supported (1/12 closed) |
| v0.08.0 | 15 | 0 | Not Yet Supported |
| v0.09.0 | 6 | 1 | Partially Supported (1/6 closed) |
| v0.10.0 | 3 | 0 | Not Yet Supported |

## Detailed Feature Status

### v0.01.0

| Feature | Support Status |
|---------|----------------|
| [Support Ballerina Runtime Interpreter for Language Subset 1](https://github.com/ballerina-platform/ballerina-lang-go/issues/38) | Supported |
| [Migrate `ballerina-runtime`](https://github.com/ballerina-platform/ballerina-lang-go/issues/11) | Supported |
| [Add WASM tests to the CI workflow](https://github.com/ballerina-platform/ballerina-lang-go/issues/9) | Supported |
| [Migrate `ballerina-parser`](https://github.com/ballerina-platform/ballerina-lang-go/issues/5) | Supported |
| [Migrate the ballerina source parser](https://github.com/ballerina-platform/ballerina-lang-go/issues/15) | Supported |
| [Migrate `ballerina-tools-api`](https://github.com/ballerina-platform/ballerina-lang-go/issues/3) | Supported |
| [Migrate `central-client`](https://github.com/ballerina-platform/ballerina-lang-go/issues/12) | Supported |
| [Migrate Semtypes module](https://github.com/ballerina-platform/ballerina-lang-go/issues/18) | Supported |
| [Migrate definitions of AST nodes](https://github.com/ballerina-platform/ballerina-lang-go/issues/29) | Supported |
| [Migrate BLangNodeBuilder](https://github.com/ballerina-platform/ballerina-lang-go/issues/20) | Supported |
| [Port BLangNodeBuilder](https://github.com/ballerina-platform/ballerina-lang-go/issues/22) | Supported |
| [Port BIRGen](https://github.com/ballerina-platform/ballerina-lang-go/issues/34) | Supported |
| [Implement type resolution](https://github.com/ballerina-platform/ballerina-lang-go/issues/41) | Supported |
| [Port Semantic Analysis](https://github.com/ballerina-platform/ballerina-lang-go/issues/45) | Supported |
| [Add symbol resolutions](https://github.com/ballerina-platform/ballerina-lang-go/issues/67) | Supported |

### v0.02.0

| Feature | Support Status |
|---------|----------------|
| [Implement the Project API](https://github.com/ballerina-platform/ballerina-lang-go/issues/75) | Supported |
| [Port code analyzer](https://github.com/ballerina-platform/ballerina-lang-go/issues/58) | Supported |
| [Add support for union type descriptors in ast](https://github.com/ballerina-platform/ballerina-lang-go/issues/59) | Supported |
| [Add support for module level type declarations](https://github.com/ballerina-platform/ballerina-lang-go/issues/60) | Supported |
| [Add support for error constructor](https://github.com/ballerina-platform/ballerina-lang-go/issues/61) | Supported |
| [Add support for type casts](https://github.com/ballerina-platform/ballerina-lang-go/issues/62) | Supported |
| [Implement data flow analysis](https://github.com/ballerina-platform/ballerina-lang-go/issues/81) | Supported |
| [Add support for binary bitwise operators](https://github.com/ballerina-platform/ballerina-lang-go/issues/90) | Supported |
| [Fix issues in semantic analyzer for subset 2](https://github.com/ballerina-platform/ballerina-lang-go/issues/92) | Supported |
| [Add subset 2 doc](https://github.com/ballerina-platform/ballerina-lang-go/issues/102) | Supported |
| [Multiple license header formats used in the code](https://github.com/ballerina-platform/ballerina-lang-go/issues/72) | Supported |
| [Make it possible for the integration test runner to handle stackoverflows](https://github.com/ballerina-platform/ballerina-lang-go/issues/93) | Supported |
| [Introduce the Project API](https://github.com/ballerina-platform/ballerina-lang-go/issues/446) | Supported |
| [Add runtime support for Subset 2 Ballerina programs (corpus subset2)](https://github.com/ballerina-platform/ballerina-lang-go/issues/107) | Supported |

### v0.03.0

| Feature | Support Status |
|---------|----------------|
| [Runtime Support for subset3](https://github.com/ballerina-platform/ballerina-lang-go/issues/172) | Supported |
| [Improve code coverage of runtime package](https://github.com/ballerina-platform/ballerina-lang-go/issues/165) | Supported |
| [Add method call support](https://github.com/ballerina-platform/ballerina-lang-go/issues/87) | Supported |
| [Add proper support for list mutation](https://github.com/ballerina-platform/ballerina-lang-go/issues/95) | Supported |
| [Properly detect numeric arithmetic overflows](https://github.com/ballerina-platform/ballerina-lang-go/issues/110) | Supported |
| [Add support for foreach over range exp](https://github.com/ballerina-platform/ballerina-lang-go/issues/111) | Supported |
| [Fix package level symbols not getting shadowed correctly](https://github.com/ballerina-platform/ballerina-lang-go/issues/149) | Supported |
| [Add Codecov for coverage reporting](https://github.com/ballerina-platform/ballerina-lang-go/issues/160) | Supported |
| [Variable initialization fails for decimal literals](https://github.com/ballerina-platform/ballerina-lang-go/issues/204) | Supported |
| [Ballerina Bir Reader and Writer](https://github.com/ballerina-platform/ballerina-lang-go/issues/39) | Supported |
| [Add support for foreach over list values](https://github.com/ballerina-platform/ballerina-lang-go/issues/120) | Supported |
| [Add project environment and inject file system abstraction](https://github.com/ballerina-platform/ballerina-lang-go/issues/447) | Supported |
| [Implement error message support](https://github.com/ballerina-platform/ballerina-lang-go/issues/46) | Supported |
| [Add support for tuple types](https://github.com/ballerina-platform/ballerina-lang-go/issues/125) | Supported |
| [Support running a ballerina package](https://github.com/ballerina-platform/ballerina-lang-go/issues/74) | Supported |
| [Add WASM support and release artifact](https://github.com/ballerina-platform/ballerina-lang-go/issues/196) | Supported |
| [Report diagnostics on syntax errors](https://github.com/ballerina-platform/ballerina-lang-go/issues/211) | Supported |

### v0.04.0

| Feature | Support Status |
|---------|----------------|
| [Runtime Support for panic](https://github.com/ballerina-platform/ballerina-lang-go/issues/251) | Supported |
| [Implement native Go TOML parser](https://github.com/ballerina-platform/ballerina-lang-go/issues/237) | Supported |
| [Add support for extern function](https://github.com/ballerina-platform/ballerina-lang-go/issues/263) | Supported |
| [Migrate Documentation parser](https://github.com/ballerina-platform/ballerina-lang-go/issues/16) | Supported |
| [Add conditional type narrowing](https://github.com/ballerina-platform/ballerina-lang-go/issues/85) | Supported |
| [Add support for type test expressions](https://github.com/ballerina-platform/ballerina-lang-go/issues/84) | Supported |
| [Add front end support for type test expressions](https://github.com/ballerina-platform/ballerina-lang-go/issues/145) | Supported |
| [Add backend support for type test expressions](https://github.com/ballerina-platform/ballerina-lang-go/issues/146) | Supported |
| [Add support for bitwise compliment](https://github.com/ballerina-platform/ballerina-lang-go/issues/99) | Supported |
| [Add support for integer bitshift operations](https://github.com/ballerina-platform/ballerina-lang-go/issues/129) | Supported |
| [Add try it browser example to repo](https://github.com/ballerina-platform/ballerina-lang-go/issues/126) | Supported |
| [Add support for map values](https://github.com/ballerina-platform/ballerina-lang-go/issues/96) | Supported |
| [Add front end support for map values](https://github.com/ballerina-platform/ballerina-lang-go/issues/135) | Supported |
| [Add lang lib support for map](https://github.com/ballerina-platform/ballerina-lang-go/issues/136) | Supported |
| [Add backend support for map values](https://github.com/ballerina-platform/ballerina-lang-go/issues/138) | Supported |
| [Make it possible to access the type env from the runtime](https://github.com/ballerina-platform/ballerina-lang-go/issues/132) | Supported |
| [Add back end support for object and class definitions](https://github.com/ballerina-platform/ballerina-lang-go/issues/309) | Supported |
| [Add frontend support for extern functions](https://github.com/ballerina-platform/ballerina-lang-go/issues/266) | Supported |
| [Add foreach support for map values](https://github.com/ballerina-platform/ballerina-lang-go/issues/137) | Supported |
| [Add front end support for module level variables](https://github.com/ballerina-platform/ballerina-lang-go/issues/152) | Supported |
| [Implement Let clause, where clause for Arrays](https://github.com/ballerina-platform/ballerina-lang-go/issues/216) | Supported |
| [Support error constructor at runtime](https://github.com/ballerina-platform/ballerina-lang-go/issues/219) | Supported |
| [Add support for rest parameters in function declaration](https://github.com/ballerina-platform/ballerina-lang-go/issues/244) | Supported |
| [Add support for intersection type descriptors](https://github.com/ballerina-platform/ballerina-lang-go/issues/247) | Supported |

### v0.05.0

| Feature | Support Status |
|---------|----------------|
| [Add support for error values](https://github.com/ballerina-platform/ballerina-lang-go/issues/88) | Supported |
| [Add backend support for xml values](https://github.com/ballerina-platform/ballerina-lang-go/issues/289) | Supported |
| [[Bug]: Float ==/!= semantics were wrong for NaN in runtime](https://github.com/ballerina-platform/ballerina-lang-go/issues/391) | Supported |
| [Add error langlib support](https://github.com/ballerina-platform/ballerina-lang-go/issues/188) | Supported |
| [Add support for optional fields](https://github.com/ballerina-platform/ballerina-lang-go/issues/369) | Supported |
| [Add support for included record param](https://github.com/ballerina-platform/ballerina-lang-go/issues/337) | Supported |
| [Add front end support for xml values](https://github.com/ballerina-platform/ballerina-lang-go/issues/288) | Supported |
| [[Bug]: Getting intermittent bad pointer in Go heap when running WASM CI](https://github.com/ballerina-platform/ballerina-lang-go/issues/341) | Supported |
| [Float and decimal division should never cause a panic](https://github.com/ballerina-platform/ballerina-lang-go/issues/364) | Supported |
| [Diagnostic reporting panics when two packages have a file with the same name](https://github.com/ballerina-platform/ballerina-lang-go/issues/407) | Supported |
| [Add HTTP Client basic support](https://github.com/ballerina-platform/ballerina-lang-go/issues/444) | Supported |
| [Runtime validation for list mutation](https://github.com/ballerina-platform/ballerina-lang-go/issues/140) | Supported |
| [Validate record mutations](https://github.com/ballerina-platform/ballerina-lang-go/issues/177) | Supported |
| [Validate tuple mutation](https://github.com/ballerina-platform/ballerina-lang-go/issues/176) | Supported |
| [Migrate XML parser](https://github.com/ballerina-platform/ballerina-lang-go/issues/17) | Supported |
| [Support workspace projects](https://github.com/ballerina-platform/ballerina-lang-go/issues/349) | Supported |
| [Add support for enum](https://github.com/ballerina-platform/ballerina-lang-go/issues/402) | Supported |
| [Add support for dependently typed functions](https://github.com/ballerina-platform/ballerina-lang-go/issues/334) | Supported |
| [Support dependently typed functions](https://github.com/ballerina-platform/ballerina-lang-go/issues/365) | Supported |
| [Add support for network interactions in objects in the frontend](https://github.com/ballerina-platform/ballerina-lang-go/issues/362) | Supported |
| [Benchmark tool](https://github.com/ballerina-platform/ballerina-lang-go/issues/312) | Supported |
| [Support rest parameters in method declarations](https://github.com/ballerina-platform/ballerina-lang-go/issues/262) | Supported |
| [Add support for named arguments](https://github.com/ballerina-platform/ballerina-lang-go/issues/335) | Supported |
| [Add iterable object foreach desugaring](https://github.com/ballerina-platform/ballerina-lang-go/issues/291) | Supported |

### v0.06.0

| Feature | Support Status |
|---------|----------------|
| [Implement the CLI commands](https://github.com/ballerina-platform/ballerina-lang-go/issues/40) | Not Yet Supported |
| [Add minimum support for file read and write](https://github.com/ballerina-platform/ballerina-lang-go/issues/127) | Not Yet Supported |
| [Implement query expressions in frontend](https://github.com/ballerina-platform/ballerina-lang-go/issues/189) | Not Yet Supported |
| [Support dependency resolution](https://github.com/ballerina-platform/ballerina-lang-go/issues/253) | Not Yet Supported |
| [Add support for XML basic type](https://github.com/ballerina-platform/ballerina-lang-go/issues/281) | Not Yet Supported |
| [Add support for stream values](https://github.com/ballerina-platform/ballerina-lang-go/issues/284) | Not Yet Supported |
| [Add support for remote/resource method declarations](https://github.com/ballerina-platform/ballerina-lang-go/issues/287) | Not Yet Supported |
| [Migrate nBallerina test suite](https://github.com/ballerina-platform/ballerina-lang-go/issues/433) | Supported |
| [NaN equality propagation fix for structural types](https://github.com/ballerina-platform/ballerina-lang-go/issues/394) | Not Yet Supported |
| [Add CI workflow to run benchmarks on pull requests](https://github.com/ballerina-platform/ballerina-lang-go/issues/396) | Not Yet Supported |
| [Add support for bal pack command](https://github.com/ballerina-platform/ballerina-lang-go/issues/435) | Not Yet Supported |
| [Add unused variable detection to the frontend](https://github.com/ballerina-platform/ballerina-lang-go/issues/439) | Not Yet Supported |
| [Add unused import detection to frontend](https://github.com/ballerina-platform/ballerina-lang-go/issues/441) | Not Yet Supported |
| [Support functions that return never](https://github.com/ballerina-platform/ballerina-lang-go/issues/443) | Supported |
| [Add support for local repository](https://github.com/ballerina-platform/ballerina-lang-go/issues/445) | Not Yet Supported |
| [Add support for `bal push` command](https://github.com/ballerina-platform/ballerina-lang-go/issues/449) | Not Yet Supported |
| [Add support for dependency caching](https://github.com/ballerina-platform/ballerina-lang-go/issues/450) | Not Yet Supported |
| [Implement group by and collect for lists and maps](https://github.com/ballerina-platform/ballerina-lang-go/issues/455) | Not Yet Supported |
| [Embed ballerina langlib and stdlib for compile-time symbols and runtime BIR interpretation](https://github.com/ballerina-platform/ballerina-lang-go/issues/461) | Not Yet Supported |
| [Add support for declaring service objects](https://github.com/ballerina-platform/ballerina-lang-go/issues/464) | Not Yet Supported |
| [[Bug]: Deal with list type creation in runtime for rest args](https://github.com/ballerina-platform/ballerina-lang-go/issues/471) | Not Yet Supported |
| [Add support for `@typeParam`](https://github.com/ballerina-platform/ballerina-lang-go/issues/472) | Not Yet Supported |
| [Add runtime support for graceful and immediate stop](https://github.com/ballerina-platform/ballerina-lang-go/issues/475) | Not Yet Supported |

### v0.07.0

| Feature | Support Status |
|---------|----------------|
| [Add cli tests](https://github.com/ballerina-platform/ballerina-lang-go/issues/48) | Not Yet Supported |
| [Add support for isolated functions](https://github.com/ballerina-platform/ballerina-lang-go/issues/359) | Not Yet Supported |
| [Remove model.tree definitions](https://github.com/ballerina-platform/ballerina-lang-go/issues/370) | Supported |
| [Improve code coverage for CLI and project api](https://github.com/ballerina-platform/ballerina-lang-go/issues/326) | Not Yet Supported |
| [Add support for named arguments for function values](https://github.com/ballerina-platform/ballerina-lang-go/issues/336) | Not Yet Supported |
| [Fix typetest for function types](https://github.com/ballerina-platform/ballerina-lang-go/issues/350) | Not Yet Supported |
| [Add WASM target to benchmark tool](https://github.com/ballerina-platform/ballerina-lang-go/issues/395) | Not Yet Supported |
| [Add support for string template expressions](https://github.com/ballerina-platform/ballerina-lang-go/issues/412) | Not Yet Supported |
| [Add support for xml template expressions](https://github.com/ballerina-platform/ballerina-lang-go/issues/413) | Not Yet Supported |
| [Add support for optional field access expressions](https://github.com/ballerina-platform/ballerina-lang-go/issues/421) | Not Yet Supported |
| [Add support for isolated lambdas](https://github.com/ballerina-platform/ballerina-lang-go/issues/428) | Not Yet Supported |
| [Support package registries and version resolution](https://github.com/ballerina-platform/ballerina-lang-go/issues/451) | Not Yet Supported |

### v0.08.0

| Feature | Support Status |
|---------|----------------|
| [Add constant propagation](https://github.com/ballerina-platform/ballerina-lang-go/issues/83) | Not Yet Supported |
| [Add support for named arguments in error constructor](https://github.com/ballerina-platform/ballerina-lang-go/issues/112) | Not Yet Supported |
| [Add type match patterns](https://github.com/ballerina-platform/ballerina-lang-go/issues/162) | Not Yet Supported |
| [Add frontend support for future values](https://github.com/ballerina-platform/ballerina-lang-go/issues/296) | Not Yet Supported |
| [Add backend support for future values](https://github.com/ballerina-platform/ballerina-lang-go/issues/297) | Not Yet Supported |
| [Running tests in parallel randomly deadlock in WASM CI](https://github.com/ballerina-platform/ballerina-lang-go/issues/303) | Not Yet Supported |
| [Add equality support for xml](https://github.com/ballerina-platform/ballerina-lang-go/issues/416) | Not Yet Supported |
| [Remove restriction on constant expressions in XML namespace declarations](https://github.com/ballerina-platform/ballerina-lang-go/issues/417) | Not Yet Supported |
| [Add support for lock statements](https://github.com/ballerina-platform/ballerina-lang-go/issues/422) | Not Yet Supported |
| [Add concurrency support](https://github.com/ballerina-platform/ballerina-lang-go/issues/426) | Not Yet Supported |
| [Add support for start and wait actions](https://github.com/ballerina-platform/ballerina-lang-go/issues/427) | Not Yet Supported |
| [Migrate existing test suites](https://github.com/ballerina-platform/ballerina-lang-go/issues/432) | Not Yet Supported |
| [Migrate jBallerina test suite](https://github.com/ballerina-platform/ballerina-lang-go/issues/434) | Not Yet Supported |
| [Support arguments in main function](https://github.com/ballerina-platform/ballerina-lang-go/issues/442) | Not Yet Supported |
| [Add support for the test framework](https://github.com/ballerina-platform/ballerina-lang-go/issues/452) | Not Yet Supported |

### v0.09.0

| Feature | Support Status |
|---------|----------------|
| [Add support for match guard](https://github.com/ballerina-platform/ballerina-lang-go/issues/163) | Not Yet Supported |
| [Add frontend support for tables](https://github.com/ballerina-platform/ballerina-lang-go/issues/294) | Not Yet Supported |
| [Add backend support for tables](https://github.com/ballerina-platform/ballerina-lang-go/issues/295) | Not Yet Supported |
| [Refactor how we handle generic function symbols](https://github.com/ballerina-platform/ballerina-lang-go/issues/389) | Supported |
| [Add platform support for compiler plugins](https://github.com/ballerina-platform/ballerina-lang-go/issues/453) | Not Yet Supported |
| [Add platform support for CLI-based developer tools](https://github.com/ballerina-platform/ballerina-lang-go/issues/454) | Not Yet Supported |

### v0.10.0

| Feature | Support Status |
|---------|----------------|
| [Add support for Table values](https://github.com/ballerina-platform/ballerina-lang-go/issues/282) | Not Yet Supported |
| [Add support for future values](https://github.com/ballerina-platform/ballerina-lang-go/issues/283) | Not Yet Supported |
| [Add support for template expressions](https://github.com/ballerina-platform/ballerina-lang-go/issues/411) | Not Yet Supported |

---

## Gaps Discovered During Stdlib Migration

The following limitations were found while implementing Go-native standard library packages. They are not yet tracked on the project board. Each entry includes the exact interpreter panic or error that surfaced the gap so it can be reproduced and linked to a tracking issue.

| Feature | Support Status | How it was discovered |
|---------|----------------|-----------------------|
| Elvis operator (`?:`) | Not Yet Supported | `panic: TransformBinaryExpression: elvis operator not supported` — triggered by expressions like `precision ?: -1` and `utcOffset?.hours ?: 0` in `ballerina/time` API wrappers |
| `distinct` type descriptor | Not Yet Supported | `panic: TransformDistinctTypeDescriptor unimplemented` — triggered by `public type FormatError distinct Error` in `ballerina/time` error types |
| Doc-comment metadata on `type` declarations | Not Yet Supported | `panic: TransformTypeDefinition: metadata not yet supported` — triggered when `#` Ballerina doc comments appear directly above a `type` declaration (functions are unaffected) |
| `readonly &` intersection on record constructors | Not Yet Supported | `error: no applicable inherent type for mapping constructor` — triggered by `public final ZoneOffset Z = {hours: 0}` when `ZoneOffset` was declared as `readonly & record {| ... |}`. Fixed by removing the `readonly &` qualifier from the type definition. |
| `lang.decimal` built-in methods (`floor`, `ceiling`, `round`, `abs`) | Not Yet Supported | No `lang.decimal` langlib is implemented. Expressions like `seconds.floor()` in Ballerina source silently fail to resolve, requiring arithmetic to be moved into Go externs. |
| Arbitrary named arguments via included rest-record parameters (`*T` where `T` has `anydata...` rest fields) | Not Yet Supported | `error[SEMANTIC_ERROR]: no such parameter <name>` — triggered by `log:printInfo("msg", port = 8080)` when `printInfo` declares `*KeyValues keyValues` and `KeyValues` has `anydata...` rest fields. Named args for explicit optional fields (e.g., `'error = e`) work correctly. |

## Known Workarounds

The following constructs compile or parse without error in jBallerina but fail in this interpreter. When porting stdlib source, check this table first and apply the workaround rather than scoping out the feature. If you encounter a new construct that is not listed here, add a row and present the options to the developer (see the `add-stdlib-support` skill).

| Construct | Failure mode | Recommended workaround |
|---|---|---|
| Tuple destructuring assignment `[a, b] = check f()` | `panic: unimplemented` (LIST_BINDING_PATTERN in `TransformAssignmentStatement`) | Define a private record type with named fields and return it instead of a tuple; access fields with `.fieldName` |
| Shorthand map constructor `{name}` (variable name as implicit key) | `panic: mapping constructor var-name field not implemented` | Use the explicit form `{name: name}` |
| Ternary / conditional expression `a ? b : c` | `panic: TransformConditionalExpression unimplemented` | Extract a small private `if/else` helper function and call it in the initialiser |
| Rest-arg spread in calls `f(...arr)` | `panic: TransformRestArgument unimplemented` | Change the receiving function's signature from `T...` to `T[]`; pass the array directly without `...` |
| Non-XML string template literal `string \`text ${expr}\`` | Returns `nil` from `TransformTemplateExpression` → nil-interface conversion panic at the call site | Replace with string concatenation (`"text " + expr.toString()`) or move the formatting into a Go extern |
| `check` expression inside a `while` condition `while cond && check f(x)` | The `check` sub-expression captures the value of `x` at loop entry and does not re-evaluate on each iteration — loop terminates at the wrong point or runs forever | Rewrite as `while cond { if check_result { break; } body; }` so the call happens unconditionally inside the body |
| Wildcard match clause `_ => {}` on an exhaustive union type | `error: unmatchable match clause` / `unreachable match clause` | Remove the wildcard; Ballerina's type system enforces exhaustiveness on closed unions, so the wildcard is unreachable |
| `foreach var` with inferred iteration-variable type | `panic: interface conversion: semtypes.SemType is nil, not *semtypes.ComplexSemType` — the wildcard/inferred variable has a nil semtype, which propagates into the foreach body | Always declare an explicit element type: `foreach int i in range` or `foreach byte b in arr` instead of `foreach var i` / `foreach var _` |
| Duplicate `import … as alias` across files in the same module | `error: import alias 'X' already defined` | Place each import alias in exactly one `.bal` file of the module; other files in the same module can use the alias without re-importing |
| Field access on a union type narrowed via the **else / fall-through** path (e.g. `if v is byte[] { … } else { v.field }`) | `error[SEMANTIC_ERROR]: unsupported container type for field access` — narrowing is not propagated into else-branch or statements after the if block | Flip the condition so the field access is in the **truthy** branch: `if v is RecordType { v.field }` |

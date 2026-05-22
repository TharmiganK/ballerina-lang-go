---
name: add-stdlib-support
description: Add a new ballerina/<name> stdlib package, or fix gaps in an existing one against the jBallerina reference implementation. Use when the user asks to migrate, port, add, extend, or fix a gap in a Ballerina standard library module in this repo.
---

# Adding or Extending a Standard Library Package

This skill is the end-to-end workflow for porting a `ballerina/<name>` package from jBallerina (Java) to this Go-native interpreter, or filling gaps in one that's already partially ported. Follow the steps in order. Do not skip the planning gates.

All coding rules, the PAL constraint, and the README template referenced here live in `AGENTS.md` at the repo root — read it before implementing. This skill encodes the *process*, not the rules.

## 1. Acquire the jBallerina reference

Ask the user for the path to the corresponding jBallerina **library implementation root**, e.g. `~/github/ballerina-platform/module-ballerina-<name>/`. Do not proceed without it.

That root should contain:

- `ballerina/` — the Ballerina-side source (public API, type declarations, extern function signatures).
- `native/` *(optional)* — the Java native implementation backing the extern functions. Pure-Ballerina libraries do not have this directory; that's fine, just note it.

Then:

- Read every `.bal` file under `<root>/ballerina/`, excluding `tests/` and `build/`, to enumerate the full jBallerina feature set and identify which functions are `external`.
- If `<root>/native/` exists, read the Java sources backing those extern functions. This is the authoritative source of truth for runtime semantics — error wording, edge-case handling, parsing rules, numeric behaviour — and it's what the Go externs must match for parity (see Step 5). Don't infer behaviour from the `.bal` signatures alone when Java source is available.
- If the package already exists under `stdlib/<name>/`, also read every `.bal` file under `stdlib/<name>/bal/` and the Go externs under `stdlib/<name>/externs/` so you know what's already implemented.

## 2. Resolve imports up-front

Scan the jBallerina source for `import ballerina/<X>` statements.

- For each `<X>` that is **not** already present under this repo's `stdlib/`: tell the user that dependency must be implemented first. If they ask to continue anyway, narrow the plan to only features that don't depend on `<X>`.
- For each `<X>` that **is** already present under `stdlib/<X>/`: read `stdlib/<X>/bal/README.md` and note every row whose status is **Not Yet Supported**, **Partially Supported**, or **Cannot Support**, plus anything under **Notable Behavioural Changes**. If our in-scope features depend on any of those gaps or divergences, surface them in the plan (Step 4) under a **Dependency Limitations** section so the developer reviewing the plan sees exactly which downstream constraints we're inheriting and either scope the feature out or note the inherited divergence.
- **Exception:** `ballerina/jballerina.java.arrays` will not get a Go equivalent. Surface a warning, and plan to replace its uses with a Go-native equivalent inside the externs layer.

Do not silently drop features because of a missing import or an inherited dependency gap — always flag and confirm.

## 3. Cross-check language support

Read `docs/lang-features.md`. If a planned feature relies on Ballerina language constructs that are still listed as **Not Yet Supported** in this interpreter, drop or defer that feature. Note these in the plan so the user sees what was scoped out and why.

## 4. Propose a plan and a showcase `.bal` file

Produce both:

- **Plan** — a list of features in scope for this iteration, with explicit "Not Yet Supported" notes for anything left out (use the same vocabulary as the README template). Include a **Dependency Limitations** section listing any inherited gaps or behavioural divergences pulled in from the README of every `ballerina/<X>` package we import (per Step 2), so reviewers see what we're inheriting before they approve.
- **Showcase `.bal` file** — a small program that exercises every feature in scope end-to-end. Use `@output` markers for expected output.

**Wait for the user to approve the plan and the showcase file before touching any Go code.**

## 5. Behavioral parity analysis

The Go-native behavior **must match the jBallerina (JVM) behavior** for every supported feature. Users migrating from jBallerina must not observe breaking changes. Before writing any Go code, produce a parity table for each in-scope feature:

| Feature | Known Go/JVM divergence risk | Avoidable? | Resolution |
|---|---|---|---|
| ... | ... | ... | ... |

### Areas to investigate for every stdlib port

- **Decimal/floating-point precision** — Ballerina `decimal` maps to `java.math.BigDecimal` on the JVM. Verify that the Go `decimal` runtime type preserves the same precision, rounding mode, and string representation.
- **String encoding** — Java uses UTF-16 internally; Go uses UTF-8. Check whether any string operations (length, indexing, formatting) can produce different output for non-ASCII input.
- **Error messages** — Differences in the *underlying* exception/error text between Java and Go are **acceptable** and **not** a behavioural change. Most Ballerina libraries wrap underlying failures in a Ballerina `error` with their own message and `error:Cause` — that **outer Ballerina error message and error type** must stay consistent with jBallerina across both runtimes. The text of the `cause` (the raw Java/Go error) is allowed to diverge.
- **Numeric overflow and edge cases** — Verify min/max values, overflow semantics, and NaN/Infinity handling against the jBallerina reference.
- **Module-specific risks** — each domain has its own divergence hot-spots; see the examples below.

### Domain-specific risks (time module)

- **RFC 3339 / RFC 5322 parsing edge cases** — Compare acceptance of trailing spaces, lowercase `z`, sub-second precision beyond 9 digits, obsolete RFC 5322 offset formats, and named timezone comments (e.g., `(PST)`).
- **`utcToEmailString` zone representation** — Verify exactly which string each `UtcZoneHandling` value produces (e.g., `"0"` → `"GMT"` in jBallerina).
- **Sub-second precision in `utcToString` / `civilToString`** — jBallerina may strip trailing zeros; confirm the Go output matches.
- **Leap second handling** — Java's `java.time` and Go's `time` package both model leap seconds differently. Verify that UTC ↔ Civil conversions agree at known leap-second boundaries.
- **Timezone data source** — Java ships its own IANA zone database; Go uses the OS-supplied or embedded `tzdata`. Note any zone ID format or DST offset differences.
- **Monotonic clock epoch** — `monotonicNow()` is explicitly "unspecified epoch" — a behavioral difference here is **acceptable and expected**; document it as such.

### Rules

- If a divergence is **avoidable** at the Go implementation level — fix it before merging.
- If a divergence is **unavoidable** (architectural Go/JVM constraint that cannot be resolved in the externs layer) — record it in the README as a **Notable Behavioural Change** *before* implementing, so it is visible from the start. Do not bury it in a post-hoc note.
- Do not proceed to Step 6 without a complete parity table, even if every row says "No risk identified."

## 6. Evaluate Go libraries (only if external deps are needed)

For each external functionality, evaluate 2–3 candidate Go libraries on:

| Axis | What to check |
|---|---|
| Availability | Active maintenance, last release within ~12 months, owner responsive |
| Licensing | Prefer MIT / Apache-2.0 / BSD. **Flag GPL/AGPL/LGPL** — these need explicit user sign-off |
| Stability | v1.x+, release cadence, open-issue health, test coverage if visible |
| Dependency footprint | Transitive dep count, binary-size impact, anything pulling in CGo |

Present the comparison as a small table with a recommendation. **Wait for user approval** before adding the dependency to `go.mod`.

If the work needs no external deps, skip this step.

## 7. Implement

Code lives in two places:

- `stdlib/<name>/bal/` — the Ballerina-side surface (`.bal` files declaring the public API and externs).
- `stdlib/<name>/externs/` — the Go implementation of the externs.

**PAL constraint:** every platform interaction (io, http, fs, env, time, etc.) must go through the Platform Adaptation Layer, never the underlying Go stdlib directly. This is what makes CLI and WASM builds both work. If the relevant PAL method doesn't exist, raise it explicitly before implementing.

Coding rules to honor (full list in `AGENTS.md`):

- Don't make symbols public unless asked or needed.
- License header on every `.bal` and `.go` file.
- No per-line comments — if a block needs explanation, extract a named function.
- When multiple structs share fields and methods, use a private `*Base` struct with type inclusion.
- Never store `model.Symbol` as a map key — always `model.SymbolRef`.
- Don't call operations on symbols directly — go through the compiler context.

## 8. Tests

Add corpus tests under `corpus/bal/`, targeting **≥80% coverage** of the new Go code in `stdlib/<name>/externs/`.

- Use the right suffix: `*-v.bal` (valid, end-to-end), `*-e.bal` (compile-time errors), `*-p.bal` (runtime panics), `*-f{v|e|p}.bal` (future, scope-deferred).
- Use markers: `@output`, `@error`, `@panic` per the rules in `AGENTS.md`.
- Name files **without leading zeros** in numeric parts (e.g. `print1-v.bal`, not `print01-v.bal`).
- Generate or update expected outputs under `corpus/<stage>/` using `go test ./corpus -update`, then review the diff before committing.

## 9. README

Create or update `stdlib/<name>/bal/README.md`.

- **New package** → create from the template below; fill in Overview, Key Functionalities, Examples, and the support table.
- **Existing package** → update the status table rows whose status changed.
- **Notable Behavioural Changes** — copy every unavoidable divergence from the Step 5 parity table directly into this section. These must be present *before* the PR is merged, not added later. Anything that will be closed by future implementation belongs in the support table as "Not Yet Supported", **not** here.
- Keep the Feature/API column generic-prose only. Type and function names belong in Comments.

### README template

````markdown
# Ballerina <Name> Library

## Overview
<Brief description of the full jBallerina module scope.>

## Key Functionalities

<Bullet list of what the Go-native version currently supports — not the full jBallerina feature set.>

## Examples

```ballerina
<Short working example using only currently supported APIs.>
```

## Go Native Interpreter Support Status

This library is currently being migrated to Go to support the Ballerina Native Interpreter. The table below outlines the current support level for various features of this library in the Go implementation.

Support Levels:

- **Supported**: Fully implemented and tested in the Go version.
- **Partially Supported**: Implemented but lacking some edge cases, options, or sub-features. (See comments).
- **Not Yet Supported**: Planned for migration, but not yet implemented.
- **Cannot Support**: Cannot be implemented in the Go version due to technical limitations or architectural differences. (See comments).

| Feature/API | Support Status | Comments / Limitations |
|---|---|---|
| ... | ... | ... |

### Notable Behavioural Changes

<Use bullet points with bold headers, one bullet per divergence. Format each as:
- **<Short title>.** <jBallerina behaviour>; the Go-native version <Go-native behaviour> — <reason if helpful>.

If there are no notable behavioural changes, write:
There are **no** notable behavioural changes in the Go-native version compared to the original jBallerina implementation for the currently supported features.>
````

### README rules

- **Feature/API column**: generic prose descriptions only — no backtick function names, type names, or object names. Those may appear in the Comments column only.
- **Table separators**: always use `|---|---|---|`, never wide-padded columns.
- **Supported rows**: leave the Comments column empty unless there is a meaningful caveat. Do not write "Fully implemented and tested in the Go version." — that is implied by the status.
- **Key Functionalities and Examples**: reflect only what the Go-native version currently supports.
- **Notable Behavioural Changes**: use bullet points with a bold header followed by a period (e.g. `- **Title.** Explanation.`). Only for permanent Go-level constraints; gaps that will be closed by future implementation belong in the support table as "Not Yet Supported", not here.

## 10. Verify

Before declaring done:

1. `go test ./corpus` — all corpus tests pass.
2. `go run ./cli/cmd run <showcase>.bal` — the showcase file runs and its output matches the `@output` markers.
3. If you regenerated golden files, `git diff` them and confirm the changes match expectations.
4. **Parity spot-check** — for every row in the Step 5 parity table marked "Avoidable / Fixed", manually verify the Go output matches the jBallerina reference output for at least one representative input.

Report what was implemented, what was scoped out (and why), any new PAL methods or dependencies added, and the complete parity table from Step 5.

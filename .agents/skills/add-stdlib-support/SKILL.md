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

### Dependency level placement

The `gen-embedded-libs` tool compiles stdlib packages in explicit dependency levels defined in `tools/gen-embedded-libs/main.go` (`stdlibLevels`). Packages within a level are compiled in parallel; a level only starts once the previous level is complete.

**Rule:** A package must be in a level strictly higher than every stdlib package it imports.

- **New package:** find the highest level of every stdlib dependency (`ballerina/<X>` it imports); assign the new package to `max_dependency_level + 1`. If it has no stdlib imports, place it in L1.
- **Filling a gap in an existing package:** if the change adds a new `import ballerina/<X>`, check the current level of `<X>`. If the current package's level is not already higher, move the package up to `level_of_X + 1` in `stdlibLevels`.

In both cases update `stdlibLevels` in `tools/gen-embedded-libs/main.go` as part of the same change, then re-run `go run -tags bootstrap ./tools/gen-embedded-libs` to verify the new level order compiles cleanly.

## 3. Cross-check language support

Read `docs/lang-features.md` in full — including the **"Known Workarounds"** section at the bottom. That section lists constructs that compile in jBallerina but fail in this interpreter (panic or silent misbehaviour at compile time or runtime), together with the recommended rewrite for each.

- If a planned feature uses a construct marked **Not Yet Supported** in the main table, drop or defer the feature and note it in the plan.
- If a planned feature uses a construct listed in the **Known Workarounds** table, apply the documented workaround during implementation (Step 7) rather than scoping out the feature. Note the workaround in the plan so reviewers are aware.

### Handling unexpected compile failures during implementation

When `go run -tags bootstrap ./tools/gen-embedded-libs` panics or emits compile errors that are **not explained** by `docs/lang-features.md`, do the following:

1. Identify the panic message and the Ballerina construct that triggered it.
2. Add a new row to the **Known Workarounds** table in `docs/lang-features.md` describing the construct, the failure mode, and (once resolved) the workaround.
3. Stop and present the developer with the options below — **do not silently pick one**:

> **Unexpected language limitation found:** `<construct>` is not supported (`panic: <message>`).
>
> Options:
> 1. **Fix the interpreter** — implement this construct in the compiler/BIR pipeline. Requires a separate change; I can outline what needs to change.
> 2. **Work around in Ballerina** — rewrite the Ballerina source to avoid the construct (I will apply the workaround and update `docs/lang-features.md`).
> 3. **Move to Go extern** — replace the Ballerina function body with `= external` and implement the logic in the Go externs.
> 4. **Scope out this feature** — mark it as "Not Yet Supported" in the README and move on.
>
> Which option do you prefer?

After the developer responds, apply the chosen resolution and update the workaround row in `docs/lang-features.md` before continuing.

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

### Wire-up checklist — required for every new stdlib package

Beyond the two source directories, these four files must also be updated. Missing any one of them causes silent failures (functions not found at runtime, or nil-pointer panics in corpus tests) that are hard to diagnose:

1. **`lib/rt/libs.go`** — add a blank import so the `init()` in the externs package runs when the binary starts:
   ```go
   _ "ballerina-lang-go/stdlib/<name>/externs"
   ```
   Without this, all `= external` functions produce "function not found" at runtime even though the binary compiles cleanly.

2. **`platform/pal/platform.go`** — if the module needs platform operations not already present in the `FS`, `OS`, `IO`, `HTTP`, or `Time` structs, add new function fields here. Only export fields that other packages need; keep internal helpers unexported.

3. **`platform/palnative/`** — implement every new PAL field from step 2 for the native (CLI/OS) build. Place FS methods in `fs.go`, OS methods in `os.go`, etc. If the test PAL will need to share the implementation, export a `NewNative<Category>PAL()` function (e.g. `NewNativeFSPAL()`) so `test_util` can call it.

4. **`test_util/test_util.go` → `TestPal`** — if any PAL fields were added in step 2, wire them into `TestPal`. The safest pattern: start from `palnative.NewNative<Category>PAL()` and override only the test-specific fields (e.g. custom `ReadFile`/`WriteFile`). Failing to update `TestPal` causes nil-pointer dereferences in corpus tests even when the CLI run succeeds, because the test runtime uses a different platform instance.

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

Create or update `stdlib/<name>/bal/README.md` following `.agents/skills/stdlib-readme-format/SKILL.md` exactly. Load that skill now and run its validation checklist before saving the file.

Key decisions for this step:

- **New package** → create from the template in `stdlib-readme-format`; fill in Overview, Key Functionalities, Examples, and the support table.
- **Existing package** → update only the rows whose status changed; then re-run the full validation checklist to catch any pre-existing violations in unchanged rows.
- **Notable Behavioural Changes** — copy every unavoidable divergence from the Step 5 parity table into this section. These must be present *before* the PR is merged. Temporary language gaps (e.g. `distinct`, `readonly &`) belong in the support table only, not here.

After updating the per-library README, update `stdlib/README.md` per the instructions in `stdlib-readme-format`.

## 10. Verify

Work through the checklist below before declaring done. Check each item off as you complete it.

### Code

- [ ] `go run -tags bootstrap ./tools/gen-embedded-libs` — compiles cleanly with the new/updated package and any level changes.
- [ ] `go build ./...` — no compilation errors.
- [ ] `go vet ./...` — no vet warnings.

### Tests

- [ ] `go test ./corpus` — all corpus tests pass.
- [ ] `go run ./cli/cmd run <showcase>.bal` — the showcase file runs and its output matches the `@output` markers exactly.
- [ ] If golden files were regenerated, `git diff corpus/` was reviewed and every changed line is intentional.
- [ ] New corpus test files follow naming conventions (no leading zeros, correct suffix).

### Parity

- [ ] Every row in the Step 5 parity table marked **"Avoidable / Fixed"** has been manually verified: Go output matches jBallerina reference for at least one representative input.
- [ ] Every unavoidable divergence is recorded in `stdlib/<name>/bal/README.md` under **Notable Behavioural Changes**.

### Documentation

- [ ] `stdlib/<name>/bal/README.md` support table reflects the current implementation (no stale "Not Yet Supported" rows for things that were just implemented).
- [ ] `stdlib/README.md` summary table has been updated with the new counts and percentage for this package, and the Total footer row is recalculated.
- [ ] If a new package was added, its Level in `stdlib/README.md` matches the entry in `stdlibLevels` (`tools/gen-embedded-libs/main.go`).
- [ ] If the dependency level of an existing package changed, `stdlibLevels` was updated and the Level column in `stdlib/README.md` reflects the new level.

### Final report

Summarise:
- What was implemented and what was scoped out (with reasons).
- Any new PAL methods or external Go dependencies added.
- The complete parity table from Step 5.

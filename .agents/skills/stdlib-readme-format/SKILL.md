---
name: stdlib-readme-format
description: Authoritative format contract for stdlib/<name>/bal/README.md files. Use when creating or updating any stdlib README, or when auditing an existing one for consistency.
---

# stdlib README Format

This skill defines the exact structure and rules for every `stdlib/<name>/bal/README.md`. It can be invoked standalone to audit or fix an existing README, or embedded in another workflow (e.g. `add-stdlib-support`) when writing a new one.

## Template

Use this skeleton exactly. Do not add, remove, or reorder sections.

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

## Column rules

### Feature/API column

- **Prose only.** No backtick function names, type names, or object names anywhere in this column — not even in parentheses. Wrong: `"File read — string (\`fileReadString\`)"`. Right: `"File read — string"`.
- Function and type names belong in the **Comments / Limitations** column only.

### Support Status column

Exactly one of: `Supported`, `Partially Supported`, `Not Yet Supported`, `Cannot Support`.

### Comments / Limitations column

- **Supported rows with no caveat** — leave this cell empty. Do not write "Fully implemented and tested in the Go version." — that is implied by the status.
- **Supported rows with a caveat** — write only the caveat. Function names, type names, and signatures are allowed here.
- **Partially Supported / Not Yet Supported / Cannot Support** — explain the gap. Include relevant function or type names here.

### Table separator

Always `|---|---|---|`. Never wide-padded column separators.

## Notable Behavioural Changes rules

- **Format**: bullet list with a bold header followed by a period, then a sentence. Example: `- **Title.** jBallerina does X; the Go-native version does Y — reason.`
- **Content**: only permanent, architectural Go-level constraints that cannot be resolved in the externs layer.
- **Do not include**:
  - Temporary language gaps that will be fixed when the interpreter gains the feature (e.g. `distinct` error subtypes, `readonly &` intersections, `stream` type). These belong in the support table as `Not Yet Supported` or `Partially Supported`.
  - Entries that say "identical" or "matching" — if the behaviour is identical, it is not a change.
  - Future potential divergences for features that are `Not Yet Supported` — document those in the Comments column of the relevant table row instead.
- If there are no permanent changes, write the "no changes" sentence from the template rather than omitting the section.

## Validation checklist

Run this checklist against every README before saving. Every item must be YES.

### Support table
- [ ] Every Feature/API cell is prose — no backtick names, no parenthetical function names
- [ ] Every `Supported` row with no meaningful caveat has an empty Comments cell
- [ ] Table separator is `|---|---|---|` on every table
- [ ] Module-level error type (e.g. `foo:Error`) appears as a row in the table with status `Partially Supported` and a comment about `distinct` not yet supported

### Notable Behavioural Changes
- [ ] Section uses bullet list only — not a table, not numbered list
- [ ] Each bullet has format `- **Title.** Explanation.`
- [ ] No bullet describes behaviour that is identical to jBallerina
- [ ] No bullet describes a temporary language gap (`distinct`, `readonly &`, `stream`, etc.)
- [ ] No bullet describes a future feature's potential divergence
- [ ] If no permanent changes exist, the "no changes" sentence is present

### Content accuracy
- [ ] Key Functionalities reflects only currently supported features
- [ ] Examples use only currently supported APIs
- [ ] No `Not Yet Supported` row that was just implemented in this session

## Updating `stdlib/README.md`

After every README change, update the summary table in `stdlib/README.md`:

- Recount `Supported`, `Partially Supported`, and `Not Yet Supported` rows from the updated `bal/README.md`.
- Recompute support %: `round(Supported / Total * 100)` where `Total = Supported + Partially Supported + Not Yet Supported + Cannot Support`.
- Keep rows sorted by Level ascending, then alphabetically within each level.
- Recompute the **Total** footer row.

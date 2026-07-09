# Common libraries examples — support summary

Source: [`ballerina-distribution/examples`](https://github.com/ballerina-platform/ballerina-distribution), `index.json` category `"Common libraries"` (57 samples, 19 sub-headings). Same methodology as the [Language concepts summary](../language-concepts/SUPPORT_SUMMARY.md): each sample was run against this repo's `bal` binary and its stdout/exit code compared against the upstream `.out` transcript.

Currently ported stdlibs (`lib/stdlibs/ballerina/`): `crypto`, `http`, `io`, `log`, `math.vector`, `os`, `random`, `time`, `url`. Most of this category's sub-headings (Avro, Messaging, Cache, EDI, File, Task, UUID, XSLT, `data.xmldata`, `data.yaml`, `data.csv`, Constraint) have **no matching stdlib ported yet**, so they fail immediately on `Unknown import`.

| Result | Count |
|---|---|
| **Added** (exact output match, or clean run for output-unverified examples) | 6 |
| **Not supported** (compile/runtime error or panic) | 51 |
| **Needs review** | 0 |
| **Skipped** | 0 |
| Total | 57 |

## Added (6)

### URL
- [`url-encode-decode`](url-encode-decode/) — URL encode/decode operations

### Log
- [`logging`](logging/) — Logging (unverified output — timestamps vary)
- [`error-logging`](error-logging/) — Error Logging (unverified output — timestamps vary)
- [`logging-configuration`](logging-configuration/) — Configure logging (unverified output — timestamps vary)

### OS
- [`environment-variables`](environment-variables/) — Environment variables (unverified output — depends on the running environment)

### Random
- [`random-numbers`](random-numbers/) — Random numbers (unverified output — inherently random)

## Not supported (51) — grouped by root cause

### 1. No stdlib ported yet (25 — plus 5 more mentioned below from the same sub-headings whose actual first failure is a different bug, cross-referenced accordingly)
`Unknown import` for a package that doesn't exist under `lib/stdlibs/ballerina/` at all:
- `ballerina/avro`: [`avro-serdes`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/avro-serdes)
- `ballerina/messaging`: [`in-memory-message-store`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/in-memory-message-store), [`message-store-listener`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/message-store-listener) (a third example in this sub-heading, [`message-store-type`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/message-store-type), fails earlier on "mapping constructor var-name field not implemented" — the same shorthand-field-syntax gap already flagged for `rest-arguments` in the Language concepts summary)
- `ballerina/cache`: [`cache-basics`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/cache-basics), [`cache-invalidation`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/cache-invalidation)
- `ballerina/file`: [`filepaths`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/filepaths), [`directories`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/directories), [`files`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/files), [`temp-files-directories`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/temp-files-directories)
- `ballerina/task`: [`task-frequency-job-execution`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/task-frequency-job-execution), [`task-one-time-job-execution`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/task-one-time-job-execution), [`manage-scheduled-jobs`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/manage-scheduled-jobs) — these actually panic (`index out of range [-1]`) before reaching a clean import error; see #4 below
- `ballerina/uuid`: [`uuid-generation`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/uuid-generation), [`uuid-operations`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/uuid-operations)
- `ballerina/xslt`: [`xslt-transformation`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/xslt-transformation)
- `ballerina/data.xmldata`: [`xml-to-json-conversion`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/xml-to-json-conversion), [`xml-from-json-conversion`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/xml-from-json-conversion) (2 more in this sub-heading panic instead — see #5)
- `ballerina/data.yaml`: [`yaml-to-anydata-with-projection`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/yaml-to-anydata-with-projection), [`anydata-to-yaml-string`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/anydata-to-yaml-string) (1 more panics instead — see #6)
- `ballerina/data.csv`: [`csv-string-to-record-array`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/csv-string-to-record-array), [`csv-string-to-anydata-array`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/csv-string-to-anydata-array), [`csv-streams-to-record-array`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/csv-streams-to-record-array), [`parse-csv-lists`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/parse-csv-lists), [`transform-csv-records-to-custom-types`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/transform-csv-records-to-custom-types), [`csv-user-configurations`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/csv-user-configurations)
- `$anon/edi_to_record.sorder`, `$anon/record_to_edi.sorder` (local EDI schema modules — `ballerina/edi` itself isn't ported): [`edi-to-record`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/edi-to-record), [`record-to-edi`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/record-to-edi)
- `ballerina/jwt` (Security sub-heading, `crypto` alone is ported but `jwt` isn't): [`security-jwt-issue-validate`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/security-jwt-issue-validate)
- `ballerina/constraint`: [`constraint-validations`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/constraint-validations) — this one actually panics on the regexp parser before the import gap matters; see #7

### 2. `io` — documented gaps (stream/CSV support) (4)
Matches [`lib/stdlibs/ballerina/io`'s README](../../lib/stdlibs/ballerina/io/0.0.1/go1.2/README.md) "Not Yet Supported" rows exactly — `stream` type and CSV file I/O aren't implemented yet:
- [`io-bytes`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/io-bytes) — "Unknown type: Block" (`fileReadBlocksAsStream`)
- [`io-strings`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/io-strings) — "Unknown symbol: fileWriteLinesFromStream"
- [`io-csv`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/io-csv), [`io-csv-datamapping`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/io-csv-datamapping) — "Unknown symbol: fileWriteCsv"

### 3. Shared "raw template" panic — same bug already flagged in Language concepts (4)
`interface conversion: interface is nil, not ast.BLangActionOrExpression` — the same panic signature as `raw-templates`/`array-map-symmetry`/`jsonpath-expressions` in the [Language concepts summary](../language-concepts/SUPPORT_SUMMARY.md). All four here use a backtick string template with an interpolated expression (`` `...${x}...` ``) directly inside `io:println`/log calls:
[`time-utc`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/time-utc), [`time-utc-and-civil`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/time-utc-and-civil), [`time-formatting-and-parsing`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/time-formatting-and-parsing), [`logging-with-context`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/logging-with-context).

### 4. `task` module — panics before the import even resolves (3)
`runtime error: index out of range [-1]` (Go panic, not a Ballerina-level error): [`task-frequency-job-execution`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/task-frequency-job-execution), [`task-one-time-job-execution`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/task-one-time-job-execution), [`manage-scheduled-jobs`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/manage-scheduled-jobs). Since `ballerina/task` isn't ported anyway, this is moot for now, but the negative-index panic (rather than a clean "unknown import" diagnostic) suggests something in import resolution mishandles this particular import path shape — worth a look whenever `task` gets ported.

### 5. XML data conversion — partial (2)
[`xml-to-record-conversion`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/xml-to-record-conversion), [`xml-from-record-conversion`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/xml-from-record-conversion) — `TransformTypeDefinition: metadata not yet supported` (a different desugar gap than the plain "unknown import" ones above; these got further because the record type they convert to/from carries type metadata/annotations the desugar pass doesn't handle yet).

### 6. YAML — ternary panic (1)
[`yaml-to-anydata`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/yaml-to-anydata) — `TransformConditionalExpression unimplemented`, the same ternary-expression gap already tracked in the Language concepts summary (#7 there).

### 7. Regexp — not implemented (1, shared with Language concepts)
[`constraint-validations`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/constraint-validations) — "Regexp parser not implemented" fires before the missing `ballerina/constraint` import matters (the example also uses a regex constraint annotation).

### 8. Log module — partial (6)
`ballerina/log` is ported, but several examples use surface area beyond what's implemented:
- [`log-file-rotation`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/log-file-rotation) — "Unknown symbol: sleep" (`ballerina/lang.runtime:sleep`)
- [`child-loggers-with-context`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/child-loggers-with-context) — "Unknown symbol: Logger" (child-logger objects not implemented)
- [`logger-from-config`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/logger-from-config) — "Unknown symbol: Config"
- [`custom-logger`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/custom-logger) — `TransformConditionalExpression unimplemented` (same ternary gap as #6)
- [`sensitive-data-logging`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/sensitive-data-logging) — "method not found: substring"
- [`directory-listener`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/directory-listener) (File sub-heading, but log-adjacent) — "unexpected node in service attach point" (service-based directory listener, needs a `service`-attachable listener type that isn't wired up)

### 9. Security/crypto — partial (1)
[`security-crypto`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/security-crypto) — "Unknown symbol: fromBytes" (a `crypto` conversion helper not yet implemented, even though the base module is ported).

### 10. Time — partial (1, beyond the shared template panic in #3)
[`time-zone`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/time-zone) — "method not found: toString" on a time-zone-related type.

### 11. `io` file-write directory-creation bug (2)
[`io-json`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/io-json), [`io-xml`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/io-xml) — see "Bugs worth flagging separately" below.

## Bugs worth flagging separately

- **`io:fileWriteJson` / `io:fileWriteXml` don't create missing parent directories.** [`io-json`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/io-json) and [`io-xml`](https://github.com/ballerina-platform/ballerina-distribution/tree/master/examples/io-xml) both fail with `open ./files/jsonFile.json: no such file or directory` — the example writes into a `./files/` subdirectory that doesn't exist yet, and jBallerina evidently creates it on write while this Go implementation doesn't. Both functions are marked plain "Supported" in the `io` README with no caveat about this, so it reads as an unintentional gap rather than a documented limitation.

## No "needs review" or "skipped" cases this round
Every non-passing example in this category failed outright (missing stdlib, unimplemented desugar path, or missing langlib method) — none produced a near-miss output worth a manual diff, and none needed a CLI feature this `bal` binary lacks.

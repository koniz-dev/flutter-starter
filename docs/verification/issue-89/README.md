# Issue 89 verification

`docs: network.md documents ApiClient and AuthInterceptor constructors that do
not exist, and 8a73fd2 added a fourth AuthInterceptor parameter without
updating it`

Change merged as
[`094e489`](https://github.com/koniz-dev/flutter-starter/commit/094e489b310e440e80dbacb97c44a054d594775c)
(PR #158). Every signature was re-derived from the source on `main` rather than
taken from the issue body, which was filed five `lib/core/network/` commits ago.

Run with `--no-goldens`: the change is documentation plus tooling, and a golden
renders text as opaque blocks, so a screenshot could only be miscited here.
**There are no PNGs in this directory** and no criterion rests on one.

## Per-criterion artifacts

| # | Criterion | Artifact | Verdict |
|---|---|---|---|
| 1 | `AuthInterceptor` block matches source parameter for parameter, including `retryDioFactory` and optionality | [`block-inventory.log`](block-inventory.log) ("AuthInterceptor vs ..." - 6 parameters, MATCH) | PASS |
| 2 | `ApiClient` block matches source, including `loggingService` / `performanceService`, and says passing them installs the interceptors | [`block-inventory.log`](block-inventory.log) (6 parameters, MATCH); the "Effect" table in `docs/api/core/network.md` states the install rule | PASS |
| 3 | Both snippets demonstrated to compile from a scratch file under `test/`, analyzer output committed | [`documented-snippets-analyze.log`](documented-snippets-analyze.log) (`No issues found!`, scratch file listed in full) | PASS |
| 4 | `retryDioFactory` annotated `@visibleForTesting` **or** documented as an extension point with the re-entrancy caveat; say which and why | [`visible-for-testing-probe.log`](visible-for-testing-probe.log) - option 2 chosen; the log shows the annotation *would* have worked, so the choice is deliberate | PASS |
| 5 | "On 401 Error" list describes what the code actually does on the failure path | [`block-inventory.log`](block-inventory.log) is signatures only; this one is prose, re-derived line by line from `_handle401Error` and `_drainPendingRequests` - see the diff in `094e489` | PASS |
| 6 | Grep proves no other constructor block disagrees with its source; list every fenced block and its counterpart | [`block-inventory.log`](block-inventory.log) - all 18 fenced blocks classified, 5 constructors + 4 method blocks + the `IGraphQLClient` interface compared, `RESULT: 0 mismatch(es)` | PASS |
| 7 | `./scripts/dev/audit_template.sh` exits 0 | [`format.log`](format.log), [`analyze.log`](analyze.log), [`tests.log`](tests.log) - all three `exit: 0` | PASS |

## The mechanical check, and proof it bites

| File | Shows |
|---|---|
| [`docs-check.log`](docs-check.log) | `dart run tool/check_docs.dart`: 0 broken links, 0 broken anchors, 0 emoji, 0 signature mismatches |
| [`signature-test.log`](signature-test.log) | The same comparison under `flutter test`, so a `lib/` change triggers it |
| [`drift-probe.log`](drift-probe.log) | Both drift directions driven and confirmed **failing**: a renamed parameter in the markdown, and `String? newlyAddedThing` added to the real `ApiClient`. Each exits 1; both files restored afterwards |
| [`pr-158-checks.log`](pr-158-checks.log) | All six PR checks green, including Quality gate and Docs check |

The check also caught a live regression while PR #158 was open: #149 landed
`ISessionTerminationSink? sessionSink` on `AuthInterceptor` mid-review, and the
rebase failed the signature comparison on the now-stale block rather than
letting it merge. That parameter is documented in the merged version.

## What is not covered

- Method signatures (`get`/`post`/`put`/`delete`) are compared in
  `block-inventory.log` but have no standing directive; they are hand-checked.
- Prose is not mechanically tied to code. Criterion 5 is a human reading.
- One-line constructors (`ApiLoggingInterceptor`, `PerformanceInterceptor`)
  cannot carry a directive; the parser reports them missing rather than
  passing silently.

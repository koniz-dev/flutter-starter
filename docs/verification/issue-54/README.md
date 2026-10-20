# Issue 54 - guides describe behaviour the code does not have

Verification evidence for koniz-dev/flutter-starter#54, against the merged fix
on `main` (PR #92, commit `cad5b98`).

## Provenance

The fix merged with CI green, but the session that wrote it was terminated by
an API rate limit before it ran acceptance verification. This evidence was
produced afterwards by the orchestrating session, in a clean detached worktree
at `origin/main` - not in the implementer's tree.

## Criterion to artifact

| # | Criterion | Verdict | Artifact |
|---|---|---|---|
| 1 | Security docs describe SSL pinning as implemented, and say what an adopter must still do | PASS | `docs/guides/security/README.md:41` - "**SSL certificate pinning is implemented**"; `docs/guides/security/audit.md:79` - "implemented but inert until you supply fingerprints" |
| 2 | `getting-started.md` and `CONTRIBUTING.md` state the real floor, cross-checked against pubspec, including a `flutter:` floor | PASS | `docs/guides/onboarding/getting-started.md:9,13,17-18`; `CONTRIBUTING.md:154-155,160-161`. Both state Flutter >=3.38.4 / Dart >=3.10.3 **and** note `pubspec.yaml` declares only `sdk: '^3.8.0'` with no `flutter:` constraint |
| 3 | `test-coverage.md` describes the actual coverage triggers | PASS | `docs/guides/testing/test-coverage.md:95-96,142` says `workflow_dispatch` + weekly Monday 03:00 UTC, matching `.github/workflows/coverage.yml` exactly |
| 4 | The `CONTRIBUTING.md` test example compiles against this project's mocktail + `Result` APIs; paste and run it as proof | PASS | `contributing-example-probe.log` - the first `dart` block extracted **verbatim** into a scratch test file and run: `+2: All tests passed!` |
| 5 | `CONTRIBUTING.md` no longer instructs `git add .`, and says why | PASS | `CONTRIBUTING.md:237-239` - "Do **not** use `git add .`", with the `flutter pub get` churn as the stated reason |
| 6 | `overview.md` diagram points inward; the "pure Dart domain" claim matches the code or the code is changed; state which | PASS | `docs/architecture/overview.md:136` - an explicit "On 'pure Dart'" note stating the rule is *no framework behaviour in the domain layer*. The doc was changed to match the code |
| 7 | Every item in section 7 fixed or explicitly deferred with a reason | PASS | See below |
| 8 | A link/anchor check runs over `docs/`, zero broken relative links and zero broken anchors, wired into CI | PASS | `check_docs.log` - `checked 497 relative link(s) in 73 file(s); 0 broken`; anchors are checked (`tool/check_docs.dart:76-78` parses the `#` fragment). Wired into CI as `.github/workflows/docs-check.yml` -> `dart run tool/check_docs.dart` |
| 9 | `docs/`, `CLAUDE.md`, `.claude/` contain no emoji | PASS | `check_docs.log` - `emoji: scanned 70 file(s); 0 line(s) with emoji` |
| 10 | `./scripts/dev/audit_template.sh` exits 0 | PASS | `audit_template.log` - `AUDIT_EXIT=0`, `+2407 ~5: All tests passed!` |

## Criterion 7, item by item

| Section 7 item | Resolution |
|---|---|
| `scripts/dev/migration/` does not exist, commands given against it | Fixed honestly, not by inventing the directory: `upgrading-this-starter.md:69` now says "No migration scripts ship with this starter today", and the example at `:75` is `ls scripts/dev/migration/ 2>/dev/null \|\| echo "no migration scripts in this version"` |
| `network.md:325` maps errors to a non-existent `UnknownException` | Fixed: `docs/api/core/network.md:325` now maps to `NetworkException` with code `UNKNOWN_NETWORK_ERROR` and states outright "There is no `UnknownException` type" |
| `logging.md:10-11` names `LogFormatter` / `LogProviders`, neither exists | Fixed: those identifiers no longer appear in `docs/api/core/logging.md`. The surviving `JsonLogFormatter` reference in `design-decisions.md:538` is a real class (covered by `test/core/logging/log_output_test.dart`) |
| 5 broken relative links (one `../` too many) | Fixed - 0 broken of 497 checked |
| ~21 broken anchors, incl. the `optimization-guide.md` TOC | Fixed - the checker validates fragments and reports none |
| `getting-started.md:195` resolves to `docs/README.md`, not the root README | Fixed - 0 broken links |
| Emoji on 487 lines across 21 files under `docs/` | Fixed - 0 lines with emoji across 70 files |

## On the PNGs in this directory

`run_acceptance.sh` copies the repository's standing acceptance goldens into
every evidence directory automatically. This is a documentation issue: **no
criterion rests on them**, and none could. `flutter test` renders text with
Ahem, so a screenshot cannot show a single word of the prose these criteria are
about.

The one criterion that needed executable proof is 4, and it was driven by
running the documented example rather than reading it.

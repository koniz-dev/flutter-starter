# Issue 57 - acceptance evidence

Issue: koniz-dev/flutter-starter#57 - `fix(tooling): build_all.sh,
bump_version.sh, setup_ci.dart, create_feature and the commit-msg hook all fail
on the documented path`.

Fix merged as PR #105, squash commit `f22d806` on `main`.

Every criterion below was verified by **running the script**, not by reading
it. Where the script needs a toolchain this machine does not have (Android SDK,
PowerShell) it was run on a GitHub Actions runner through the new
`workflow_dispatch` workflow `.github/workflows/scripts-smoke.yml`, and the run
log is copied in here.

Nothing in this change touches `lib/`, so the golden layer was skipped
deliberately (`run_acceptance.sh 57 --no-goldens`). There are no PNGs in this
directory on purpose: a screenshot of the sample app would prove nothing about
a shell script and could only be miscited.

## Result

| Criterion | Result | Evidence |
|---|---|---|
| 1. `build_all.sh <env>` completes for android and web with no product flavors, no `--flavor`, no `--web-renderer` | PASS | `criterion-1-build-all-production.log`, `criterion-1-build-all-production-outputs.txt`, `criterion-1-build-all-staging.log`, `criterion-1-build-all-staging-outputs.txt` |
| 2. `bump_version.sh patch` works for `1.0.0` and `1.0.0+1`, no-op on failure | PASS | `criterion-2-bump-version.log` |
| 3. commit-msg hook accepts `feat!:`, `feat(auth)!:`, `Revert "..."`, `fixup! ...`; still rejects malformed | PASS | `criterion-3-commit-msg-hook.md` |
| 4. `setup_ci.dart --yes` produces workflows `actionlint` accepts and uncomments only the intended triggers | PASS | `criterion-4-setup-ci.log` |
| 5. `create_feature.sh <name>` output passes `flutter analyze` and `dart format`, and has a mirrored test | PASS | `criteria-5-6-scaffolders.log` sections 1, 2, 7, 8 |
| 6. `mason make feature_clean` output analyzes, formats, compiles and passes; `include_tests: false` writes no empty test | PASS | `criteria-5-6-scaffolders.log` sections 3-6 |
| 7. `create_feature.ps1` is valid PowerShell and matches the `.sh` output | PASS | `criterion-7-create-feature-ps1-windows.log` |
| 8. `./scripts/dev/audit_template.sh` exits 0 | PASS | `criterion-8-audit-template.log` |

`format.log`, `analyze.log` and `tests.log` are the standard
`./scripts/test/run_acceptance.sh 57 --no-goldens` output on the merged tree:
format check exit 0, `flutter analyze` `No issues found!`, 2422 tests passed
with 5 skipped.

## Criterion 1 - `scripts/ci/build_all.sh`

Run on `ubuntu-latest`, which has the Android SDK this machine does not:
Actions -> Scripts smoke -> Run workflow.

- `production` (`flutter build appbundle --release` + `flutter build web
  --release`): run
  [35442370643](https://github.com/koniz-dev/flutter-starter/actions/runs/35442370643),
  job `build_all.sh (production)`, conclusion **success**.
- `staging` (the other branch: `flutter build apk` + non-release web): run
  [35442727655](https://github.com/koniz-dev/flutter-starter/actions/runs/35442727655),
  job `build_all.sh (staging)`, conclusion **success**.

What the logs show, line by line:

- Gradle runs `bundleRelease` / `assembleRelease`, **not**
  `bundleProductionRelease`. That task name was the exact failure in the issue.
- `Built build/app/outputs/bundle/release/app-release.aab (60.3MB)` for
  production, and the APK for staging - see the `*-outputs.txt` listings.
- `Built build/web`, with no "Could not find an option named web-renderer".
  The `build/web/canvaskit/` directory is present anyway, because CanvasKit is
  the default renderer now; that is precisely why the flag was removed
  upstream.
- iOS is skipped on Ubuntu (`Skipping iOS build (not on macOS)`), so the
  criterion's "android and web" is fully covered and the iOS branch is not.
  See "Not covered" below.

## Criterion 2 - `scripts/ci/bump_version.sh`

`criterion-2-bump-version.log` drives the script against a throwaway pubspec,
13 cases, and re-reads the file after each one.

- `1.0.0` + `patch` -> `1.0.1`; `1.0.0+1` + `patch` -> `1.0.1+2`. Both shapes
  work, and a pubspec with no build number does not acquire one by accident.
- `build` and an explicit build-number argument do add one (`1.0.0` + `build`
  -> `1.0.0+1`).
- Four rejected inputs (`1.0`, `1.0.0-beta+1`, an invalid bump type, a
  non-numeric build number) exit 1 **and** leave the file byte-identical -
  the log asserts that explicitly with `pubspec unchanged: YES`.
- No stray temp files are left in the directory.

The `BEFORE` section at the end runs the pre-fix script (`a688cbd`) on
`version: 1.0.0`. Worth reading: it does not abort the way the issue body
describes. On bash 3.2.57 (the macOS system bash) the arithmetic error is
printed, `set -e` does **not** fire on the failed expansion inside an
assignment, and the script goes on to write `version: 1.0.1+1.0.0` and print
"Version bumped successfully!" with exit 0. A silent corruption is worse than
the reported abort, not better.

## Criterion 3 - `.githooks/commit-msg`

`criterion-3-commit-msg-hook.md` has three parts.

1. A 19-row accept/reject table against the fixed hook. The five subjects named
   in the issue are the first five rows, all ACCEPT. Eight malformed subjects
   (`updated some stuff`, `feat:`, `feat: `, `feat(auth)!x`, `Feat(auth): x`,
   `wip! feat: x`, ...) are all still REJECT, so the fix did not just widen the
   pattern into uselessness.
2. The same table against the pre-fix hook, for contrast: 7 MISMATCH rows.
3. **Real `git commit`s** in a throwaway repository with the hook installed at
   `.git/hooks/commit-msg`: a Conventional Commit carrying the repo's
   `Refs koniz-dev/flutter-starter#57` trailer, a scoped breaking change, an
   unscoped breaking change, an actual `git revert`, an actual
   `git commit --fixup`, and a malformed subject that is refused. Exit codes
   and resulting subjects are printed.

This commit and PR #105 itself also went through the hook.

## Criterion 4 - `scripts/dev/setup_ci.dart`

`criterion-4-setup-ci.log` runs the old and the new script against identical
copies of `.github/workflows/` and validates both with `actionlint` 1.7.7.

- Baseline on the untouched workflows: `actionlint` exit 0.
- **BEFORE** (pre-fix script): it rewrote the prose header of
  `deploy-android.yml`, `deploy-ios.yml`, `deploy-web.yml` and `coverage.yml`,
  producing `push:` and `pull_request:` keys at column 0 inside a comment
  block. `actionlint` exit 1 with 10 errors, including
  `unexpected key "push" for "workflow" section` and
  `key "push" is duplicated in workflow`. The real trigger's `tags:` /
  `branches:` children stayed commented, exactly as the issue described.
- **AFTER** (fixed script): only the three deploy workflows change, only inside
  their top-level `on:` block, and the whole `push:` block - key plus children -
  is uncommented with correct indentation. The `# Uncomment to ...` hint is
  dropped from the lines it applied to. `actionlint` exit 0. The full diff of
  every changed file is in the log.
- `--dry-run` leaves every file byte-identical.

The script was not deleted: it can be made safe, and the log shows it is.

## Criteria 5 and 6 - the scaffolders

`criteria-5-6-scaffolders.log`, section by section:

- **0b** baseline `flutter analyze` on the committed tree: `No issues found!`,
  so anything found later is attributable to the scaffold.
- **1-2** `./scripts/dev/create_feature.sh profile` creates 9 files under
  `lib/features/profile/` **and** `test/features/profile/profile_repository_impl_test.dart`.
  `dart format --set-exit-if-changed` exit 0, `flutter analyze` `No issues
  found!`, `flutter test test/features/profile` 2 tests pass.
  (The issue measured 50 analyze issues and no test at all before this.)
- **3-4** `mason make feature_clean` over the same names produces output that
  `diff -r` reports as **identical** to the shell script's.
- **5** the same three gates on the mason output: format 0, analyze clean,
  2 tests pass. The generated test compiles now because the template imports
  `core/utils/result.dart`, which is where `isSuccess` / `dataOrNull` /
  `isFailure` / `errorOrNull` are declared as extensions.
- **6** `--include_tests false` generates 9 files, and
  `test/features/profile` does not exist afterwards - no empty test file, no
  empty directory.
- **7** `user_profile_settings`, a three-word name, passes all three gates too.
  This matters: `dart format` cannot wrap a doc comment, so long class names
  were breaching `lines_longer_than_80_chars` until the templates' doc
  comments were shortened.
- **8** `Bad-Name` is rejected, and a second run over an existing feature
  refuses to overwrite.

## Criterion 7 - `scripts/dev/create_feature.ps1`

Not routed to `needs-uat`: it was actually run, on `windows-latest`.

`criterion-7-create-feature-ps1-windows.log` is the raw job log of
`create_feature.sh == create_feature.ps1 (Windows)` from run
[35442370643](https://github.com/koniz-dev/flutter-starter/actions/runs/35442370643)
(conclusion **success**). It shows, in order:

- `pwsh -File scripts/dev/create_feature.ps1 smoke_feature` runs to completion
  and prints `Feature smoke_feature created`. The pre-fix script died on its
  first statement calling a `Culture` cmdlet that does not exist.
- `diff -r` against the tree produced by `create_feature.sh` in the same job:
  no output, followed by
  `create_feature.ps1 output is identical to create_feature.sh`.
- `dart format --set-exit-if-changed`: `Formatted 10 files (0 changed)`.
- `flutter analyze`: `No issues found!`.
- `flutter test test/features/smoke_feature`: `2 tests passed`.

## Criterion 8 - `audit_template.sh`

`criterion-8-audit-template.log`: format check, `flutter analyze`,
`flutter test`. Exit 0.

## Not covered by this evidence

Stated so nobody reads more into the above than is there.

- **The iOS branch of `build_all.sh`.** Criterion 1 asks for android and web;
  the Ubuntu runner skips iOS, and no macOS runner was used. The `--flavor`
  removal on the `flutter build ios` path is therefore covered only by the
  local build recorded in `criterion-1-ios-branch-local.log`, which runs the
  same command the script runs (`flutter build ios --no-codesign
  --dart-define=...`) rather than the script itself. `flutter build ipa`
  (the production iOS path) needs signing credentials and was not run.
- **`fastlane/Fastfile` still passes `--flavor`** (lines 53 and 79), the same
  defect family as this issue and koniz-dev/flutter-starter#34. Out of scope
  here; already covered by koniz-dev/flutter-starter#62, so no duplicate was
  filed.
- **A flaky test was hit on the way to criterion 8.** The first
  `audit_template.sh` run failed with 14 tests in
  `test/core/logging/log_output_test.dart` reported as `did not complete`. That
  file passes in isolation (79 tests) and the very next full run exits 0, which
  is the run captured in `criterion-8-audit-template.log`. Filed as
  koniz-dev/flutter-starter#109 rather than fixed here: it is `epic:testing`
  and unrelated to any script in this change.
- **`--analyze-size`.** `build_all.sh --analyze-size` was not exercised; the
  criterion does not ask for it and it only reads file sizes after the builds
  that were verified.

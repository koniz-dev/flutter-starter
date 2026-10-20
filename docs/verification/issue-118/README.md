# Acceptance evidence - issue 118

`chore(taxonomy): the epic list has no entry for half of lib/core or any native
surface`

Change merged to `main` as `929dcd3`
([PR 225](https://github.com/koniz-dev/flutter-starter/pull/225)). Evidence
below was produced on `main` after that merge.

## Verdict

| # | Criterion | Verdict | Artifact |
|---|---|---|---|
| 1 | `EPICS` covers every top-level surface; nothing under `lib/core/`, `android/`, `ios/`, `macos/`, `web/` or `fastlane/` left unclaimed | PASS | [`criterion-1-surface-map.txt`](criterion-1-surface-map.txt), [`epic-path-map.txt`](epic-path-map.txt), [`coverage-guard.log`](coverage-guard.log), [`guard-tests.log`](guard-tests.log) |
| 2 | Live labels equal `--list-epics` | PASS | [`criterion-2-labels.txt`](criterion-2-labels.txt) |
| 3 | Near-miss epics on open issues relabelled, or justified | PASS | [`criterion-3-relabels.txt`](criterion-3-relabels.txt) |
| 4 | The list appears in exactly one place | PASS | [`criterion-4-single-source.txt`](criterion-4-single-source.txt) |
| 5 | `./scripts/dev/audit_template.sh` exits 0 | PASS | [`audit_template.log`](audit_template.log), plus [`format.log`](format.log) / [`analyze.log`](analyze.log) / [`tests.log`](tests.log) from the acceptance runner |

No criterion needed a human. Nothing was routed to `status:needs-uat`.

## What each artifact shows

### Criterion 1

[`criterion-1-surface-map.txt`](criterion-1-surface-map.txt) lists 65 surfaces -
every directory under `lib/` (expanded to `lib/core/*`, `lib/features/*`,
`lib/shared/*`), `lib/main.dart`, all seven native folders plus `fastlane/`,
every other tracked top-level directory, and every tracked top-level file -
against the epic claiming it. Each line has exactly one owner and the file ends
`RESULT: every surface above is claimed by exactly one epic.` The owner column
is computed from `./scripts/bootstrap-issue-labels.sh --list-map`, not typed by
hand.

The seven directories the issue and its comments named as uncovered now read:

```
lib/core/utils               epic:core-foundation
lib/core/di                  epic:core-di
lib/core/contracts           epic:core-di
lib/core/errors              epic:core-foundation
lib/core/logging             epic:core-foundation
lib/core/performance         epic:core-foundation
lib/features/feature_flags   epic:feature-flags
```

and the surfaces from the issue body that no epic claimed:

```
lib/core/accessibility       epic:design-system
lib/core/localization        epic:i18n
android ios macos web        epic:platform-release
fastlane                     epic:platform-release
```

[`coverage-guard.log`](coverage-guard.log) is the machine check added by this
change (`dart run tool/check_epic_coverage.dart`) reporting the same thing, and
[`guard-tests.log`](guard-tests.log) is its test suite: 11 cases including four
counterfactuals that drive each failure direction on synthetic input, so a
green run means the checker can actually fail. One case asserts the surface walk
produces more than 30 surfaces and includes every directory named above -
without it, a walk that silently produced nothing would pass everything.

### Criterion 2

[`criterion-2-labels.txt`](criterion-2-labels.txt) shows the live `epic:*`
labels with their descriptions, `--list-epics`, and an empty `diff` between the
two name sets. 17 labels, identical both ways. The live descriptions also match
the script's third-field-free description text, which is the observable proof
that `./scripts/bootstrap-issue-labels.sh` was actually run rather than the
labels being edited by hand.

### Criterion 3

[`criterion-3-relabels.txt`](criterion-3-relabels.txt) shows the current labels
of every issue that was a near-miss, plus the full open-issue list with its
epic:

- **#62** (open, `status:needs-uat`): `epic:tooling-ci` -> `epic:platform-release`.
  Its defects are macOS/iOS entitlements, release signing and fastlane lanes.
- **#207** (open, `status:todo`): `epic:core-config` -> `epic:feature-flags`.
  The file is in `lib/features/feature_flags/`.
- **#180** (open): keeps `epic:feature-tasks`, with the reasoning commented on
  the issue - it edits `lib/core/contracts/`, but only the tasks controller
  contract, used nowhere outside the slice.
- **#63** (closed): unchanged, by the policy this change wrote into
  `docs/issue-workflow.md` - open issues get relabelled, closed ones keep the
  label they shipped under, because no lock, queue or selector reads a closed
  issue's epic.

Neither relabel touched a status label, a priority or an assignee.

### Criterion 4

[`criterion-4-single-source.txt`](criterion-4-single-source.txt) shows
`grep -rn "epic:core-network" docs/ CLAUDE.md .claude/` returning three hits,
all of them prose or example `gh` commands mentioning a single label - no
enumeration. A grep for three of the six new epics across `docs/`, `CLAUDE.md`,
`.claude/`, `README.md` and `CONTRIBUTING.md` returns nothing, and
`EPICS=(` appears in exactly one file: `scripts/bootstrap-issue-labels.sh`.

### Criterion 5

[`audit_template.log`](audit_template.log) - exit 0, `flutter analyze` clean,
`+2791 ~8: All tests passed!`. Trimmed to head and tail with ANSI stripped; the
raw capture was 1.1 MB of per-test application logging.

## No screenshots, deliberately

This issue changes a label taxonomy, a shell script, a Dart checker and three
documents. Nothing renders. The acceptance runner was invoked with
`--no-goldens`, so this directory contains **no PNG** - there is no golden here
to misread, and no criterion rests on one.

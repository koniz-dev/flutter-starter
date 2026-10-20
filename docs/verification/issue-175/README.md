# Verification evidence - issue #175

Guard: `test/tooling/import_rules_test.dart`, merged as `3c341a7` (PR #216).
Verified against `main` @ `22ebb26`, Flutter 3.47.0 stable.

This directory is the acceptance evidence. The implementation was already
merged; this run only verifies it.

## Artifacts

| File | What it is |
|---|---|
| `format.log` | `dart format --set-exit-if-changed` over the tracked dirs |
| `analyze.log` | `flutter analyze` |
| `tests.log` | full `flutter test` suite (2768 passed, 8 skipped) |
| `tooling-tests.log` | `flutter test test/tooling/` on unmodified `main` |
| `allowlist-state.log` | `kAllowedImportViolations` as it stands, plus greps proving each entry is live |
| `counterfactual-4a-entry-deleted.log` | one allowlist line deleted -> guard fails |
| `counterfactual-4b-entry-restored.log` | line restored -> guard passes |
| `counterfactual-5-stale-entry.log` | bogus entry for a clean file -> guard fails |
| `counterfactual-new-violation.log` | four new violations added to `lib/` -> guard fails |
| `audit-template.log` | `./scripts/dev/audit_template.sh` |

No PNGs: this issue is non-visual, so the harness ran with `--no-goldens`.
Nothing here rests on a screenshot.

## The allowlist as it stands on `main`

Four paths across five rules:

| Rule | Path | Status |
|---|---|---|
| `dio_outside_core_network` | `lib/core/errors/dio_exception_mapper.dart` | live, standing exemption |
| `core_imports_feature` | `lib/core/di/providers.dart` | live, standing exemption (#118) |
| `core_imports_feature` | `lib/core/feature_flags/feature_flags_manager.dart` | live, standing exemption (#118) |
| `core_imports_feature` | `lib/core/routing/app_router.dart` | live, standing exemption (#118) |
| `domain_imports_outer_layer` | (empty set) | no violations exist |
| `cross_feature_import` | (empty set) | no violations exist |
| `go_router_outside_routing` | (empty set) | no violations exist |

**There are zero stale entries.** Each of the four paths was re-checked against
the tree by grep, not taken on trust - see `allowlist-state.log`:

- `package:dio` outside `lib/core/network/` appears on exactly one line, in the
  allowlisted `dio_exception_mapper.dart`.
- `package:go_router` outside `lib/core/routing/` appears only in the four
  designated `lib/features/*/routing/*_routes.dart` modules, which the rule
  exempts permanently rather than allowlisting.
- `lib/core/**` importing `lib/features/**` appears in exactly four files: the
  three allowlisted ones plus `lib/core/routing/routes_registry.dart`, the
  registry seam, which is a permanent rule exemption.

### On the two entries the issue body specified that are absent

Issue #175 was written against `094e489` and specified an eight-path allowlist.
The merged guard carries four. That is not drift, and it is not staleness - the
difference is that `main` moved between the issue being written and the guard
landing:

- #176 removed `package:dio` from
  `lib/features/auth/data/datasources/auth_remote_datasource.dart`.
- #177 deleted the `AppNavigator` contract and removed the raw `go_router`
  imports from `login_screen.dart`, `register_screen.dart` and
  `task_detail_screen.dart`.

Those four paths were therefore never seeded, rather than seeded and then
deleted. Seeding them would have made the guard fail on `main` on day one - the
"no stale allowlist entry" test would have caught all four, which is the
mechanism working as designed, not a bug.

The `lib/core/di/` pair called out in the #64 split (`app_router.dart` and
`feature_flags_manager.dart`), plus `providers.dart`, are deliberate standing
exemptions and are not scheduled for a fix: no epic covers `lib/core/di/`, and
#118 tracks the cycle.

## Does a stale exemption rot silently?

No - and this was driven, not assumed. `counterfactual-5-stale-entry.log` shows
a bogus entry for a clean file (`lib/core/errors/failures.dart`, which breaks no
rule) failing the `no stale allowlist entry` test by name:

```
STALE allowlist entr(ies) - 1 found.
kAllowedImportViolations exempts these, but the violation no longer exists in
lib/ (it was fixed, the file moved, or the path is misspelt).
...
  core_imports_feature: lib/core/errors/failures.dart
```

### Recorded limitation

The stale check is skipped for an allowlisted path whose **file no longer
exists**, guarded by `File(path).existsSync()`. This is deliberate and
documented in the guard: `strip-smoke.yml` runs `flutter test` against trees
where `tool/strip_sample_features.dart` has deleted a whole sample feature, so a
missing file there means "stripped", not "fixed".

The narrow hole that follows: an allowlist entry under `lib/features/tasks/`,
`lib/features/feature_flags/` or `lib/core/feature_flags/` would stop being
checked if that file were deleted outright. A separate test - "every allowlist
path exists, unless it is a stripped sample" - catches a missing path anywhere
else, so the hole is confined to the three strippable prefixes and is the price
of keeping strip-smoke green. Not filed as a defect: it is a conscious,
commented trade-off, and no current entry sits under those prefixes.

## Probe sources

No `.dart` file is committed under `docs/verification/` on purpose:
`analysis_options.yaml` does not exclude `docs/`, so a stray Dart file there
breaks the tasks-stripping CI variants (tracked in #187). The probe edits are
recorded here instead. Each was reverted with `git checkout --` and the tree
confirmed clean before committing.

**Criterion 4** - delete exactly one allowlist line, touching no source file:

```diff
   'core_imports_feature': <String>{
-    'lib/core/di/providers.dart',
     'lib/core/feature_flags/feature_flags_manager.dart',
     'lib/core/routing/app_router.dart',
```

**Criterion 5** - add one bogus entry naming a file that breaks no rule:

```diff
   'core_imports_feature': <String>{
+    'lib/core/errors/failures.dart',
     'lib/core/di/providers.dart',
```

**New violations** - four imports added to `lib/`, allowlist untouched. The
first three ran together, the fourth on its own:

```dart
// lib/features/auth/data/datasources/auth_remote_datasource.dart:1
import 'package:dio/dio.dart';

// lib/features/tasks/domain/usecases/get_all_tasks_usecase.dart:1
import 'package:flutter_starter/features/tasks/data/models/task_model.dart';

// lib/features/tasks/presentation/screens/tasks_list_screen.dart:1
import 'package:flutter_starter/features/auth/domain/entities/user.dart';

// lib/features/tasks/presentation/screens/task_detail_screen.dart:1
import 'package:go_router/go_router.dart';
```

All four were caught, each by the correct rule. Between them they exercise
**all five rules** against real files - the four above plus
`core_imports_feature`, which criterion 4's probe fired. No rule is verified by
its unit test alone.

## Criterion-by-criterion

| # | Criterion | Verdict | Artifact |
|---|---|---|---|
| 1 | Test parses every import in `lib/**` and enforces all five rules, each consulting the allowlist | PASS | `counterfactual-new-violation.log` (4 rules fired on real files) + `counterfactual-4a-entry-deleted.log` (5th rule, `core_imports_feature`) |
| 2 | `flutter test test/tooling/` exits 0 on unmodified `main`; allowlist holds exactly the specified paths | PASS with documented deviation | `tooling-tests.log` (54 tests, exit 0); `allowlist-state.log` - four paths, not eight, because #176 and #177 landed first. See above. |
| 3 | Allowlist is a single named constant, one entry per file path, so a fix deletes exactly one line | PASS | `allowlist-state.log` (`kAllowedImportViolations`, one path per line); `counterfactual-4a-entry-deleted.log` proves a one-line deletion is the whole edit |
| 4 | Delete an allowlist entry -> fails naming file and rule; restore -> passes | PASS | `counterfactual-4a-entry-deleted.log` (exit 1, names `lib/core/di/providers.dart:11` and `core_imports_feature`) and `counterfactual-4b-entry-restored.log` (exit 0) |
| 5 | A stale entry also fails | PASS | `counterfactual-5-stale-entry.log` (exit 1, names `core_imports_feature: lib/core/errors/failures.dart`) |
| 6 | Failure message names the offending file and the rule, not a bare count | PASS | `counterfactual-new-violation.log` - each entry prints path, line, imported URI, rule id, `banned`, and `allowed` |
| 7 | `./scripts/dev/audit_template.sh` exits 0 | PASS | `audit-template.log` |

Criterion 2 is the only one not met literally. The guard cannot carry the eight
paths the issue specified, because four of those violations no longer exist and
its own stale-entry test would reject them. The intent behind the criterion -
the guard lands green on `main` with an allowlist matching reality - holds.

Nothing here was routed to `status:needs-uat`: every criterion is tier 1 and was
driven directly.

# Verification evidence - issue #183

docs: no ADR records which core contracts are load-bearing, so three of eight
have sat dead without anyone deciding

Shipped in PR #254, squash-merged to `main` as `c4a724d`. Verified against that
commit.

## Artifacts

| File | What it is |
|---|---|
| `criteria.log` | Every grep the criteria specify, run against the merged tree: the nine per-symbol consumer greps, the per-axis slice measurement, `ApiClient`'s public verb signatures, the ADR index, the contracts-map alignment, and `git diff --name-only` for the shipping commit |
| `format.log` | `dart format --set-exit-if-changed lib test integration_test tool examples`, exit 0 |
| `analyze.log` | `flutter analyze`, "No issues found!", exit 0 |
| `tests.log` | `flutter test --timeout=5m`, `+2812 ~8`, exit 0 |

No PNGs: documentation-only change, so `run_acceptance.sh` ran with
`--no-goldens` and copied none. **No criterion rests on a golden.**

## Criteria

| Criterion | Result | Evidence |
|---|---|---|
| 1. a new ADR names all the contracts and records "load-bearing" with a named production consumer or "removed" with the issue/commit that removed it; "declared with no consumer" is not an allowed verdict | **PASS with documented deviation** (see below) | `docs/architecture/adr/0006-contract-status-and-slice-shape.md`, "Decision 1": five load-bearing rows with named consumers, two removed rows citing #177 and #180, and a decided verdict for each of the remaining two |
| 2. every consumer path the ADR cites resolves under `grep -rn "<symbol>" lib` | PASS | `criteria.log`, first block: all nine greps. Each file:line the ADR names appears; `AppNavigator` and `ITasksController` return "(no output)" as the ADR asserts |
| 3. the ADR states which slice shape is canonical and, per axis, what the others must do or why they differ | PASS | ADR "Decision 2", two tables. Measured shape in `criteria.log`: `auth di=yes usecases=6 models=yes routing=yes`, `tasks` identical, `feature_flags di=no usecases=0 models=no routing=yes` |
| 4. the ADR records what happened to `ApiClient`'s Dio surface and to `AppNavigator`, naming the issue for each | PASS | ADR "Decision 3". Backed by `criteria.log`: `api_client.dart` has `Dio get dio` at `:151` and `Future<NetworkResponse<dynamic>>` on all four verbs plus `_send`, with no `@Deprecated` and no `_sendWithCompatibility`; `grep -rn "AppNavigator" lib` is empty |
| 5. `adr/README.md` indexes the new ADR and `contracts-map.md` does not contradict it | PASS | `criteria.log`: README lines 15-19 index 0006 and mark 0005 superseded; `contracts-map.md:31-32` now reads "That is no longer an open question" and links 0006; `0005-state-boundary.md:4,8,9,43` all defer to 0006 |
| 6. `git diff --name-only origin/main` lists only paths under `docs/` | PASS | `criteria.log`, last block: four paths, all `docs/architecture/...` |

## Criterion 1 - the deviation, stated plainly

Criterion 1 allows exactly two verdicts per row. Criterion 6 forbids this change
from touching anything outside `docs/`. For two contracts - `AppDesignTokens`
and `IAuthController` - neither allowed verdict is *true today*, and making
either one true requires editing `lib/`. The two criteria cannot both hold in a
single change for those rows.

The ADR resolves this by recording the **decision**, which is what an ADR is
for, and naming the epic and the exact edit so the execution is mechanical:

- **`IAuthController` -> remove**, with `AuthStateSnapshot`,
  `ControllerStateSnapshot`, `authControllerProvider`
  (`auth_provider.dart:289`) and the `implements` clause (`:48`). Under
  `epic:feature-auth`, following #180's precedent of deleting a contract from
  `lib/core/contracts/` under the feature epic rather than splitting a
  four-line deletion across two.
- **`AppDesignTokens` -> wire**, by typing `AppTheme._tokens`
  (`lib/shared/theme/app_theme.dart:7`) on the abstraction. Under
  `epic:design-system`.

What criterion 1 actually forbids - leaving a contract in the indefinite
"declared, implemented, nobody decided" state - does not survive this ADR. Both
rows now have a verdict, a rationale, an epic and a diff. Neither follow-up is
filed as an issue; the ADR's "Follow-up work this ADR creates" table is the
record, together with a third item (teaching `bricks/feature_clean` the
`routing/` directory) that #183's own body flagged as a separate child.

## Two premises in the issue that current `main` has overtaken

- The issue's table says tasks has **no** `routing/`. It has one -
  `lib/features/tasks/routing/tasks_routes.dart` - and so does every slice.
  `criteria.log` measures it. The ADR records the tree as it is and says so.
- The issue's title says "three of eight". Counting `IKeyValueStore` and
  `ITokenStore` separately, as the ADR does (different implementations,
  different consumer sets, and a verdict is per contract), there are **nine**
  contracts across the life of #64: five live, two already removed, two with a
  verdict pending execution.

## Why the ADR supersedes 0005 rather than amending it

Both contracts ADR 0005 proposed are gone or going: `ITasksController` was
deleted by #180, and 0006 decides to remove `IAuthController`. Amending 0005 in
place would leave a Decision section arguing for something the repository has
chosen not to do - which is exactly how 0005 came to carry an "Implementation
status" section contradicting its own Decision. Superseding keeps 0005 readable
as the reasoning that was tried, and 0006 as what holds. 0005's **Context** is
explicitly retained as still accurate; only the conclusion drawn from it
changed.

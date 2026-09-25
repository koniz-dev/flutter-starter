# Acceptance evidence - issue #178

`chore(shared): context_extensions ships a second, Navigator-based navigation
API with no production caller`

Shipped in PR #204, squash-merged to `main` as `134038d`. All logs in this
directory were produced by running against merged `main` at `134038d`, not
against the feature branch.

## What changed

`navigateTo`, `navigateToReplacement` and `pop` were removed from
`lib/shared/extensions/context_extensions.dart`. Acceptance criterion 1 offered
two routes - remove them, or document them - and the removal route was taken,
so criteria 2 and 4 are read in their "if the members were removed" form.

## Criterion map

| # | Criterion | Result | Artifact |
|---|---|---|---|
| 1 | The three members removed, or documented | PASS (removed) | [`criterion-1-2-members-removed.log`](criterion-1-2-members-removed.log) |
| 2 | `grep -n "MaterialPageRoute" lib/shared/extensions/context_extensions.dart` returns nothing | PASS | [`criterion-1-2-members-removed.log`](criterion-1-2-members-removed.log) |
| 3 | `flutter test` on the extension's test exits 0; count recorded before and after | PASS, 15 -> 14 | [`criterion-3-test-count.log`](criterion-3-test-count.log) |
| 4 | Name collision settled observably | PASS | [`criterion-4-collision.log`](criterion-4-collision.log) |
| 5 | Only `context_extensions.dart` changed under `lib/` | PASS | [`criterion-5-lib-scope.log`](criterion-5-lib-scope.log) |
| 6 | `./scripts/dev/audit_template.sh` exits 0 | PASS | [`criterion-6-audit_template.log`](criterion-6-audit_template.log) |

Supporting, not tied to a numbered criterion:

- [`criterion-deadness-grep.log`](criterion-deadness-grep.log) - the proof that
  each of the three members was genuinely unused before deletion, across `lib`,
  `test`, `examples`, `integration_test`, `tool` (all three `tool/golden/`
  trees), `bricks`, `docs`, `scripts` and `.github`.
- [`docs-check.log`](docs-check.log) - `dart run tool/check_docs.dart`, which
  gates links, anchors, emoji and documented constructor signatures.
- [`format.log`](format.log), [`analyze.log`](analyze.log),
  [`tests.log`](tests.log) - produced by
  `./scripts/test/run_acceptance.sh 178 --no-goldens`.

## No screenshots, deliberately

There are **no PNGs in this directory**. The acceptance harness was run with
`--no-goldens` because this change renders nothing: it deletes three methods
from an extension that no widget in `lib/` imports, and adds one non-visual
widget test. No criterion here rests on a golden, and none could - a golden
proves position, size, colour and presence, and every criterion on #178 is
about which symbols exist and which code compiles.

Because no golden ran, the usual `goldens-checksums.txt` is absent rather than
empty: the standing goldens under `test/acceptance/goldens/` were never copied
in and were never touched.

## The collision probe

Criterion 4 turns on an analyzer error that existed before the change. A
throwaway probe was written at `4a5f8f2` (the parent of the fix), analyzed, and
deleted. It is **not** committed as a `.dart` file: `analysis_options.yaml` does
not exclude `docs/`, so a `.dart` file here would be analyzed by the
tasks-stripping CI variants and fail them - see
koniz-dev/flutter-starter#187. Its source, for anyone reproducing the result:

```dart
// test/shared/extensions/collision_probe_test.dart  (throwaway, not committed)
import 'package:flutter/material.dart';
import 'package:flutter_starter/shared/extensions/context_extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('context.pop() with both imports', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Pop'),
            );
          },
        ),
      ),
    );
  });
}
```

To reproduce: check out `4a5f8f2`, write that file, and run
`flutter analyze test/shared/extensions/collision_probe_test.dart`. The output
is transcribed verbatim in
[`criterion-4-collision.log`](criterion-4-collision.log).

At `134038d` the probe is unnecessary, because
`test/shared/extensions/context_extensions_test.dart` now carries both imports
permanently and calls `context.pop()` itself. That makes the collision a
compile-time regression guard rather than a one-off observation.

## Relationship to #177

#177 (`epic:core-routing`, in flight) is deciding whether the repository has one
navigation style and whether `AppNavigator` is kept-and-wired or deleted. This
change does **not** presuppose either answer:

- No `package:go_router` import was added anywhere under `lib/`, so #177's
  criterion 1 (`grep -rn "package:go_router" lib | grep -v "^lib/core/routing/"`
  returns only the four feature route files) is unaffected.
- The one new `go_router` call site is a test, not a screen, so #177's
  criterion 2 (no screen calls `context.go` / `context.pop` directly) is
  unaffected.
- The replacement doc comment on `ContextExtensions` names `lib/core/routing/`
  as the home of navigation without committing to `NavigationExtensions` over
  `AppNavigator`.

One residual coupling, stated rather than hidden: the three `docs/` snippets
updated here now show `context.goToHome()`, `context.pushRoute(...)` and
`context.popRoute()`, which are `NavigationExtensions` members. If #177 lands on
`AppNavigator` and retires that extension, those three snippets need the same
rewrite as the rest of the navigation docs, and #177's criterion 4 already puts
that documentation follow-through in its own scope.

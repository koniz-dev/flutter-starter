# Tool (Dart)

Maintenance utilities run with `dart run` from the **repository root**.

## `check_docs.dart`

Documentation integrity checker. Three checks, all of which had silently rotted:

- **Links and anchors** under `docs/`: every relative path resolves, and every
  `#fragment` matches a heading slug in the target file (GitHub's slug rules,
  including duplicate `-1` suffixes).
- **Emoji** in `docs/`, `CLAUDE.md` and `.claude/`, per the convention stated in
  `CLAUDE.md`. `README.md` and `CONTRIBUTING.md` are exempt (they predate it), and
  so is `docs/verification/`, whose files quote captured tool output verbatim.
- **Constructor signatures** (`doc_signatures.dart`): any fenced block preceded
  by `<!-- signature: <source path> <ConstructorName> -->` must list exactly the
  named parameters that constructor declares, in order, with the same types,
  `required` markers and defaults. Added after koniz-dev/flutter-starter#89,
  where `docs/api/core/network.md` documented an `AuthInterceptor` parameter
  that never existed while missing three that did.
- **Symbol existence** (`doc_symbols.dart`): every
  `<!-- symbol: <source path> <identifier> -->` directive must name an
  identifier that file actually declares. Added after
  koniz-dev/flutter-starter#206, where `docs/architecture/contracts-map.md` -
  the document an adopter follows to swap an implementation - cited
  `tasksControllerProvider` and `FirebaseFeatureFlagsRemoteDataSource`, neither
  of which has ever existed anywhere in the repository.

```bash
dart run tool/check_docs.dart               # all checks
dart run tool/check_docs.dart --links       # links and anchors only
dart run tool/check_docs.dart --emoji       # emoji only
dart run tool/check_docs.dart --signatures  # constructor signatures only
dart run tool/check_docs.dart --symbols     # symbol existence only
```

Exits 1 and prints `file:line` for every problem. CI runs it as **Docs check**
(`.github/workflows/docs-check.yml`) on any PR touching markdown - exactly the
set of changes the Quality gate treats as inert and skips. The signature and
symbol checks additionally run under `flutter test`
(`test/docs/doc_signatures_test.dart`, `test/docs/doc_symbols_test.dart`),
because a constructor gaining a parameter, or an identifier being deleted from
`lib/`, is a `lib/` change that Docs check never sees. It is deliberately
**not** part of `scripts/dev/audit_template.sh`: that script gates code changes,
and a broken doc link should not block an unrelated `lib/` fix.

### The `symbol:` directive

```markdown
<!-- symbol: lib/core/di/providers.dart apiClientProvider -->
```

One directive per asserted identifier. It takes no fenced block and says
nothing about the shape of the declaration - only that the name is declared in
that file. Accepted forms: `class` in every modifier spelling, `mixin`, `enum`,
`extension`, `extension type`, `typedef`, a top-level
`final`/`const`/`late`/`var`, and a top-level function.

Two properties worth knowing:

- **Generated output counts.** `goRouterProvider`, `authProvider` and
  `featureFlagsRemoteDataSourceProvider` exist only in a `.g.dart`, so a
  checker that skipped generated files would skip the identifiers an adopter is
  most likely to get wrong. Name the `.g.dart` path.
- **Inline code spans are not scanned, deliberately.** The swap map's cells mix
  identifiers, paths and prose; a heuristic would either miss the phantom or
  drown the author in false positives. The directive is verbose and exact,
  which is the right trade for a document whose whole job is being exact.

Directives inside a fenced block are ignored, so this section does not check
itself. `docs/verification/` is skipped too: an evidence file is a frozen
record of a past run, and a directive in one would start failing the day the
code it described changed.

`strip_sample_features.dart` deletes any directive naming a path it removed,
so a stripped tree does not fail `test/docs/doc_symbols_test.dart` over a
feature that is no longer there.

## `check_epic_coverage.dart`

Taxonomy guard: every tracked surface maps to **exactly one** `epic:*` label.

The mapping is not duplicated here or in the tool. `scripts/bootstrap-issue-labels.sh`
is the single source of truth for the epic list *and* for the paths each epic
claims; the tool reads it with `--list-map` and compares it against the tracked
tree. Three fatal directions: a surface no epic claims, a surface two epics
claim, and a claimed path that is not in the tree.

```bash
dart run tool/check_epic_coverage.dart
./scripts/bootstrap-issue-labels.sh --list-map   # the mapping it checks against
```

Runs under `flutter test` via `test/tooling/epic_coverage_test.dart`, alongside
counterfactual tests that prove the checker can fail. Added by
koniz-dev/flutter-starter#118, where half of `lib/core/` and every native
surface had no epic - which is not cosmetic, because the "never two implementers
in the same `epic:*`" rule keys on that label.

It reads paths from version control rather than from the filesystem, so
`strip_sample_features.dart` deleting the sample slices does not make the
sample epics look stale under **Strip smoke**.

## `strip_sample_features.dart`

Removes sample **`tasks`** and **`feature_flags`** modules (and related tests), deletes `lib/core/feature_flags/feature_flags_manager.dart` when present, and **copies rewired sources from `tool/golden/stripped/`** (mirrors `lib/`, `test/`, `integration_test/`). Keeps **auth** and core infrastructure.

Guards: after file operations the script scans `lib/`, `test/`, `integration_test/`, and `examples/` for leftover imports of the removed modules and exits with code **3** if any remain.

```bash
dart run tool/strip_sample_features.dart --apply
flutter pub get
flutter analyze
flutter test
```

### Golden tree

Edit **`tool/golden/stripped/`** when the stripped baseline should change (e.g. new `AppRoutes`, `main` bootstrap). Mirrored paths include `lib/`, `test/core/routing/` (`app_router_test.dart`, `app_routes_test.dart`), and `integration_test/`. The tree is **excluded from** `flutter analyze` via `analysis_options.yaml` so it does not conflict with the real `lib/`.

CI runs **Strip smoke** (`.github/workflows/strip-smoke.yml`): apply strip on a fresh checkout, then `flutter analyze` and `flutter test`.

See also [Fork and customize](../docs/guides/onboarding/fork-and-customize.md), [Contracts map](../docs/architecture/contracts-map.md) (stripped vs full starter), and the Mason brick under [`bricks/`](../bricks/).

## After stripping

- **Patrol:** Golden `integration_test/` targets **auth → home** (`#e2e_home_content` on `HomeScreen`). Run `patrol test --target integration_test/app_e2e_test.dart` after strip.
- Re-run **`flutter analyze`** and **`flutter test`**; the script’s guard should catch most stale imports.

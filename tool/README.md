# Tool (Dart)

Maintenance utilities run with `dart run` from the **repository root**.

## `check_docs.dart`

Documentation integrity checker. Seven checks, all of which had silently rotted:

- **Links and anchors** in `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md` and
  the markdown under `docs/`, `test/`, `scripts/`, `tool/`, `bricks/`,
  `examples/`, `integration_test/` and `fastlane/`: every relative path
  resolves inside the repository, and every
  `#fragment` matches a heading slug in the target file (GitHub's slug rules,
  including duplicate `-1` suffixes).
- **Emoji** in `docs/`, `CLAUDE.md` and `.claude/`, per the convention stated in
  `CLAUDE.md`. `README.md` and `CONTRIBUTING.md` are exempt (they predate it).
- **Constructor signatures** (`doc_signatures.dart`): any fenced block preceded
  by `<!-- signature: <source path> <ConstructorName> -->` must list exactly the
  parameters that constructor declares - positional, `[optional]` and
  `{named}`, on one line or many - in order, with the same types, `required`
  markers and defaults. A super- or field-formal (`super.code`) is compared by
  kind, name, `required` and default only, since docs write the reader-facing
  type. Added after `docs/api/core/network.md` documented an `AuthInterceptor` parameter
  that never existed while missing three that did.
- **Symbol existence** (`doc_symbols.dart`): every
  `<!-- symbol: <source path> <identifier> -->` directive must name an
  identifier that file actually declares. Added after
  `docs/architecture/contracts-map.md` -
  the document an adopter follows to swap an implementation - cited
  `tasksControllerProvider` and `FirebaseFeatureFlagsRemoteDataSource`, neither
  of which has ever existed anywhere in the repository.
- **`.env` setup runs** (`doc_env_runs.dart`): in `README.md`,
  `CONTRIBUTING.md` and `docs/`, the first `flutter run` or `flutter build`
  after a `cp .env.example .env` line must pass `--dart-define-from-file`
  (or explicit `--dart-define=` flags). `.env` is not an asset, so a plain run
  ignores the file it just told the reader to fill in. Added after README's
  Quick Start and CONTRIBUTING did exactly that.
- **`--dart-define` keys** (`doc_dart_defines.dart`): every
  `--dart-define=<KEY>=` in a fenced block of `README.md` or `docs/` names a
  key of `DartDefines.values` (`lib/core/config/dart_defines.dart`), the only
  table a define reaches the app through. Added after the security guide
  built production with a key nothing read.
- **`flutter test` paths** (`doc_test_paths.dart`): every path argument of
  `flutter test` in a fenced block of `README.md`, `CONTRIBUTING.md` or `docs/`
  exists, after joining continued lines and skipping flags, `:line` suffixes and
  placeholders (`<...>`, `path/to`). Added after CONTRIBUTING named a test
  file that did not exist.

```bash
dart run tool/check_docs.dart               # all checks
dart run tool/check_docs.dart --links       # links and anchors only
dart run tool/check_docs.dart --emoji       # emoji only
dart run tool/check_docs.dart --signatures  # constructor signatures only
dart run tool/check_docs.dart --symbols     # symbol existence only
dart run tool/check_docs.dart --env-runs    # .env setup runs only
dart run tool/check_docs.dart --dart-defines  # --dart-define keys only
dart run tool/check_docs.dart --test-paths  # flutter test paths only
```

Exits 1 and prints `file:line` for every problem. CI runs it as **Docs check**
(`.github/workflows/docs-check.yml`) on any PR touching markdown - exactly the
set of changes the Quality gate treats as inert and skips. The signature and
symbol checks additionally run under `flutter test`
(`test/docs/doc_signatures_test.dart`, `test/docs/doc_symbols_test.dart`), as
does the `.env` rule (`test/docs/doc_env_runs_test.dart`, with fixtures),
because a constructor gaining a parameter, or an identifier being deleted from
`lib/`, is a `lib/` change that Docs check never sees. It is deliberately
**not** part of `scripts/dev/audit_template.sh`: that script gates code changes,
and a broken doc link should not block an unrelated `lib/` fix.

### The `symbol:` directive

```markdown
<!-- symbol: lib/core/di/providers.dart apiClientProvider -->
<!-- symbol: lib/core/network/api_client.dart ApiClient.responseCache -->
```

One directive per asserted identifier: a top-level name, or `Type.member` for a
member. It takes no fenced block and says
nothing about the shape of the declaration - only that the name is declared in
that file. Accepted forms: `class` in every modifier spelling, `mixin`, `enum`,
`extension`, `extension type`, `typedef`, a top-level
`final`/`const`/`late`/`var`, and a top-level function. For `Type.member`: a
named or factory constructor, method, getter, setter or field written directly
in that type's body - not an inherited member, and not a call inside a method
body.

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
itself.

<!-- strip:strip-tool start -->
`strip_sample_features.dart` deletes any directive naming a path it removed,
so a stripped tree does not fail `test/docs/doc_symbols_test.dart` over a
feature that is no longer there.
<!-- strip:strip-tool end -->

<!-- strip:strip-tool start -->
## `check_action_pins.dart`

Fails when a workflow under `.github/workflows/`, a composite action
(`action.yml` / `action.yaml`) anywhere under `.github/`, or a local action a
workflow reaches through `uses: ./<path>` (wherever it lives) runs an action
that is not pinned to a full commit SHA followed by its release as a comment
(`uses: owner/repo@<40-hex sha> # vX.Y.Z`). Local `./` actions and
`docker://...@sha256:` images are exempt. File names are matched case-insensitively (`Release.YML`,
`Action.yml`), since a case-insensitive runner file system loads them. It parses the YAML, so a `uses` key
written in a flow mapping, quoted, or as `uses :` is checked like any other.

```bash
dart run tool/check_action_pins.dart
```

Exits 1 and prints `file:line: uses: <target>` for every unpinned action, and
for every `uses: ./<path>` that has no `action.yml` / `action.yaml`.
`test/tooling/workflow_action_pins_test.dart` runs it under `flutter test`, so
the Quality gate enforces it.

## `strip_sample_features.dart`

Removes sample **`tasks`** and **`feature_flags`** modules (and related tests) and **copies rewired sources from `tool/golden/stripped/`** (mirrors `lib/`, `test/`, `integration_test/`). Keeps **auth** and core infrastructure.

Guards: after file operations the script scans `lib/`, `test/`, `integration_test/`, and `examples/` for leftover imports of the removed modules and exits with code **3** if any remain.

```bash
dart run tool/strip_sample_features.dart --apply
flutter pub get
flutter analyze
flutter test
```

`--keep-samples` removes neither sample. On its own it does nothing; with
`--remove-bricks` it is how a fork that keeps `tasks` and `feature_flags` drops
the Mason bricks. It cannot be combined
with `--remove-tasks` or `--remove-feature-flags`.

`--remove-bricks` can be added to any mode. It deletes `bricks/` and
`mason.yaml` and drops the `strip:bricks` passages that link into them, so the
links that are left still resolve. Deleting the
two by hand leaves those links dangling, and `check_docs --links` fails.

### Markers

Prose in a file the strip keeps that documents something the strip removes is
marked in place rather than listed in the script, so the two cannot drift.
Unbalanced markers are a hard error, reported before anything is deleted.

Prose about the feature-flags sample sits between `<!-- strip:feature-flags start -->` and
`<!-- strip:feature-flags end -->`, and the tasks sample uses
`strip:tasks`. Each block goes only when its sample does. For a single line,
such as a table row where a marker line would end the table, put
`<!-- strip:<tag> line -->` anywhere on the line.
`test/tooling/strip_sample_prose_test.dart` fails if a kept markdown file
names a sample's symbol outside such a marker, in the full tree and in every
strip variant.

Prose about the Mason bricks uses `strip:bricks` and goes with
`--remove-bricks`.

### Golden tree

Edit **`tool/golden/stripped/`** when the stripped baseline should change (e.g. new `AppRoutes`, `main` bootstrap). Mirrored paths include `lib/`, `test/core/routing/` (`app_router_test.dart`, `app_routes_test.dart`), and `integration_test/`. The tree is **excluded from** `flutter analyze` via `analysis_options.yaml` so it does not conflict with the real `lib/`.

CI runs **Strip smoke** (`.github/workflows/strip-smoke.yml`): apply strip on a fresh checkout, then `flutter analyze` and `flutter test`. It runs on its own only in the template repository; in a repository created from the template, run it from the Actions tab when you change the strip tool or its goldens.
<!-- strip:strip-tool end -->

See also [Fork and customize](../docs/guides/onboarding/fork-and-customize.md) and [Contracts map](../docs/architecture/contracts-map.md) (stripped vs full starter).
The Mason brick is under [`bricks/`](../bricks/). <!-- strip:bricks line -->

<!-- strip:strip-tool start -->
## After stripping

- **Patrol:** Golden `integration_test/` targets **auth → home** (`#e2e_home_content` on `HomeScreen`). Run `patrol test --target integration_test/app_e2e_test.dart` after strip.
- Re-run **`flutter analyze`** and **`flutter test`**; the script’s guard should catch most stale imports.
<!-- strip:strip-tool end -->

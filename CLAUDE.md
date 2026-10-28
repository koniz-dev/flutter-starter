# CLAUDE.md

Guidance for Claude Code sessions working in this project.

Flutter app built on Clean Architecture: single root `pubspec.yaml`, sources in
`lib/`, tests mirroring them in `test/`, end-to-end flows in `integration_test/`.

## Commands

```bash
flutter pub get
./scripts/dev/audit_template.sh        # codegen + format + analyze + test (CI adds: random order, coverage floor, clean tree)
flutter test --timeout=5m              # unit + widget (goldens skipped by default)
flutter analyze
dart format lib test integration_test tool examples
flutter test --run-skipped --tags golden test/acceptance   # acceptance goldens (tier 2)
```

`flutter pub get` on the current stable leaves the tree clean: the migrations
it used to apply (analyzer excludes, the Pods includes in four `*.xcconfig`
files, the SDK-pinned lock entries) are committed. If it does dirty a tracked file, a new stable re-pinned or re-migrated
something; the Quality gate's "Tracked files are unchanged" step fails on it
too. Fix that on `main` in its own change - re-run `flutter pub get` and commit
the result - rather than reverting it or sweeping it into an unrelated PR.
Always stage explicitly rather than with `git add .`.

Code generation (Freezed, json_serializable, Riverpod) is committed. Regenerate
with `flutter pub run build_runner build --delete-conflicting-outputs` only when
you touch an annotated source.

## Testing

Three tiers:

- **Tier 1 - `flutter test`.** Unit and widget tests on the host VM. Widget
  tests pump real screens via [`test/helpers/pump_app.dart`](test/helpers/pump_app.dart)
  and assert against [`lib/core/constants/ui_keys.dart`](lib/core/constants/ui_keys.dart).
  This is the workhorse.
- **Tier 2 - acceptance goldens.** Tests under `test/acceptance/` tagged
  `golden`, using [`test/acceptance/acceptance_helpers.dart`](test/acceptance/acceptance_helpers.dart).
  [`dart_test.yaml`](dart_test.yaml) skips the `golden` tag by default, so CI,
  `.githooks/pre-push`, and plain `flutter test` ignore them; run them with
  `flutter test --run-skipped --tags golden test/acceptance`. Goldens are a
  record of what screens look like, **not a CI gate** - a golden regression
  will not fail CI, by design.
- **Tier 3 - not drivable on a host.** Real devices, store builds and anything
  needing a live backend; see below.

### What this tooling cannot verify

Be honest about these. Claiming any of them is verified is the fastest way to
make verification worthless.

- **Text content in a golden.** `flutter test` renders text with the Ahem font,
  so **every glyph is an opaque black block**. A golden proves presence,
  position, size, colour, and overflow. It cannot show wording or icon glyphs -
  assert those with `find.text()` / `find.byIcon()`. Never write "the screenshot
  shows the label reads X".
- **Layout with real fonts.** Ahem glyphs are far wider than real ones, so
  goldens wrap and clip text the real app fits on one line. `pumpAcceptance`
  uses a 1200x800 surface to reduce this, but it does not remove it: the
  51-character English `welcome` string measures ~1428px in Ahem at 28px and
  still wraps, versus ~714px in a real font. Treat wrapped or clipped text in a
  golden as a font artifact until you have checked the arithmetic.
- **Patrol E2E.** `integration_test/` and `patrol: ^3.10.0` exist, but
  `patrol_cli` is not installed locally, no Android/iOS device or emulator is
  connected (only macOS desktop and Chrome), and
  [`e2e-android.yml`](.github/workflows/e2e-android.yml) never runs on a
  pull request, by design: it runs on `workflow_dispatch`, plus a weekly
  `schedule` in the template repository only (a repository created from it
  skips the scheduled run). **A session cannot run Patrol locally.**
  Anyone can dispatch it: Actions -> E2E Android (Patrol) -> Run workflow.
  The native harness exists (`android/app/src/androidTest/`,
  `PatrolJUnitRunner`, orchestrator) and run 32966672465 collected and executed a
  real test (`Total: 1`). The job also fails on `Total: 0` or a non-zero
  `Failed:` count, so a green run there is now trustworthy - that was not true
  before, when it went green having run nothing.
  It needs no backend: built without `BASE_URL`, the auth -> home test signs
  in through the offline demo account. One live caveat: `patrol_cli` must
  stay pinned to the version matching the `patrol` dependency, or it aborts
  before any test runs.
- **Real device behavior**, including everything RASP (`lib/core/security/` is a
  no-op by default and only meaningful on a real device).
- **Gestures**: hover, right-click, drag, long-press discoverability,
  multi-touch, one-handed reachability.
- **Store and deploy flows**: `fastlane/`, `deploy-{android,ios,web}.yml` all
  need credentials this environment lacks.
- **Anything needing a live backend.** With no `BASE_URL` the app signs in
  through the offline demo, which proves the flow but not your API; no
  reachable API exists here.
- **Per-layer coverage thresholds.** The Quality gate enforces only a total
  line coverage floor (`COVERAGE_MIN_TOTAL` in [`ci.yml`](.github/workflows/ci.yml)).
  The per-layer targets live in [`coverage.yml`](.github/workflows/coverage.yml),
  which is manual plus weekly, not per-PR.

### Which checks a PR gets

The workflows below run on PRs. **Every PR reports Quality gate** - the
minimum - and Docs check, Action pins and the JDK 25 Android job join only
when their paths change.
While the sample strip is in the tree, every PR also reports its Strip jobs. <!-- strip:strip-tool line -->
`test/tooling/claude_md_checks_table_test.dart` fails if this table and the
workflows' `pull_request` triggers drift apart:

| Workflow | Check name(s) | Runs when |
|---|---|---|
| [`ci.yml`](.github/workflows/ci.yml) | Quality gate | **every** PR; the expensive steps are skipped inside the job when nothing outside `**/*.md` and `docs/**` changed |
| [`docs-check.yml`](.github/workflows/docs-check.yml) | Docs check | any `**/*.md`, `tool/check_docs.dart`, `tool/doc_signatures.dart`, `tool/doc_symbols.dart`, `tool/doc_env_runs.dart`, `tool/doc_dart_defines.dart`, `tool/doc_test_paths.dart`, `lib/core/config/dart_defines.dart`, or the workflow itself (`.github/workflows/docs-check.yml`) |
| [`action-pins.yml`](.github/workflows/action-pins.yml) | Action pins, Workflow lint (actionlint + shellcheck) | any `.github/**` (so every Dependabot github-actions bump) or `scripts/ci/verify_action_pins.sh`; asks the GitHub API, so it is not part of the offline `flutter test` suite |
| [`build.yml`](.github/workflows/build.yml) | Android on JDK 25 (toolchain floor + debug build) | any `android/**`, `tool/check_android_toolchain.dart`, or the workflow itself (`.github/workflows/build.yml`); its manual Build Android/iOS/Web jobs report as skipped |
| [`strip-smoke.yml`](.github/workflows/strip-smoke.yml) | Strip `<variant>` + analyze + test (x5) | **every** PR in the template repository (in a repository created from it, the job reports as skipped); strip, analyze and test are skipped inside each job when nothing outside `**/*.md` and `docs/**` changed <!-- strip:strip-tool line --> |

`ci.yml` has no `paths-ignore`; it filters inside the job instead ("Decide
the gate scope"), so the check always posts a conclusion and can be a required status check, while
a docs-only PR installs no Flutter toolchain.
`strip-smoke.yml` does the same ("Decide the strip scope"). <!-- strip:strip-tool line --> A PR reporting zero checks is the
registration race, never a path exclusion. Poll until
`gh pr checks --json name --jq 'length'` is non-zero before
`gh pr checks --watch`; merging on the "no checks reported" reading skips the
gate entirely.

**Read a green Quality gate or Strip check carefully on a docs-only PR.** It
does not mean format, analyze and test passed - it means they did not run,
because no changed path could have affected them. Each job summary states which
of the two happened and lists every changed path. The skip set is `**/*.md` anywhere plus `docs/**`,
minus `.dart`: `analysis_options.yaml` does not exclude `docs/`, so a `.dart`
file committed under `docs/` is analyzed like any other source and forces the
full gate.

**None of these checks gates a merge until you turn on branch protection.**
Without it, `gh pr merge --squash` succeeds on a red PR and a direct push to
`main` is not rejected, so reading the checks is the session's job. Quality
gate always posts a conclusion, so it is safe to list in
`required_status_checks.contexts` when you enable protection.

## Conventions

- Clean Architecture: domain -> data -> presentation. Business logic stays in
  domain; contracts in `lib/core/contracts` with adapters alongside.
- Riverpod for DI and state; `very_good_analysis` lint rules.
- Conventional Commits enforced by `.githooks/commit-msg`. Install hooks with
  `./scripts/dev/setup_git_hooks.sh`.
- Tests mirror `lib/`. New feature slices: `mason make feature_clean` or
  `./scripts/dev/create_feature.sh`.
<!-- strip:strip-tool start -->
- `tool/golden/` mirrors `lib/` for `strip_sample_features.dart`. Changing a
  file that has a `tool/golden/*` counterpart means updating that counterpart too,
  or [`strip-smoke.yml`](.github/workflows/strip-smoke.yml) breaks.
<!-- strip:strip-tool end -->
- No emoji in `docs/`, `CLAUDE.md`, or `.claude/`. The existing `README.md` and
  `CONTRIBUTING.md` use them; leave those alone unless the issue is about them.

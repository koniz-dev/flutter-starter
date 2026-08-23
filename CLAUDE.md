# CLAUDE.md

Guidance for Claude Code sessions working in this repository.

Flutter enterprise starter built on Clean Architecture: 157 files in `lib/`,
134 test files, single root `pubspec.yaml`, default branch `main`.

## Commands

```bash
flutter pub get
./scripts/dev/audit_template.sh        # format check + analyze + test (same gates as CI)
flutter test --timeout=5m              # unit + widget (goldens skipped by default)
flutter analyze
dart format lib test integration_test tool examples
./scripts/test/run_acceptance.sh <N>   # acceptance gates + evidence for issue N
```

`flutter pub get` has a side effect: it appends platform excludes to
`analysis_options.yaml` and writes `ios/Podfile`, `macos/Podfile`, and four
`*.xcconfig` files. Those are tooling churn, not your change. Revert them before
committing, and always stage explicitly rather than with `git add .`.

Code generation (Freezed, json_serializable, Riverpod) is committed. Regenerate
with `flutter pub run build_runner build --delete-conflicting-outputs` only when
you touch an annotated source.

## Workflow

GitHub issues are the single source of truth. Full spec:
[`docs/issue-workflow.md`](docs/issue-workflow.md).

1. Labels are authoritative. Any Project board is a read-only mirror.
2. Taxonomy: `type:{bug,feature,task}` (native issue types are org-only and
   unavailable here), one `epic:*`, one `priority:P0..P3`, one `status:*`.
3. States: Backlog (no status label) -> `status:todo` -> `status:in-progress`
   -> closed, or `status:needs-uat`, or `status:blocked`.
4. Exactly one state per open issue. A `status:*` label comes off only by
   closing the issue or swapping to another state - never stripped alone, or the
   issue lands in invisible limbo.
5. Every startable issue has a `## Acceptance criteria` section (exact heading)
   with observable steps. No criteria means not startable.
6. Take the highest-priority unassigned `status:todo` issue; ties break oldest
   first. If the queue is empty, triage one Backlog issue in, then restart.
7. Claim by self-assigning and swapping the label, then **re-read the issue** -
   `--add-assignee` adds you alongside an existing assignee rather than failing,
   so this is the only way to know you won the race. If you lost, unassign and
   take the next issue.
8. Commits and PR bodies use `Refs koniz-dev/flutter-starter#N`. `Fixes`,
   `Closes`, and `Resolves` are banned: auto-closing on merge destroys the
   verification gate.
9. Ship via feature branch + PR (`CONTRIBUTING.md` naming, Conventional
   Commits), wait for the **Quality gate** check, merge `--squash
   --delete-branch`.
10. Done means closed AND evidence-backed. One issue at a time.

**Canonical epic list:
[`scripts/bootstrap-issue-labels.sh`](scripts/bootstrap-issue-labels.sh)**
(`./scripts/bootstrap-issue-labels.sh --list-epics`). Never re-type the epic
list anywhere else - humans, sessions, and any issue-filing integration read it
from that script so the three cannot drift.

## Acceptance verification

Run `./scripts/test/run_acceptance.sh <issue-number>`. It runs the format check,
`flutter analyze`, `flutter test`, and the golden-tagged acceptance tests, tees
every log into `docs/verification/issue-<N>/`, and copies captured PNGs there so
the evidence directory is self-contained and committable.

Three tiers exist here:

- **Tier 1 - `flutter test`.** Unit and widget tests on the host VM. Widget
  tests pump real screens via [`test/helpers/pump_app.dart`](test/helpers/pump_app.dart)
  and assert against [`lib/core/constants/ui_keys.dart`](lib/core/constants/ui_keys.dart).
  This is the workhorse.
- **Tier 2 - acceptance goldens.** Tests under `test/acceptance/` tagged
  `golden`, using [`test/acceptance/acceptance_helpers.dart`](test/acceptance/acceptance_helpers.dart).
  [`dart_test.yaml`](dart_test.yaml) skips the `golden` tag by default, so CI,
  `.githooks/pre-push`, and plain `flutter test` ignore them; the acceptance
  runner opts in with `--run-skipped --tags golden`. Goldens are **evidence, not
  a CI gate** - a golden regression will not fail CI, by design.
- **Tier 3 - not drivable here.** Route to `status:needs-uat`.

### What this tooling cannot verify

Be honest about these. Claiming any of them is verified is the fastest way to
make the loop worthless.

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
  `patrol_cli` is not installed, no Android/iOS device or emulator is connected
  (only macOS desktop and Chrome), and
  [`e2e-android.yml`](.github/workflows/e2e-android.yml) is
  `workflow_dispatch`-only by design. A session cannot run Patrol.
- **Real device behavior**, including everything RASP (`lib/core/security/` is a
  no-op by default and only meaningful on a real device).
- **Gestures**: hover, right-click, drag, long-press discoverability,
  multi-touch, one-handed reachability.
- **Store and deploy flows**: `fastlane/`, `deploy-{android,ios,web}.yml` all
  need credentials this environment lacks.
- **Anything needing a live backend.** The auth flow calls the network; no
  reachable API exists here.
- **Coverage thresholds.** [`coverage.yml`](.github/workflows/coverage.yml) is
  manual plus weekly, not per-PR.
- **Docs-only PRs get no Quality gate.** `ci.yml` has
  `paths-ignore: ['**/*.md', 'docs/**']`, so `gh pr checks` reports no checks
  rather than a pass. Expected; do not wait on it and do not call it a failure.

### Evidence discipline

- Persist artifacts as **committed files** under `docs/verification/issue-<N>/`,
  and commit them **before** the closing comment so links resolve. Terminal
  scrollback is not evidence.
- **Open every screenshot yourself** and confirm it shows the asserted behavior
  before writing PASS. A zero exit from `run_acceptance.sh` is an input, not a
  verdict; the script prints that reminder on success on purpose.
- **Never relay a subagent's PASS you have not inspected.** If a subagent says a
  screenshot proves something, open that screenshot. A subagent's confidence is
  not evidence and its context is not retrievable later.
- Name the artifact that proves each criterion, one row per criterion. "All
  criteria pass, see logs" is not a PASS summary.
- If a criterion cannot be driven, say which one and why, and route to
  `status:needs-uat` with the exact human steps and what PASS would look like.

## Loop Protocol

Four roles in [`.claude/agents/`](.claude/agents/): `planner`, `implementer`,
`qa`, `security`. Each role's `tools:` frontmatter scopes its write lane.

**Reviewer roles file issues, they do not fix them.** `qa` and `security` are
declared without `Edit` or `Write`; their output is a filed issue in Backlog.

Caveat, stated plainly: `tools:` gating is coarse. Withholding `Edit`/`Write`
removes the obvious path, but every role needs `Bash` to call `gh`, and `Bash`
can write files. The write lane is therefore enforced by instruction as much as
by capability. If a reviewer role ever edits code, that is a protocol violation
to be caught in review, not something the harness will block.

### Phase order

```
planner  ->  implementer  ->  qa  ->  security (risk-gated)  ->  close or hand off
```

`security` runs only when the diff touches `lib/core/security/`,
`lib/core/storage/`, `lib/core/network/`, `.env*`, dependency versions, or
anything auth-related. Otherwise skip it.

### Gate table

What must be true before the next phase starts:

| Gate | Before entering | Must be true |
|---|---|---|
| G1 | implementer | Issue has a `## Acceptance criteria` section with observable steps; scope fits one `epic:*`; issue is `status:in-progress` and assigned to this session (re-read confirmed) |
| G2 | qa | Change is merged to `main`; commits carry `Refs owner/repo#N` and no `Fixes`/`Closes`/`Resolves`; `./scripts/dev/audit_template.sh` exits 0 |
| G3 | security | G2 held and the diff touches a risk surface listed above |
| G4 | close | Every criterion has a named artifact under `docs/verification/issue-<N>/`; every PNG was opened and inspected by the closing session; evidence is committed and pushed |
| G5 | needs-uat | The blocking criterion is genuinely in tier 3; the comment states the human steps and what PASS means |

A gate that does not hold is not a judgment call. Stop and route.

### Escalation

- **QA failure returns to the implementer, not the planner.** QA files an issue
  and comments on the original; the implementer picks it up. The planner is only
  re-entered if the acceptance criteria themselves were wrong or unachievable.
- **Security finding** files a separate issue at `priority:P0` (exploitable) or
  `priority:P1` (hardening) with `epic:core-security`. It never edits code.
- **Scope explosion** (change would span two epics): comment a proposed split,
  set `status:blocked`, unassign. Back to the planner.
- **Missing or unobservable criteria**: `status:blocked` with a comment naming
  what is missing. Back to the planner. Never guess the intent.
- **Lost claim race**: unassign, take the next issue, no comment needed.

### Tiebreaker priority order

When two candidate issues compete:

1. `priority:P0` over anything else.
2. Unblocks another issue over standalone.
3. Lower `priority:*` number.
4. `type:bug` over `type:feature` over `type:task`.
5. Lower issue number (oldest first).

### Parallelism

- **Never two implementers in the same `epic:*`.** Merge conflicts in a Clean
  Architecture slice are expensive and the loop cannot arbitrate them.
- One implementer per issue, one issue per implementer. Always.
- `qa` and `security` may run concurrently with each other on the same merged
  change - they only read and file.
- `qa` on issue A may run concurrently with `implementer` on issue B provided
  the epics differ.
- `planner` may run concurrently with anything; triage only writes labels and
  issue bodies.
- Only one session at a time may hold a `status:in-progress` claim on a given
  issue. The claim-then-re-read step in step 7 above is what enforces this.

## Conventions

- Clean Architecture: domain -> data -> presentation. Business logic stays in
  domain; contracts in `lib/core/contracts` with adapters alongside.
- Riverpod for DI and state; `very_good_analysis` lint rules.
- Conventional Commits enforced by `.githooks/commit-msg`. Install hooks with
  `./scripts/dev/setup_git_hooks.sh`.
- Tests mirror `lib/`. New feature slices: `mason make feature_clean` or
  `./scripts/dev/create_feature.sh`.
- `tool/golden/` mirrors `lib/` for `strip_sample_features.dart`. Changing a
  file that has a `tool/golden/*` counterpart means updating that counterpart too,
  or [`strip-smoke.yml`](.github/workflows/strip-smoke.yml) breaks.
- No emoji in `docs/`, `CLAUDE.md`, or `.claude/`. The existing `README.md` and
  `CONTRIBUTING.md` use them; leave those alone unless the issue is about them.

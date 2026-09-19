# CLAUDE.md

Guidance for Claude Code sessions working in this repository.

Flutter enterprise starter built on Clean Architecture: 161 Dart files in
`lib/`, 142 `*_test.dart` files under `test/` (plus 2 in `integration_test/`),
single root `pubspec.yaml`, default branch `main`. Recheck the counts with
`find lib -name '*.dart' | wc -l` and `find test -name '*_test.dart' | wc -l`
rather than trusting this line.

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
3. States, with every exit and the role that performs it:

   ```
   Backlog (no status label) --planner triage--> status:todo
   status:todo        --implementer claim-->     status:in-progress
   status:in-progress --implementer verifies-->  closed
   status:in-progress --implementer hands off--> status:needs-uat
   any state          --any role, + comment-->   status:blocked
   status:needs-uat   --planner sweep, human PASS--> closed
   status:needs-uat   --planner sweep, human FAIL--> status:todo
   status:blocked     --planner sweep, blocker gone--> status:todo
   status:in-progress --planner sweep, claim is stale--> status:todo
   ```

   No state is a one-way door. `status:blocked` and `status:needs-uat` are
   exited by the **planner** sweep (see `.claude/agents/planner.md`), which is
   why the planner runs even when the `status:todo` queue looks non-empty.
4. Exactly one state per open issue, and a `status:*` label is only ever
   **swapped** for another one - never stripped on its own, or the issue lands
   in invisible limbo. **Closing does not touch the label:** the last state
   stays on the closed issue as a record, so `gh issue list --state closed
   --label status:in-progress` is expected to return most closed issues. Always
   pass `--state open` when you mean the live queue. The one legitimate
   no-status issue is an untriaged Backlog issue, open or closed.
5. Every startable issue has a `## Acceptance criteria` section (exact heading)
   with observable steps. No criteria means not startable.
6. Take the top issue from the **Tiebreaker priority order** below - there is
   exactly one such order, and `docs/issue-workflow.md` implements it rather
   than restating it. If the queue is empty, triage one Backlog issue in, then
   restart.
7. Claim by self-assigning and swapping the label, then **re-read the issue** -
   `--add-assignee` adds you alongside an existing assignee rather than failing,
   so this is the only way to know you won the race. If you lost, unassign and
   take the next issue.
8. Commits and PR bodies use `Refs koniz-dev/flutter-starter#N`. `Fixes`,
   `Closes`, and `Resolves` are banned: auto-closing on merge destroys the
   verification gate. This is now machine-checked -
   [`scripts/dev/check_issue_refs.sh`](scripts/dev/check_issue_refs.sh), run on
   every PR by [`issue-refs.yml`](.github/workflows/issue-refs.yml). Run it
   locally before pushing:
   `./scripts/dev/check_issue_refs.sh --range origin/main..HEAD`.
9. Ship via feature branch + PR (`CONTRIBUTING.md` naming, Conventional
   Commits), wait for the checks the PR actually gets (see "Which checks a PR
   gets" below), merge `--squash --delete-branch`. `main` is **not** protected -
   a direct push would succeed - so the branch-and-PR rule is discipline, not
   enforcement. Never test that.
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
  `patrol_cli` is not installed locally, no Android/iOS device or emulator is
  connected (only macOS desktop and Chrome), and
  [`e2e-android.yml`](.github/workflows/e2e-android.yml) is
  `workflow_dispatch`-only by design. **A session cannot run Patrol.**
  A **human** can now run it: Actions -> E2E Android (Patrol) -> Run workflow.
  The native harness exists (`android/app/src/androidTest/`,
  `PatrolJUnitRunner`, orchestrator) and run 32966672465 collected and executed a
  real test (`Total: 1`). The job also fails on `Total: 0` or a non-zero
  `Failed:` count, so a green run there is now trustworthy - that was not true
  before, when it went green having run nothing.
  Two live caveats: the shipped test still **fails without a reachable backend**
  (the auth flow posts to `BASE_URL`), so a `needs-uat` hand-off must say whether
  the human has an API; and `patrol_cli` must stay pinned to the version matching
  the `patrol` dependency, or it aborts before any test runs.
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
### Which checks a PR gets

Four workflows run on PRs and only two of them filter on paths, so "no Quality
gate" is normal rather than a failure:

| Workflow | Check name(s) | Runs when |
|---|---|---|
| [`ci.yml`](.github/workflows/ci.yml) | Quality gate | any path **outside** `**/*.md` and `docs/**` |
| [`docs-check.yml`](.github/workflows/docs-check.yml) | Docs check | any `**/*.md`, `tool/check_docs.dart`, or the workflow itself |
| [`issue-refs.yml`](.github/workflows/issue-refs.yml) | Issue refs | **every** PR, no path filter |
| [`strip-smoke.yml`](.github/workflows/strip-smoke.yml) | Strip `<variant>` + analyze + test (x3) | **every** PR, no path filter |

So a docs-only PR gets Docs check, Issue refs and the three Strip jobs but no
Quality gate, and an evidence-only PR of `.log`/`.png` files gets Issue refs
and the Strip jobs. **Every PR gets at least four checks** - a PR reporting
zero is the registration race, not a path exclusion. Poll until
`gh pr checks --json name --jq 'length'` is non-zero before
`gh pr checks --watch`; merging on the "no checks reported" reading skips the
gate entirely.

**None of these checks gates a merge, and `main` has no branch protection.**
`gh pr merge --squash` succeeds on a red PR, and a direct push to `main` is not
rejected. Reading the checks is therefore the session's job, not the platform's.
Enabling protection needs a human (criterion 5 of
koniz-dev/flutter-starter#58); the exact command is in that issue's `needs-uat`
comment. Note that Quality gate cannot become a *required* check while `ci.yml`
carries `paths-ignore`, because a required check that never reports leaves every
docs-only PR permanently unmergeable.

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
- **Account for the standing goldens.** `run_acceptance.sh` copies every PNG
  under `test/acceptance/goldens/` into the evidence directory, so a non-visual
  issue still ships six screenshots that prove nothing about it. Do not cite
  them. Say so explicitly in the closing comment, backed by a checksum showing
  they are the repository's unchanged goldens:

  ```bash
  shasum -a 256 test/acceptance/goldens/*.png docs/verification/issue-<N>/*.png \
    | sort | tee docs/verification/issue-<N>/goldens-checksums.txt
  ```

  Matching pairs mean the run did not change them and no criterion rests on
  them. A mismatch is a golden regression and needs explaining, not ignoring.
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

#### Who invokes each phase

No role invokes another role - none of them can. The phase order is driven by
**the session that owns the loop**:

- **Orchestrated run** (a top-level session dispatching role subagents): that
  session is the owner. It dispatches `planner`, then `implementer`, then `qa`
  on the merged change, then `security` if G3 holds. It is also the only party
  that can see two implementers at once, so it enforces Parallelism. This is how
  `qa` came to file koniz-dev/flutter-starter#88 and #89.
- **Solo run** (one session working an issue end to end, no subagents): there is
  nobody to dispatch, so the implementer **performs the `qa` checklist itself**
  before closing, as the last step of G4. The checklist is in
  [`.claude/agents/implementer.md`](.claude/agents/implementer.md) ("Self-QA
  before closing") and is a copy of steps 2 and 3 of
  [`.claude/agents/qa.md`](.claude/agents/qa.md).

Self-QA is the weaker of the two - the same session that wrote the PASS is
auditing it. Prefer a separate `qa` pass on anything non-trivial. What is never
acceptable is skipping both and closing anyway.

### Gate table

What must be true before the next phase starts:

| Gate | Before entering | Must be true |
|---|---|---|
| G1 | implementer | Issue has a `## Acceptance criteria` section with observable steps; scope fits one `epic:*`; issue is `status:in-progress` and assigned to this session (re-read confirmed) |
| G2 | qa | Change is merged to `main`; commits carry `Refs owner/repo#N` and no `Fixes`/`Closes`/`Resolves`; `./scripts/dev/audit_template.sh` exits 0 |
| G3 | security | G2 held and the diff touches a risk surface listed above |
| G4 | close | Every criterion has a named artifact under `docs/verification/issue-<N>/`; every PNG was opened and inspected by the closing session; evidence is committed and pushed; a `qa` pass or the self-QA checklist has run |
| G5 | needs-uat | The blocking criterion is genuinely in tier 3; the comment states the human steps and what PASS means |

A gate that does not hold is not a judgment call. Stop and route.

**The one exception to G4: an issue whose premise is false.** A bug that does
not exist has nothing to verify, so demanding evidence would force a fabricated
PASS table. Close it `--reason "not planned"` with a comment showing *why* the
premise fails - the file and line that already behave correctly, or the command
whose output contradicts the report - and no `docs/verification/` directory.
That is the only close without evidence, and the comment is what makes it
auditable. Precedents: koniz-dev/flutter-starter#25 and #84.

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
- **Stale claim** (a session died holding `status:in-progress`): any role may
  release it - unassign, swap `status:in-progress` back to `status:todo`, and
  comment whether the work had already merged, so the next implementer does not
  redo it. Recipe: "Release a stale claim" in
  [`docs/issue-workflow.md`](docs/issue-workflow.md). Only release a claim you
  have reason to believe is dead; a live claim belongs to its holder.

### Tiebreaker priority order

**This list is the only definition of the order.** `docs/issue-workflow.md`
implements it in its queue selector and does not restate it; nothing else may
paraphrase it. When two candidate issues compete:

1. `priority:P0` over anything else.
2. Unblocks another issue over standalone.
3. Lower `priority:*` number.
4. `type:bug` over `type:feature` over `type:task`.
5. Lower issue number (oldest first).

Levels 1, 3, 4 and 5 are mechanical and the selector sorts by them. Level 2 is
not - no label records "unblocks #N" - so the selector prints the ranked
candidates instead of picking blindly, and the session applies level 2 by
reading them.

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

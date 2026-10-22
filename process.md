# Maintainer process

How work on **the starter itself** (koniz-dev/flutter-starter) is tracked,
verified and shipped. It lives on this orphan `maintainers` branch, not on
`main`, because `main` is what an adopter receives from "Use this template",
and none of this belongs to their project. Read it together with `main`'s
`CLAUDE.md`, which describes the code (commands, tests, checks, conventions).

Paths below are relative to this branch. Commands are run from the main
checkout, with:

- `$M` = this worktree, `../flutter-starter-maintainers`
- `$E` = the evidence worktree, `../flutter-starter-evidence`

`scripts/install.sh` sets both up and points the main checkout's untracked
`CLAUDE.local.md` here, so a session loads this file automatically.

## Workflow

GitHub issues are the single source of truth. Full spec:
[`issue-workflow.md`](issue-workflow.md).

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
   exited by the **planner** sweep (see `agents/planner.md`), which is
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
   exactly one such order, and `issue-workflow.md` implements it rather
   than restating it. If the queue is empty, triage one Backlog issue in, then
   restart.
7. Claim by self-assigning and swapping the label, then **re-read the issue** -
   `--add-assignee` adds you alongside an existing assignee rather than failing,
   so this is the only way to know you won the race. If you lost, unassign and
   take the next issue.
8. Commits and PR bodies use `Refs koniz-dev/flutter-starter#N`. `Fixes`,
   `Closes`, and `Resolves` are banned: auto-closing on merge destroys the
   verification gate. It is checked by
   [`scripts/check_issue_refs.sh`](scripts/check_issue_refs.sh) as part of the
   G2 gate. No workflow on `main` runs it any more: an adopter's commits
   reference their own tracker (koniz-dev/flutter-starter#621). Run it before
   pushing: `$M/scripts/check_issue_refs.sh --range origin/main..HEAD`.
9. Ship via feature branch + PR (`CONTRIBUTING.md` naming, Conventional
   Commits), wait for the checks the PR actually gets (see "Which checks a PR
   gets" below), merge `--squash --delete-branch`. `main` is **not** protected -
   a direct push would succeed - so the branch-and-PR rule is discipline, not
   enforcement. Never test that.
10. Done means closed AND evidence-backed. One issue at a time.

**Canonical epic list:
[`scripts/bootstrap-issue-labels.sh`](scripts/bootstrap-issue-labels.sh)**
(`$M/scripts/bootstrap-issue-labels.sh --list-epics`). Never re-type the epic
list anywhere else - humans, sessions, and any issue-filing integration read it
from that script so the three cannot drift.

The same script also owns the **path -> epic** map:
`$M/scripts/bootstrap-issue-labels.sh --list-map` answers "which epic owns this
diff". Every tracked path maps to exactly one epic, enforced by
[`scripts/check_epic_coverage.dart`](scripts/check_epic_coverage.dart) in the G2
gate. If no epic fits a change, that is a taxonomy gap: file it,
do not force the nearest label - the parallelism rule below keys on that label.

## Acceptance verification

### Scope test: would an adopter notice?

This is a starter template, not an app that ships. A criterion proves the
**mechanism** is correct; it is not there to prove the *product* runs. So before
writing one, ask: **would an adopter notice if this were missing?** If answering
it needs a physical device, a custom CA, an Apple certificate, a reachable
backend or store credentials, that answer belongs to the adopter's app, not to
this repository - prove the mechanism at tier 1 or tier 2 here and hand the
residual over. Precedent: koniz-dev/flutter-starter#48, #59, #62 and #108 each
sat blocked for months of calendar time on exactly that (a real device, a custom
CA, an Apple cert, on-device storage inspection) after the mechanism had already
been proven, and all four closed with the residual assigned to the adopter.

Run `$M/scripts/run_acceptance.sh <issue-number>` from the main checkout. It
runs the format check, `flutter analyze`, `flutter test`, and the golden-tagged
acceptance tests, and tees every log and captured PNG straight into the
evidence worktree's `docs/verification/issue-<N>/` (`$E`, see Evidence
discipline). Nothing it writes lands in the main checkout.

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

## Evidence

### Evidence discipline

- Persist artifacts as **committed files** under `docs/verification/issue-<N>/`
  on the orphan **`evidence` branch**, never on `main`: `main` is what an
  adopter gets from "Use this template" (koniz-dev/flutter-starter#619). Keep a
  worktree of it at `$E` (`git worktree add ../flutter-starter-evidence
  origin/evidence`, recipe in that branch's README); `run_acceptance.sh` writes
  there directly. Add anything else the criteria need, commit, and push
  (`git -C $E push origin HEAD:refs/heads/evidence --no-verify`) **before** the
  closing comment, linking
  `https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-<N>/<file>`.
  That branch has no Flutter project, so commit and push there with
  `--no-verify`. Terminal scrollback is not evidence.
- **Nothing on `main` points back here.** Code comments, docs and test names
  say *why* the code is the way it is; they never cite an issue
  (`koniz-dev/flutter-starter#N`, a bare `#N`, an issue URL) or the evidence
  branch. Those belong in commit messages and PR bodies. `check_deliverable.sh`
  fails on the cited forms (koniz-dev/flutter-starter#629).
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
  shasum -a 256 test/acceptance/goldens/*.png $E/docs/verification/issue-<N>/*.png \
    | sort | tee $E/docs/verification/issue-<N>/goldens-checksums.txt
  ```

  Matching pairs mean the run did not change them and no criterion rests on
  them. A mismatch is a golden regression and needs explaining, not ignoring.
- If a criterion cannot be driven, say which one and why, and route to
  `status:needs-uat` with the exact human steps and what PASS would look like.

## Loop Protocol

Four roles in [`agents/`](agents/) (linked into the checkout's `.claude/agents/` by `scripts/install.sh`): `planner`, `implementer`,
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
  [`agents/implementer.md`](agents/implementer.md) ("Self-QA
  before closing") and is a copy of steps 2 and 3 of
  [`agents/qa.md`](agents/qa.md).

Self-QA is the weaker of the two - the same session that wrote the PASS is
auditing it. Prefer a separate `qa` pass on anything non-trivial. What is never
acceptable is skipping both and closing anyway.

### Gate table

What must be true before the next phase starts:

| Gate | Before entering | Must be true |
|---|---|---|
| G1 | implementer | Issue has a `## Acceptance criteria` section with observable steps; scope fits one `epic:*`; issue is `status:in-progress` and assigned to this session (re-read confirmed) |
| G2 | qa | Change is merged to `main`; commits carry `Refs owner/repo#N` and no `Fixes`/`Closes`/`Resolves` (`$M/scripts/check_issue_refs.sh`); `./scripts/dev/audit_template.sh` exits 0; `dart run $M/scripts/check_epic_coverage.dart` and `$M/scripts/check_deliverable.sh HEAD` exit 0 |
| G3 | security | G2 held and the diff touches a risk surface listed above |
| G4 | close | Every criterion has a named artifact under `docs/verification/issue-<N>/` on the `evidence` branch; every PNG was opened and inspected by the closing session; evidence is committed and pushed; a `qa` pass or the self-QA checklist has run |
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
  [`issue-workflow.md`](issue-workflow.md). Only release a claim you
  have reason to believe is dead; a live claim belongs to its holder.

### Tiebreaker priority order

**This list is the only definition of the order.** `issue-workflow.md`
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

# Issue-driven workflow

GitHub issues are the single source of truth for all work in this repository.
An autonomous Claude Code session should be able to pull an issue, ship it,
verify it, and close it without a human approving each step. This document
defines the taxonomy, the state machine, the invariants that keep the loop
survivable when nobody is watching, and the exact `gh` commands for every
transition.

Repository: `koniz-dev/flutter-starter`. Default branch: `main`.

- Canonical epic list: [`scripts/bootstrap-issue-labels.sh`](../scripts/bootstrap-issue-labels.sh)
  (also `./scripts/bootstrap-issue-labels.sh --list-epics`)
- Session-facing summary: [`CLAUDE.md`](../CLAUDE.md)
- Acceptance harness: [`scripts/test/run_acceptance.sh`](../scripts/test/run_acceptance.sh)

---

## 1. Taxonomy

Run [`scripts/bootstrap-issue-labels.sh`](../scripts/bootstrap-issue-labels.sh)
to create or update every label below. It is idempotent
(`gh label create --force`) and accepts `REPO=owner/name` to target another
repository.

### Type

GitHub's native issue types (`Bug` / `Feature` / `Task`) are an
**organisation-level feature**. This repository is owned by a user account
(`koniz-dev`), so `/orgs/koniz-dev/issue-types` returns 404 and native types
cannot be created by any script or API call. The `type:*` label family stands in
for them. See [section 7](#7-adaptations-for-this-repository) for the migration
path if the repository moves to an organisation.

| Label | Meaning |
|---|---|
| `type:bug` | Broken relative to documented behavior. Includes documentation that contradicts the code. |
| `type:feature` | New capability or user-visible enhancement. |
| `type:task` | Chore, refactor, docs, or tooling work introducing no new capability. |

Exactly one per issue.

### Epic

One functional area per issue. Each epic maps to a real directory or surface in
the tree, so "which epic" is answerable by looking at the diff.

| Label | Surface |
|---|---|
| `epic:core-network` | `lib/core/network` - Dio `ApiClient`, interceptors, realtime/WebSocket |
| `epic:core-storage` | `lib/core/storage` - key-value and secure adapters, token store, migrations |
| `epic:core-security` | `lib/core/security` - RASP providers, hardening, `docs/guides/security/` |
| `epic:core-config` | `lib/core/config` - env layers, `.env`, dart-defines, feature-flag plumbing |
| `epic:core-routing` | `lib/core/routing` - GoRouter tree, guards, navigation adapters |
| `epic:feature-auth` | `lib/features/auth` - login, register, session |
| `epic:feature-tasks` | `lib/features/tasks` - CRUD sample slice |
| `epic:design-system` | `lib/shared` - tokens, theme, shared widgets, accessibility |
| `epic:testing` | `test/`, `integration_test/`, coverage gates, Patrol E2E, golden acceptance |
| `epic:tooling-ci` | `.github/workflows`, `scripts/`, `tool/`, `bricks/`, git hooks |
| `epic:docs` | `docs/`, `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md` |

Exactly one per issue. If a change genuinely spans two epics, it is too big:
split it.

### Priority

| Label | Meaning |
|---|---|
| `priority:P0` | Drop everything. `main` is broken, a released build is unusable, or a security hole is open. |
| `priority:P1` | Next up. Blocks adopters, or a documented workflow is factually wrong. |
| `priority:P2` | Normal queue. Real but not blocking. |
| `priority:P3` | Nice to have. Cosmetic, speculative, or long tail. |

Exactly one per issue.

### Status

| Label | Meaning |
|---|---|
| *(none)* | Backlog. Filed but not triaged. Not startable. |
| `status:todo` | Triaged and startable: has acceptance criteria, nobody assigned. |
| `status:in-progress` | Claimed by an assignee and being worked right now. |
| `status:needs-uat` | Shipped, but one or more criteria need a **human** to verify. |
| `status:blocked` | Cannot proceed: needs a decision, a credential, or an upstream fix. |

At most one per issue, and **exactly** one on any triaged open issue.

---

## 2. Lifecycle

```
Backlog (open, no status label)
   |  triage: add type + epic + priority, write acceptance criteria
   v
status:todo ──claim: assign + relabel──> status:in-progress
                                              | ship (branch, PR, merge)
                                              v
                                        run acceptance criteria
                                          |
                                          ├─ PASS + evidence ────────> closed
                                          |
                                          └─ cannot verify ─> status:needs-uat (human)
                                                                ├─ PASS ──> closed
                                                                └─ FAIL ──> status:todo
   any state ── stuck / needs a decision ──> status:blocked (+ comment, unassign)
```

---

## 3. The six invariants

These are rules, not suggestions. Each one exists because breaking it makes the
unattended loop fail in a specific way.

### Invariant 1 - Exactly one state per open issue

A `status:*` label comes off only by **closing** the issue or by **moving it to
another state**. Never strip a status label on its own.

An open issue with no status label is invisible limbo: it will not appear in the
`status:todo` queue, so no session will ever pick it up, and it will not appear
in `status:in-progress`, so no human will notice it stalled. Every relabel is
therefore a single atomic swap:

```bash
gh issue edit N --remove-label status:todo --add-label status:in-progress
```

The one legitimate no-status open issue is an untriaged Backlog issue. Triage
converts it; nothing else should produce one.

### Invariant 2 - Acceptance criteria live in the issue body

Every startable issue has a section under the exact heading
`## Acceptance criteria`. The exact string matters: sessions grep for it.

Criteria are **concrete observable steps** someone or something can run, with a
stated expected result. They are not dev notes, not a design sketch, and not a
restatement of the title.

Mark any step only a human can perform with a `(human)` prefix.

Good:

```markdown
## Acceptance criteria

1. `./scripts/dev/audit_template.sh` prints a format scope identical to the
   `paths=(...)` array in `scripts/dev/format_dart.sh`.
2. `grep -rn "tool bricks" CONTRIBUTING.md scripts/ docs/guides/` returns no
   matches.
3. `flutter analyze` exits 0.
4. (human) On a physical Android device, the tasks FAB is reachable by
   thumb in one-handed mode.
```

Bad ("verify it works", "make sure nothing breaks", "refactor cleanly") - not
observable, no expected result, nothing to attach evidence to.

**No criteria means the issue is not startable.** A session that picks up a
`status:todo` issue with no `## Acceptance criteria` section must move it back
to Backlog behavior by commenting what is missing and setting `status:blocked`,
not guess at the intent.

### Invariant 3 - Commits link, never close

Commit messages and PR bodies reference issues as:

```
Refs koniz-dev/flutter-starter#12
```

`Fixes`, `Closes`, and `Resolves` are **banned** in commit messages and PR
bodies. GitHub auto-closes an issue when a commit carrying those keywords lands
on the default branch. That would close the issue at *merge* time, before
anything ran the acceptance criteria - destroying the verification gate, which
is the entire point of this workflow.

Use the fully qualified `owner/repo#N` form so the reference survives being
quoted in another repository or in release notes.

> This contradicts the current advice in `CONTRIBUTING.md`
> ("Reference issues in footer: `Closes #123`"). That line is tracked as a bug;
> this document wins.

### Invariant 4 - Definition of Done is closed AND evidence-backed

A session closes an issue only after it has:

1. run the issue's acceptance criteria against the real thing (the running app,
   the actual script, the actual command), and
2. attached **retrievable** evidence - committed files under
   `docs/verification/issue-<N>/`, referenced from the closing comment - plus a
   PASS summary that names which artifact proves which criterion.

"Tests are green", "CI passed", "deployed", and "looks right to me" are **not**
Done. Those are inputs to a verdict, not the verdict.

Evidence must be retrievable *later*, by someone who was not in the session.
Terminal scrollback is not evidence. A screenshot that exists only in a
subagent's context is not evidence.

### Invariant 5 - `status:needs-uat` means a human must verify this

Reserved for criteria an agent genuinely **cannot** drive in this environment.
In this repository, that means:

- hover, right-click, drag, multi-touch, and other pointer/gesture behavior
- real Android or iOS device behavior, including anything RASP-related
- flows blocked by a missing credential, backend, or store account
- font rendering, real-glyph typography, and anything a golden cannot show
  (see [section 6](#6-what-the-acceptance-tooling-cannot-verify))

It is **not** a "someone should test this later" dumping ground. Routing a
criterion you simply did not try to `needs-uat` converts a verification gate
into a backlog of unowned questions.

When routing, the comment must state exactly what the human has to do and what
result would count as PASS. A human's rejection sends the issue back to
`status:todo` with feedback, not to `blocked`.

### Invariant 6 - Labels are the source of truth

Label state is authoritative. Any GitHub Project or board view is a
**read-only mirror** of label state, never the reverse. Nothing in this workflow
reads a board to decide what to do, and no automation writes label state from a
board column.

Boards are allowed. Boards deciding anything are not.

---

## 4. The per-issue agent loop

One issue at a time. Each change stays small and revertible.

1. **Select.** Take the highest-priority `status:todo` issue with no assignee.
   Ties break by lowest issue number (oldest first).

   ```bash
   pick=""
   for p in P0 P1 P2 P3; do
     pick=$(gh issue list --state open \
       --label status:todo --label "priority:$p" \
       --search "no:assignee sort:created-asc" \
       --json number,title,labels --jq '.[0] // empty')
     [[ -n "$pick" ]] && break
   done
   echo "${pick:-queue empty - triage one Backlog issue (step 2)}"
   ```

   Two details are load-bearing here, both learned the hard way:

   - **`.[0] // empty` plus a `-n` test, not `&& break`.** `gh issue list`
     exits 0 when nothing matches, so `... --jq '.[0]' && break` breaks on the
     first iteration (`P0`) every time and the loop never reaches `P1`.
   - **`sort:created-asc`.** `gh issue list` defaults to newest-first, which
     silently inverts the oldest-first tiebreaker.

2. **Triage if the queue is empty.** If nothing is in `status:todo`, take one
   Backlog issue (open, no `status:*`), add `type:*`, `epic:*`, `priority:*`,
   write its `## Acceptance criteria`, and set `status:todo`. Then restart at
   step 1. Triage one issue, not the whole backlog.

3. **Claim, then re-read.** Self-assign and swap the label:

   ```bash
   gh issue edit N --add-assignee @me \
     --remove-label status:todo --add-label status:in-progress
   ```

   Then **re-read the issue** and confirm you actually won:

   ```bash
   gh issue view N --json assignees,labels \
     --jq '{assignees: [.assignees[].login], labels: [.labels[].name]}'
   ```

   `gh issue edit --add-assignee` does not fail when someone else is already
   assigned - it adds you alongside them. If the assignee list contains anyone
   but you, or the labels do not read `status:in-progress`, you lost the race
   against a concurrent session. Release and take the next issue:

   ```bash
   gh issue edit N --remove-assignee @me
   ```

   Do not "fix" the labels to make yourself the winner.

4. **Scope.** Read the acceptance criteria. Confirm the change fits one epic and
   one branch. If the criteria are missing or not observable, stop and apply
   invariant 2. If the change would span two epics, comment a proposed split,
   set `status:blocked`, unassign, and move on.

5. **Implement and ship.** Branch from `main` using the `CONTRIBUTING.md`
   convention (`fix/`, `feature/`, `docs/`, `test/`, `chore/`, `refactor/`),
   commit with Conventional Commits plus `Refs owner/repo#N`, open a PR, wait for
   the **Quality gate** check, then merge.

   ```bash
   git checkout main && git pull
   git checkout -b fix/short-description
   # ... edit ...
   ./scripts/dev/audit_template.sh          # same gates as CI, locally
   git commit -m "fix(scope): what changed

   Refs koniz-dev/flutter-starter#12"
   git push -u origin fix/short-description
   gh pr create --fill --body "Refs koniz-dev/flutter-starter#12"

   # Wait for checks to REGISTER before watching them. Run immediately after
   # `pr create`, `gh pr checks` reports "no checks reported on the ... branch"
   # simply because GitHub has not created them yet - indistinguishable from a
   # docs-only PR that will genuinely never get any. Merging on that reading
   # skips the gate entirely.
   for _ in 1 2 3 4 5 6; do
     [[ "$(gh pr checks --json name --jq 'length' 2>/dev/null || echo 0)" -gt 0 ]] && break
     sleep 10
   done
   gh pr checks --watch
   gh pr merge --squash --delete-branch
   ```

   To tell the two cases apart, compare the changed files against `ci.yml`'s
   `paths-ignore` (`**/*.md`, `docs/**`): if every changed path matches, no check
   will ever appear and there is nothing to wait for.

   ```bash
   gh pr diff --name-only
   ```

6. **Verify and close, or hand off.** Run the acceptance harness, open every
   artifact it produced, then either close with evidence or route to
   `needs-uat` / `blocked`. See [section 5](#5-gh-recipes) for the exact
   commands and [section 6](#6-what-the-acceptance-tooling-cannot-verify) for
   what forces a hand-off.

7. **Stop.** One issue per loop iteration. Return to step 1 only after the
   current issue is closed, in `needs-uat`, or in `blocked`.

At any point, if you are stuck or need a decision that is not yours to make:

```bash
gh issue comment N --body "Blocked: <what is needed, and who can unblock it>"
gh issue edit N --remove-label status:in-progress --add-label status:blocked \
  --remove-assignee @me
```

---

## 5. `gh` recipes

Set once per shell:

```bash
REPO=koniz-dev/flutter-starter
```

### Create (filed straight into the queue)

```bash
gh issue create --repo "$REPO" \
  --title "fix: audit_template.sh reports a format scope it does not use" \
  --label type:bug --label epic:tooling-ci --label priority:P1 \
  --label status:todo \
  --body "$(cat <<'EOF'
## Context

`scripts/dev/audit_template.sh` prints `==> format (lib test integration_test
tool bricks)` but delegates to `scripts/dev/format_dart.sh`, whose `paths=`
array is `(lib test integration_test tool examples)`.

## Acceptance criteria

1. `./scripts/dev/audit_template.sh` prints a scope identical to the `paths=`
   array in `scripts/dev/format_dart.sh`.
2. `flutter analyze` exits 0.
EOF
)"
```

### Create into Backlog (untriaged, no status label)

Omit `--label status:todo`. Anything filed by a reviewer role goes here.

```bash
gh issue create --repo "$REPO" --title "..." \
  --label type:bug --label epic:testing --label priority:P2 --body "..."
```

### List the queue

```bash
# Startable work, highest priority first
gh issue list --repo "$REPO" --state open --label status:todo \
  --search "no:assignee sort:created-asc" \
  --json number,title,labels \
  --template '{{range .}}#{{.number}} {{.title}} [{{range .labels}}{{.name}} {{end}}]{{"\n"}}{{end}}'

# Untriaged backlog
gh issue list --repo "$REPO" --state open \
  --search '-label:status:todo -label:status:in-progress -label:status:needs-uat -label:status:blocked'

# In flight, and by whom
gh issue list --repo "$REPO" --state open --label status:in-progress \
  --json number,title,assignees

# Waiting on a human
gh issue list --repo "$REPO" --state open --label status:needs-uat
```

### Triage (Backlog -> todo)

```bash
gh issue edit N --repo "$REPO" \
  --add-label type:bug --add-label epic:core-network --add-label priority:P2 \
  --add-label status:todo
# If the body lacks '## Acceptance criteria', add it first:
gh issue edit N --repo "$REPO" --body-file /tmp/issue-N-body.md
```

### Claim (todo -> in-progress), then confirm

```bash
gh issue edit N --repo "$REPO" --add-assignee @me \
  --remove-label status:todo --add-label status:in-progress

ME=$(gh api /user --jq .login)
gh issue view N --repo "$REPO" --json assignees,labels --jq '
  if ([.assignees[].login] == ["'"$ME"'"]
      and ([.labels[].name] | index("status:in-progress")))
  then "claim confirmed on #N"
  else error("lost the claim race on #N - unassign and take the next issue")
  end'
```

### Hand off to a human (in-progress -> needs-uat)

```bash
gh issue comment N --repo "$REPO" --body "$(cat <<'EOF'
Shipped in #<pr>. Automated criteria 1-3 PASS; evidence in
`docs/verification/issue-N/`.

Criterion 4 needs a human: this harness cannot drive a physical Android device.

**What to do:** install the debug build on an Android phone, open the tasks
screen, and confirm the FAB is reachable one-handed.
**PASS means:** the FAB sits inside the bottom-right thumb arc without
reaching. Comment PASS or FAIL with a photo.
EOF
)"
gh issue edit N --repo "$REPO" \
  --remove-label status:in-progress --add-label status:needs-uat \
  --remove-assignee @me
```

### Human rejects (needs-uat -> todo)

```bash
gh issue comment N --repo "$REPO" --body "FAIL: <what was wrong>. <What to change.>"
gh issue edit N --repo "$REPO" \
  --remove-label status:needs-uat --add-label status:todo
```

### Block (any state -> blocked)

```bash
gh issue comment N --repo "$REPO" --body "Blocked: <what is needed and who can unblock>"
gh issue edit N --repo "$REPO" \
  --remove-label status:in-progress --add-label status:blocked \
  --remove-assignee @me
```

### Unblock (blocked -> todo)

```bash
gh issue comment N --repo "$REPO" --body "Unblocked: <what changed>"
gh issue edit N --repo "$REPO" \
  --remove-label status:blocked --add-label status:todo
```

### Close with evidence

Evidence must be **merged** before the closing comment, so the links resolve on
`main`.

Prefer putting the evidence in the **same PR as the fix**. When the fix has
already merged (as happens when verification turns up extra work), send the
evidence as its own small PR - it still goes through a branch, because
`docs/verification/**` is not exempt from the branch-and-PR rule. Be aware that
an evidence-only PR touches nothing but `docs/**`, which `ci.yml` excludes via
`paths-ignore`, so it will report **no checks at all**. That is expected: the
gate for evidence is a human or agent reading it, not CI.

```bash
./scripts/test/run_acceptance.sh N          # writes docs/verification/issue-N/
# Now OPEN every PNG and log it produced and confirm each criterion.

git checkout -b chore/acceptance-evidence-issue-N
git add docs/verification/issue-N
git commit -m "test: acceptance evidence for issue N

Refs koniz-dev/flutter-starter#N"
git push -u origin chore/acceptance-evidence-issue-N
gh pr create --fill --body "Refs koniz-dev/flutter-starter#N"
gh pr merge --squash --delete-branch

gh issue close N --repo "$REPO" --reason completed --comment "$(cat <<'EOF'
## PASS

Verified against the merged change on `main` (PR #<pr>, commit <sha>).

| Criterion | Result | Evidence |
|---|---|---|
| 1. audit scope matches format_dart.sh | PASS | `docs/verification/issue-N/format.log` |
| 2. no stale "tool bricks" references | PASS | `docs/verification/issue-N/grep.log` |
| 3. flutter analyze exits 0 | PASS | `docs/verification/issue-N/analyze.log` |

Evidence directory: `docs/verification/issue-N/`
EOF
)"
```

Closing an issue satisfies invariant 1 - the `status:in-progress` label stays on
the closed issue as a record. Do not strip it.

---

## 6. What the acceptance tooling cannot verify

Being precise here is what keeps `status:needs-uat` meaningful. This repository
has three verification tiers.

### Tier 1 - `flutter test` (agent-drivable, no device)

157 files in `lib/`, 134 test files. Unit and widget tests run on the host VM.
Widget tests can pump real screens through
[`test/helpers/pump_app.dart`](../test/helpers/pump_app.dart) and assert against
the stable keys in
[`lib/core/constants/ui_keys.dart`](../lib/core/constants/ui_keys.dart). This is
the workhorse.

### Tier 2 - acceptance goldens (agent-drivable, committed PNGs)

[`scripts/test/run_acceptance.sh`](../scripts/test/run_acceptance.sh) runs
golden-tagged tests under `test/acceptance/` and copies the resulting PNGs into
`docs/verification/issue-<N>/`. Because golden bytes depend on the host
renderer, [`dart_test.yaml`](../dart_test.yaml) skips the `golden` tag by default
- so plain `flutter test`, the CI **Quality gate**, and `.githooks/pre-push` all
ignore them, and only the acceptance runner opts in with
`--run-skipped --tags golden`.

**Goldens here are evidence, not a CI gate.** A golden regression will not fail
CI. That is deliberate: cross-platform golden gating is a maintenance tax this
repository has not chosen to pay.

**What a golden actually proves.** `flutter test` renders text with the Ahem
test font, so every glyph is an **opaque block**. A golden from this harness
proves widget presence, position, size, colour, and overflow. It does **not**
prove text content or icon glyphs. Assert those with `find.text()` and
`find.byIcon()` in the same test, and never write "the golden shows the label
says X" - it cannot.

Ahem glyphs are also far wider than real ones, so a narrow surface wraps and
clips text the real app fits on one line. `pumpAcceptance` defaults to a 1200x800
surface for this reason, which reduces the problem without removing it: the
51-character English `welcome` string measures about 1428px in Ahem at 28px
`headlineMedium` and still wraps, where a real font needs roughly 714px and does
not. Treat wrapped or clipped text in a golden as a font artifact until you have
checked the arithmetic - it is not evidence of a layout bug.

### Tier 3 - what nothing in this repository can drive

Route these to `status:needs-uat`:

- **Patrol E2E.** `integration_test/` exists and `patrol: ^3.10.0` is in
  `pubspec.yaml`, but `patrol_cli` is not installed locally, no Android or iOS
  device or emulator is connected (only macOS desktop and Chrome), and
  [`e2e-android.yml`](../.github/workflows/e2e-android.yml) is
  `workflow_dispatch`-only by design. A session cannot run Patrol.

  A human can, through Actions -> E2E Android (Patrol) -> Run workflow, and that
  path is now real: the native harness exists
  (`android/app/src/androidTest/java/.../MainActivityTest.java`,
  `PatrolJUnitRunner`, the AndroidX orchestrator) and run 32966672465 collected
  and executed a genuine test (`Total: 1`).

  Two things to put in the hand-off comment.

  First, **the shipped test fails without a reachable backend.** The sample auth
  flow posts to `BASE_URL`; with no server the app stays on the login screen and
  `expect($(#e2e_home_content), findsOneWidget)` finds nothing. Ask whether the
  human has an API before sending them there.

  Second, a green run is now trustworthy, which it was not before. The job fails
  when the summary reports `Total: 0` or a non-zero `Failed:` count, closing two
  false-green paths: an empty test set (`patrol test` exits 0 on one) and a
  failing set whose exit code was swallowed by a pipe without `pipefail`.
- **Real device behavior.** Anything RASP-related
  (`lib/core/security/`) is a no-op by default and only becomes meaningful on a
  real device with a real implementation wired in.
- **Gestures and pointer input.** Hover, right-click, drag, long-press
  discoverability, multi-touch, one-handed reachability.
- **Real typography.** Font fallback, glyph rendering, text overflow with real
  fonts, right-to-left layout with real glyphs.
- **Store and deployment flows.** `fastlane/`, `deploy-android.yml`,
  `deploy-ios.yml`, `deploy-web.yml` all need credentials this environment does
  not have.
- **Anything requiring a live backend.** The auth flow calls the network; there
  is no reachable API in this environment.
- **Coverage thresholds.** [`coverage.yml`](../.github/workflows/coverage.yml) is
  `workflow_dispatch` plus a weekly schedule, not per-PR. A session can run
  `flutter test --coverage` locally but the gate itself is not on the PR path.

### Evidence discipline

- Persist artifacts as **committed files** under `docs/verification/issue-<N>/`.
  Scrollback is not evidence.
- **Open every screenshot** and confirm it shows the asserted behavior before
  writing PASS. A green exit status from `run_acceptance.sh` is an input, not a
  verdict - the script says so on success, on purpose.
- **Never relay a subagent's PASS you have not inspected yourself.** If a
  subagent reports a screenshot proves something, open that screenshot. A
  subagent's confidence is not evidence, and its context is not retrievable.
- Name the artifact per criterion. "All criteria pass, see the logs" is not a
  PASS summary.

---

## 7. Adaptations for this repository

The generic pattern was adjusted in four places. Each is a deliberate deviation.

1. **`type:*` labels instead of native issue types.** Forced: native types are
   organisation-only and this repository is user-owned. If it moves to an
   organisation, create the three types under organisation settings, backfill
   with `gh issue edit N --type Bug`, then run
   `./scripts/bootstrap-issue-labels.sh --prune-defaults` and delete the
   `type:*` family. The state machine is unchanged either way, because type was
   never part of it.

2. **Feature branch plus PR, not straight to `main`.** `main` is currently
   unprotected, but `CONTRIBUTING.md` mandates PRs and all seven historical
   changes went through one. The session opens the PR, waits for the
   **Quality gate** check in [`ci.yml`](../.github/workflows/ci.yml), and merges
   with `--squash --delete-branch`. Note that `ci.yml` has
   `paths-ignore: ['**/*.md', 'docs/**']`, so a docs-only PR gets **no** Quality
   gate run - `gh pr checks --watch` will report no checks rather than a pass.
   That is expected; do not treat it as a failure, and do not wait on it.

3. **Golden PNGs instead of a browser harness.** There is no browser or e2e
   harness a session can drive here (tier 3 above). Golden capture is the only
   route to visual evidence without a device, with the hard Ahem-font limit
   documented in section 6.

4. **No `repo:*` or `area:*` family.** Single repository, single root
   `pubspec.yaml`. The only other `pubspec.yaml` is a Mason brick hook
   (`bricks/flutter_starter_setup/hooks/`), not a shipped package. `epic:*`
   carries all the partitioning that is needed.

---

## 8. Multi-agent layer

Four roles are defined under [`.claude/agents/`](../.claude/agents/): planner,
implementer, qa, and security. Phase order, the gate table, escalation rules,
the tiebreaker order, and parallelism rules live in the `## Loop Protocol`
section of [`CLAUDE.md`](../CLAUDE.md).

The load-bearing rule: **reviewer roles file issues, they do not fix them.** QA
and security have no write access to `lib/`. A QA failure returns to the
implementer, never to the planner.

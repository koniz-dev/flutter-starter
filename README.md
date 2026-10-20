# Maintainers

This orphan branch holds everything that exists to develop **the starter
itself** (koniz-dev/flutter-starter) rather than to serve a project built from
it. `main` is what an adopter receives from "Use this template", so none of this
is on `main`; projects made from the template never see it.

## Setup

From a checkout of the repository:

```bash
git fetch origin maintainers evidence
git worktree add ../flutter-starter-maintainers origin/maintainers
../flutter-starter-maintainers/scripts/install.sh
```

`install.sh` creates the evidence worktree, links the agent roles into the
checkout's `.claude/agents/`, and writes an untracked `CLAUDE.local.md` that
imports [`process.md`](process.md). After that, a Claude Code session in the
checkout follows `main`'s `CLAUDE.md` (the code) **and** `process.md` (the
work). Update this worktree with `git -C ../flutter-starter-maintainers pull`.

## Contents

- [`process.md`](process.md): how work is tracked, verified and shipped:
  labels and states, acceptance verification, evidence, the agent loop and its
  gates.
- [`issue-workflow.md`](issue-workflow.md): the full issue workflow, with `gh`
  recipes.
- [`agents/`](agents/): the planner, implementer, qa and security roles.
- `scripts/`:
  - [`check_deliverable.sh`](scripts/check_deliverable.sh): the deliverable
    gate. It fails if `main` carries anything that only serves this process.
  - [`check_issue_refs.sh`](scripts/check_issue_refs.sh): `Refs owner/repo#N`,
    no auto-closing keywords.
  - [`check_epic_coverage.dart`](scripts/check_epic_coverage.dart): every
    tracked path on `main` maps to exactly one `epic:*`.
  - [`bootstrap-issue-labels.sh`](scripts/bootstrap-issue-labels.sh): the label
    taxonomy, the canonical epic list, and the path to epic map.
  - [`run_acceptance.sh`](scripts/run_acceptance.sh): the acceptance harness.
    It writes evidence straight into the evidence worktree.
  - [`install.sh`](scripts/install.sh): the setup above.
- [`history/`](history/): upstream-only history, namely the completed
  architecture migration plans and the script for recording the Mason demo.

Evidence lives on the separate orphan `evidence` branch; see its README.

# Issue 58 - acceptance evidence

Issue: koniz-dev/flutter-starter#58 - "the qa phase has no owner and has never
run; status-label and tiebreaker rules contradict across CLAUDE.md and
issue-workflow.md"

Shipped in PR #104 and PR #107. Verified against `main` at `08cad8d`.

## What each criterion rests on

| # | Criterion | Result | Artifact |
|---|---|---|---|
| 1 | The `qa` phase has a named owner; phase order and role files agree | PASS | [`criterion-1-qa-owner.log`](criterion-1-qa-owner.log) |
| 2 | One rule for the `status:*` label on close; closed issues match it | PASS | [`criterion-2-status-label.log`](criterion-2-status-label.log) |
| 3 | Every state has a documented exit and a role that performs it | PASS | [`criterion-3-state-exits.log`](criterion-3-state-exits.log) |
| 4 | A mechanical check rejects auto-closing keywords and requires `Refs` | PASS | [`criterion-4-check-issue-refs.log`](criterion-4-check-issue-refs.log) |
| 5 | `main` is protected with the Quality gate required | NOT DONE - `status:needs-uat` | [`criterion-5-branch-protection.log`](criterion-5-branch-protection.log) |
| 6 | Exactly one tiebreaker definition; the selector implements it | PASS | [`criterion-6-tiebreaker.log`](criterion-6-tiebreaker.log) |
| 7 | The epic list exists only in `scripts/bootstrap-issue-labels.sh` | PASS | [`criterion-7-epic-list.log`](criterion-7-epic-list.log) |
| 8 | Stale note removed, counts corrected, G4 invalid-issue route added | PASS | [`criterion-8-stale-facts.log`](criterion-8-stale-facts.log) |
| 9 | `--help` stops at the header; `--dry-run` works without `gh` | PASS | [`criterion-9-bootstrap.log`](criterion-9-bootstrap.log) |
| 10 | `./scripts/dev/audit_template.sh` exits 0 | PASS | [`criterion-10-audit_template.log`](criterion-10-audit_template.log) |

Criterion 5 is the only hand-off. The session's permission layer refuses
repository-settings writes, so the `PUT .../branches/main/protection` call could
not be made; the log records the exact payload attempted, the current
unprotected state, and the reason a human must not mark **Quality gate**
required as the criterion literally asks.

## Harness output

`./scripts/test/run_acceptance.sh 58` - all gates passed:

- [`format.log`](format.log), [`analyze.log`](analyze.log),
  [`tests.log`](tests.log), [`goldens.log`](goldens.log)

## About the PNGs in this directory

`run_acceptance.sh` copies every standing golden under
`test/acceptance/goldens/` into the evidence directory of whatever issue it is
run for. This issue changed no Dart code and no UI, so **none of the six PNGs
is evidence for any criterion here.** They were opened and inspected anyway
(they show the home screen, the two cold-start states, the startup-failure
screen, and the light/dark text-style sheets, with text rendered as opaque Ahem
blocks as always), and they are byte-identical to the committed goldens:

- [`goldens-checksums.txt`](goldens-checksums.txt) - each SHA-256 appears twice,
  once for `test/acceptance/goldens/<name>.png` and once for the copy here.

## Review note

No separate `qa` phase ran on this change. The implementer ran the self-QA
checklist from `.claude/agents/implementer.md` instead - which is the weaker of
the two paths, and is exactly the distinction criterion 1 exists to make
visible.

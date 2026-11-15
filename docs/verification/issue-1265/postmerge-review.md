# Focused postmerge QA/security: issue 1265 / PR 1276

Reviewed merged commit `dbea2426a5866533d01a06bb7dc1c73e821b1c8a`. Its tree exactly matches accepted HEAD `b5837782c4fef116cf4e57a21888cac8aeb3ada2` (`git diff --exit-code` returned 0). No actionable QA or introduced security defect found within the four-file deploy-template scope.

## Direct verification

Reran `flutter test --no-pub --reporter expanded test/tooling/deploy_base_url_test.dart` on the merged checkout: all seven tests passed. No full-suite rerun or tracked edits were performed by this review. Raw output and inspection records are in `1265-postmerge-independent.log`.

Inspected actual completed evidence files under the evidence worktree's `docs/verification/issue-1265/`: format processed 632 files with zero changes and exit 0; analyzer reported no issues and exit 0; the full host test log ends at 4,501 passed, 14 skips, `All tests passed!`, exit 0. These are completion records, not inferred successes from a runner launch.

Inspected all three criterion mappings in `1265-evidence-draft.json`: URL selection/refusal and the Vercel input map to executable local-audit output; fully uncommented workflow lint maps to actionlint output. Every mapped source artifact exists and is nonempty. Root inspection accurately describes mechanism-level verification, baseline failures, independent probes, and limits. The earlier independent review additionally exercised shell 3.2 and six baseline regression failures.

Fresh read-only GitHub queries confirmed PR 1276 is MERGED at the stated commit, with all eight accepted-head checks completed SUCCESS (Quality gate, Workflow lint, Action pins, five Strip jobs). The recorded final Quality tail independently shows 4,500 tests passed with 16 skipped, randomized order seed 20862662, coverage 96.69% meeting the 94% floor, and `No tracked file changed.` The host/CI test and skip totals differ; both actual completion summaries are retained rather than conflated. `1265-quality-job.json` is an older in-progress snapshot, not final conclusion evidence; the draft uses the final tail plus current CI snapshot.

The merged squash commit carries `Refs koniz-dev/flutter-starter#1265`; maintainer `check_issue_refs.sh --range HEAD^..HEAD` passes and confirms no auto-closing message. Fresh issue read shows OPEN, assigned to koniz-dev, exactly one status label `status:in-progress`, with `type:bug`, `epic:tooling-ci`, and `priority:P2`. This is correct before the root session publishes evidence and closes the issue. Git status remains clean.

## Scope and publication limits

No live backend, store build/signing/upload, or actual Firebase/Netlify/Vercel deployment was verified. The five shell recipes were exercised with stub Flutter in the premerge checks, and Vercel is verified at its actual workflow input. No newly added credentials or endpoints were found; URL values now flow through step environment data and the existing release guard. The existing test probes' disabled pinning is isolated to fixtures. No outbound mutations were made.

The root session retains evidence publication, unchanged-standing-golden accounting, changelog publication, final gate checks, and issue closure. This review does not claim those pending publication actions have happened.

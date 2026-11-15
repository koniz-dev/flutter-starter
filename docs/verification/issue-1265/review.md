# Independent premerge review: PR 1276

Reviewed base `a03d07d3b1246665549919163e3d8785cf929009` to accepted head `b5837782c4fef116cf4e57a21888cac8aeb3ada2` for issue 1265. Read `CLAUDE.md`, maintainer `process.md` (including G1b), the issue body, and the actual four-file diff independently of the implementer's verdict.

## Outcome

No actionable introduced defect found in the reviewed scope.

All five commented builds now receive both environment-specific URL values through step `env`, with repository variable precedence and secret fallback; the selected staging/production value goes through the existing release helper before Flutter executes. Missing or invalid selected values do not borrow the other environment's value or an inherited `BASE_URL`. Values are expanded as data rather than interpolated as shell source. The helper and pinning helper remain compatible with macOS Bash 3.2. The keystore group preserves the existing four property lines while removing repeated output redirection. Vercel's input now selects the built `build/web` directory.

Reviewed manual staging/production selection, existing production selection for push/tag workflows, repository variable/secret precedence, unrelated environment values, inherited environment state, URL quoting and shell metacharacters, adopter repositories, and the newly sourced helper's checkout-relative path. No new template-repository-only restriction or shell/platform dependency was introduced. These workflows still ship commented and do not execute their deploy paths in ordinary PR CI, so the uncommented fixtures and extracted shell probes are necessary evidence beyond green PR checks.

## Independent checks

Raw output is retained in `1265-independent-tests.log` alongside this report.

- Exact new test file on accepted HEAD: all seven tests passed with Flutter 3.50.0, using `--no-pub --reporter expanded`.
- Independent extraction of the actual five build run blocks, executed with `/bin/bash -e -o pipefail` on GNU Bash 3.2.57: 70 HEAD probes passed across both environments. Cases cover empty values, HTTP, case-insensitive/trailing-dot placeholder hosts with userinfo/port, percent-encoded placeholder hosts, trimmed HTTPS URLs with query strings, whitespace rejection, and literal command-substitution text. Each probe supplies a valid opposite-environment URL plus inherited `BASE_URL` to catch accidental fallback. Stub Flutter verifies exact arguments and no invocation on refusal. Literal `$(id)` remains literal data; no shell execution occurs.
- Baseline extraction reproduces all five builds invoking Flutter with an empty URL.
- Independently uncommented all template steps in all three deploy workflows and ran installed actionlint: exit 0, including shellcheck of the keystore group and newly sourced helper calls.
- Exact new tests against baseline workflow files in an isolated temporary package: five URL regression tests fail on `Expected: not <0>; Actual: <0>` for missing staging URL, and Vercel regression test fails on `Actual: './'`. The discovery-count control passes, as expected. Final result: one pass and six failures. This independently establishes baseline sensitivity of every regression test.

The baseline test harness initially failed before test execution because its temporary package lacked `package_graph.json`, then lacked declared assets. Those two harness failures remain in the raw log and are not regression evidence. After adding the package graph and read-only asset links, the third run executed all seven tests and produced the six expected assertion failures above.

## Limits

This review does not claim real Play Store/App Store uploads, code signing, or live Firebase/Netlify/Vercel deployment. Vercel was checked at the template input and workflow-lint level, not with credentials or a live host. Flutter calls were stubbed in focused shell probes. No full suite duplication, tracked edits, or GitHub mutations were performed. No separate pre-existing defect was reproduced that requires filing from this review.


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


# Independent final-head review: issue1347 / PR1353

Reviewed accepted `81fa4e16a5fbe2d4a4141dcb563eaf08acca7ffd` against base `7ee7aa0cc01fac2ba8510639290b9a368ea4e7eb`, the freshly fetched live acceptance criteria, maintainer process, all nine changed files, shared formatter, remaining release steps and hook environment/monorepo behavior.

**Outcome: no remaining actionable defect identified.** The five acceptance alternatives are implemented. The initial SC2034 warning is fixed by marking intentionally ignored ref fields with underscores; final warning-level shellcheck passes. The literal formatter-stub expansion and scoped SC2016 suppression are correct.

## Independent execution

Final actual stdout/stderr and exit codes: `1347-independent-resume-tests.log`. Reproducer: `1347-independent-resume-check.py`, invoked with `REVIEW_ACCEPTED=81fa4e16a5fbe2d4a4141dcb563eaf08acca7ffd`. All probes used the isolated SDK and native `/bin/bash` **3.2.57**. No full suite was duplicated.

- Current release-script fixture suite passes, exit0.
- Warning-level shellcheck passes for both hooks and changed release/changelog/test scripts, exit0.
- Four-file focused hook/setup/culture/scaffold suite: **21 tests passed**, exit0.
- Actual-base release scripts, preserving their executable bits, fail **exactly two new assertions**: format failure does not refuse before mutations, and the implicit version heading retains its comment. All other fixture assertions pass. The final log checks the exact summary line, not a substring.
- Actual accepted hook bytes pass eight independent cases with **64-character OIDs**: tag-only, deletion-only, tag/deletion mixed, branch update, branch/deletion in both orders, local tag pushed to a remote branch and empty EOF. A remote tag destination skips regardless of local name; a remote branch destination runs. Each run uses a nested monorepo and poisoned Git environment; Flutter executes from the canonical app directory with Git variables removed.
- A failing Flutter stub propagates failure through the hook. A real PTY manual invocation completes without blocking on stdin and runs Flutter.
- Actual-base hook bytes call Flutter for all three tag/deletion skip cases, independently discriminating the regression.
- Real shared formatter on a clean fixture repository with committed unformatted Dart source refuses before Step1: no Flutter call, no branch/HEAD/tracked-file changes. A correctly formatted source control reaches Step1; its failed Flutter command exits without mutation. Thus the preflight is neither a no-op nor an unconditional refusal.

The first resumed reviewer harness was invalid for base discrimination because old script snapshots lacked executable bits and a substring assertion accepted a larger failure count. It is preserved as `1347-independent-resume-first-harness.log` and is **not acceptance evidence**. The reproducer was corrected, every probe rerun, and the final raw log reports exactly two base failures and completes with `INDEPENDENT REVIEW CHECKS COMPLETE`. Earlier reviewer artifacts were preserved untouched.

## Static and platform review

The release preflight invokes the existing read-only scoped formatter before tests and release mutations, while retaining root selection, version/tag/history checks and later failure handling. Version discovery now uses the same whitespace/comment/CR/build normalization as release.sh. No new GNU-only shell constructs were introduced.

Both the PowerShell script header and scripts index explicitly require **PowerShell7+ (`pwsh`)**, satisfying the documented alternative; no WindowsPowerShell5.1 execution is claimed. The script runtime/output is unchanged, so the manual scaffold-parity workflow's payload behavior is unaffected. Reviewed that workflow's `pwsh` invocation as well as the automatic release-script and hook workflows.

Pre-commit remains a staged-tree export with path-dependency fidelity. Its header and troubleshooting now accurately name whole tracked-repository export, unrelated monorepo assets, proportional runtime and temporary disk cost. Pre-push header/docs explicitly say it tests the **working tree**, not pushed commit tips, including uncommitted changes; this avoids claiming commit attestation.

No tracked source, dependency, SDK, GitHub issue/PR or external application was mutated by this review. Temporary fixtures were cleaned up. Root HEAD remains accepted and tracked checkout is clean. Native Windows, signed store delivery and live-backend behavior are not claimed.

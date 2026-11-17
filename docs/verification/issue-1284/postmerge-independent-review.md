# Postmerge independent QA/security: issue 1284 / PR 1298

Reviewed merged main `1114622db1df919645d961a981c0fefb1ecdd9e8`. `git diff --stat a1b0bfe20b1fa9994a5de784da8d43c7fa47240d 1114622db1df919645d961a981c0fefb1ecdd9e8` is empty, independently confirming parity with the accepted premerge tree.

**Outcome: no actionable defect identified.** Reinspected phone format/normalization, URL raw-control/raw-port/host contracts, exact bounded integer conversion/parser, and login/register email/password callers. The two initial URL findings remain fixed. Auth callers continue to use unchanged email/password methods; no shipped screen uses URL/phone helpers. Integer target-rounding and signed-range policies remain explicit.

Fresh postmerge checks, using `.git/codex-issue-work/sdk-350/flutter/bin/dart` (Flutter 3.50 / Dart 3.14):

- `dart .git/codex-issue-work/1284-independent-final-probe.dart`: **90 assertions passed on VM**.
- `dart compile js .git/codex-issue-work/1284-independent-final-probe.dart -o .git/codex-issue-work/1284-postmerge-independent-probe.js`, then `node .git/codex-issue-work/1284-postmerge-independent-probe.js`: **90 assertions passed on JavaScript**.
- `dart .git/codex-issue-work/1284-independent-head-control.dart`: all **8 issue regression cases and 2 unchanged auth controls passed**.

Actual captured command stdout/stderr: `1284-postmerge-independent-tests.log`. Probe cases cover unsigned/signed/empty/zero-padded/huge ports, IPv6 and userinfo boundaries, URI query/fragment handling, C0/C1 control rejection, and percent-encoded controls. All commands exited 0. No full-suite duplication, source edits, SDK changes, or external mutations. Prior independent review and raw logs preserved.

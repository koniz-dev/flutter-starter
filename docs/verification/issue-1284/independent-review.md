# Independent adversarial review: issue 1284 / PR 1298

Reviewed actual diff `2c4da9755371f7ed56f6dbec09f73ae8eb46d863..9dd879ede07ff09e7e74eab0ac1f52c70fafe450`, all seven changed files, and adjacent auth callers / StringExtensions. No tracked edits or external mutations made.

## Findings

1. **P3: signed port spellings pass a URL syntax validator.** `lib/core/utils/validators.dart:186` checks only the already-normalized `Uri.port`. `isValidUrl('http://example.com:+80')` and `isValidUrl('http://example.com:-0')` both return true on Dart VM and compiled JavaScript. Dart normalizes these to `http://example.com` and `http://example.com:0`, respectively. Port syntax uses digits; Node's URL constructor rejects both original strings with TypeError. Therefore callers can receive true for an original URL that a browser cannot consume. Validate raw authority port spelling before normalization, with digit-only port tests including `+80`, `-0`, overflow, ordinary/default ports, and bracketed IPv6. An empty `:` is separately accepted by both Dart and Node and is not asserted invalid here. Existing base also accepts signed ports; this becomes a defect of the newly promised syntax/port contract rather than a new exploit. No current shipped screen calls this helper.

2. **P3: the documented raw-control rejection omits C1 controls.** `lib/core/utils/validators.dart:73` excludes C0 and DEL but leaves U+0080..U+009F. `isValidUrl('http://example.com/\u0085')` and the same with `\u009f` return true on VM and JavaScript, as Uri percent-encodes them. Both source API comment and docs now say raw controls are rejected without limiting that to ASCII. Either reject C1 too and test it, or explicitly narrow the documented policy to ASCII control characters. This is a contract/documentation issue, not evidence of injection or an authorization bypass.

## Independent verification

Actual captured output: `1284-independent-tests.log` in this directory.

- Flutter 3.50 / Dart 3.14: four focused test files (utility contracts, validators, JsonHelper, StringExtensions), **246 passed**. No duplicate full suite.
- Independent source probe executed on VM and compiled with `dart compile js` then executed using Node v26.7. Checked URI normalization, port edges, numeric-only/legacy host forms, percent-encoded ASCII host, IPv6 malformed suffix, raw whitespace and C1 controls; exact signed hex bounds; target-representable even values above 2^53; signed minimum; maximum/out-of-range text; very large finite doubles; fraction rejection. No integer defect found.
- Million-character malformed phone and million-leading-zero integer completed in roughly 0.1 seconds each on VM and JavaScript, without exceptions. Algorithms inspected for ambiguous nested regex quantifiers and huge BigInt parsing; significant-digit bound prevents unbounded BigInt parsing.
- Actual-base/control discrimination: standalone checks import source extracted using `git show 2c4da...`. All eight issue regression cases fail on actual base and pass on head. Unchanged ordinary auth email/password controls pass on both.
- Auth login/register use only unchanged `isValidEmail` and `isValidPassword`. Phone StringExtension delegates to the same phone method; no duplicate policy or new downstream normalization mismatch found.
- Integer conversions explicitly preserve signed 64-bit and target exactness. VM / JS differences for odd values beyond 2^53 are documented. Earlier precision loss in incoming num/JSON values cannot be recovered and is explicitly documented. Signed hex overflow no longer wrapping is consistent with the new exact-range contract.

No exploitable security finding identified. Recommend resolving the two narrow URL contract gaps before merge; no auth regression identified.

## Final-head follow-up: a1b0bfe20b1fa9994a5de784da8d43c7fa47240d

**Both findings resolved; no remaining actionable defect identified.** Reviewed the incremental source/tests/docs diff. Raw authority extraction ends before path/query/fragment, strips userinfo at its final `@`, handles bracketed IPv6 before inspecting the port suffix, requires unsigned ASCII decimal spelling and checks the numeric bound. C1 rejection is explicit in source and docs. Empty-port handling is now documented and preserves browser-compatible behavior.

Independent final commands (all exited 0; actual stdout/stderr preserved separately in `1284-independent-final-tests.log`, original raw log unchanged):

- `PATH="$PWD/.git/codex-issue-work/sdk-350/flutter/bin:$PATH" dart .git/codex-issue-work/1284-independent-final-probe.dart`
- Same SDK `dart compile js .git/codex-issue-work/1284-independent-final-probe.dart -o .git/codex-issue-work/1284-independent-final-probe.js`, followed by `node .git/codex-issue-work/1284-independent-final-probe.js`.
- Same SDK `flutter test test/core/utils/utility_contracts_test.dart --reporter expanded`: **52 tests passed**.

The independent final probe asserts **90 cases on each of VM and JavaScript**: signed port rejection; userinfo containing a colon/signed-port-like text; password plus bracketed IPv6; empty ports; ports 0/65535/65536; zero-padded ports including 10,000 leading zeroes; 10,000-digit overflow; malformed bracket suffix; hexadecimal/percent-encoded port rejection; path/query/fragment text that resembles ports; every C0 control, space, DEL and every C1 control; encoded C1 remains accepted. All 180 platform assertions passed.

This follow-up reran only the affected contract suite, not the full suite. Previous independent integer/caller review remains applicable because those methods and callers did not change. Tracked tree clean at completion. No external actions performed.

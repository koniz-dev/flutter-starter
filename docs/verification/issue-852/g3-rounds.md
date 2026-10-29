# G3 security reviews: three rounds on the realtime and redaction fixes

Each round was a read-only `security` subagent with probes against real loopback servers. Each finding was fixed under the same issue before closing.

| Round | Reviewed | Found | Fixed in |
|---|---|---|---|
| 1 | #854 (#851), #856 (#852) | redactPath still threw on non-UTF-8 escapes and raw non-ASCII; the rethrown handshake error carried the raw URL; NoOpRealtimeClient printed URL and payload | #861, #862, #863 |
| 2 | #861, #862, #863 | an apostrophe ended the URL-scrub regex early; userinfo normalised by Uri was missed; Uri.parse's FormatException quoted the URL; NoOp printed userinfo in debug | #867 (errors built from the redacted URL alone, shared `redactUrl`) |
| 3 | #867 | `ws:\\user:pass@h` and `//user:pass@h` userinfo (which dart:io sends as Basic credentials) was not found after a literal `://` | #869 (authority found as Uri finds it) |
| check | #869 | structured fuzz: 149,215 URLs that Uri.parse reads userinfo from; after redactUrl, none keeps userinfo, none throws | (redact_url_structured_fuzz_test.dart) |

Round 3 also checked, with no finding: TimeoutException carries no URL; the cancellation error; synchronous throws from the connector; post-open stream errors (dart:io messages carry no URL); 300k random strings, none making redactUrl throw.
Trade-off, not a finding: the rethrown error keeps only the inner error type, so non-secret details (an OS errno, a failed host lookup's name) are lost.

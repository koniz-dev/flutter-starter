# Issue 1308 - the URL cache stores responses that vary only on Accept-Encoding or Origin

Merged: PR 1311, squash `2346ad03c95`. Gates on `main` at `be2197da fix(network): end the realtime client with the session (#1312)`.

| Criterion | Artifact | Result |
|---|---|---|
| Anonymous GETs varying only on Accept-Encoding and/or Origin are stored and replayed | `cache_vary_test.log` (`cache_header_isolation_test.dart`, "Vary [...] is covered and the anonymous GET is reused" x4) | one transport hit for two GETs, all four variants; fail before the fix |
| Any other Vary field is still refused | same log, "Vary [...] is not represented by the URL key and is not stored" (X-Api-Key, Accept-Language, *, Accept-Encoding + X-Region, Accept) and the eviction test | pass |
| Class comment and network.md note the web caveat | `lib/core/network/interceptors/cache_interceptor.dart`, `docs/api/core/network.md` at `be2197da fix(network): end the realtime client with the session (#1312)` | stated |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0 |

No screenshots; no golden is cited.

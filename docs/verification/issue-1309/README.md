# Issue 1309 - the realtime client ends with the session

Merged: PR 1312, squash `be2197da5f6`. Gates on `main` at `be2197da fix(network): end the realtime client with the session (#1312)`.

| Criterion | Artifact | Result |
|---|---|---|
| After a session-epoch change the factory-owned client is disconnected and the next read is fresh | `realtime_session_test.log` | disconnect with and without a listener; fresh client on the next read; both fail before the fix |
| A direct override is unaffected | same log, "a direct override of the client is left to its owner" | pass |
| Docs say per session | `docs/api/core/network.md` "Provider ownership and remote closure" at `be2197da fix(network): end the realtime client with the session (#1312)` | per session; watch, not read; connect when signed in; query-token trade-off |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0 |

No screenshots; no golden is cited. Tier 3, not run: a real WebSocket server across a real logout (no backend here); the mechanism is proven at tier 1.

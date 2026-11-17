# Issue 1326 - a TLS or pinning failure reads as a connectivity problem

Merged: PR 1330, squash `18aca50`. Gates on `main` at `8b9b4a2c test(auth): the demo card fits 360dp at 2x text in every locale (#1339)`.

| Criterion | Artifact | Result |
|---|---|---|
| A `DioException` carrying a `TlsException` / `HandshakeException` maps to `BAD_CERTIFICATE` and renders the insecure-connection message | `tls_failure_mapping_test.log`: "a pinning mismatch ..." and "an untrusted certificate is an insecure connection, not a connectivity problem" assert `code == 'BAD_CERTIFICATE'` and `localizedMessage == l10n.failureInsecureConnection` | pass (both ran, none skipped) |
| A tier-1 test drives a real pinned handshake failure through the mapper | same test: a local TLS server with an openssl-generated certificate, a `SslPinning(enabled: true, fingerprints: ['AA:BB'])` adapter, the real handshake | pass; `tls_failure_mapping_test.before-fix.log` is the same test against the v5.0.1 mapper: `Actual: 'UNKNOWN_NETWORK_ERROR'` |
| A `SocketException` maps to a connection error; decided by the type of `error` | same log, "a socket error with a null message is a connection error" (`NETWORK_ERROR`); `lib/core/errors/dio_exception_mapper.dart:85-100` tests `carried is TlsException` first and `carried is SocketException` next. The older `message` substring checks remain only as a fallback for an error that carries no typed cause; a `TlsException` returns before them | pass |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0 |

No screenshots; no golden is cited.

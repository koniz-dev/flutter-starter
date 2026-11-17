# Issue 1286 - duplicate demo registration is rejected

Merged: PR 1304, squash `16f172e986e`. Gates on `main` at `2526cefb fix(release): select exported IPA artifacts without assuming Runner.ipa (#1305)`.

| Criterion | Artifact | Result |
|---|---|---|
| Registering an existing email is rejected as a conflict | `demo_auth_test.log` ("registering an existing email is a 409 and keeps the account") | throws `ServerException` with status 409 for ` Demo@Example.com `; the demo account still signs in with its own password. Fails on the tree before the merge |
| What the user sees | pre-merge review (PR 1304 body) pumped the real `RegisterScreen` in en/es/ar/vi | localized client-rejection message, no tokens written |
| Host gates (G2) | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt` | all exit 0 |

No screenshots; no golden is cited.

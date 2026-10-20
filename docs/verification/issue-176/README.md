# Issue #176 - acceptance evidence

`ApiClient`'s public API returned Dio types, so `package:dio` leaked into the
auth feature. Fixed in PR #191, merged as `07c8f27`. Everything below was run
against that commit unless the file says otherwise.

## Which artifact proves which criterion

| Criterion | Artifact |
|---|---|
| 1. `grep -rn "package:dio" lib \| grep -v "^lib/core/network/"` returns exactly one line | `criterion1-grep.log` |
| 2. `auth_remote_datasource.dart` declares no dio-typed member | `criterion2-datasource.log` |
| 3. `ApiClient` exposes a `NetworkResponse`-returning method for every verb, and `api_client_test.dart` exits 0 | `criterion3-signatures.log`, `criterion3-api_client_test.log` |
| 4. Failure behaviour unchanged for `login`, `register`, `logout`, `refreshToken` | `criterion4-before.log` (pre-change tree `7f63283`), `criterion4-after.log` |
| 5. 401 refresh path still works end to end | `criterion5-core-network.log`, `criterion5-features-auth.log` |
| 6. Import-rule guard allowlist no longer names the datasource; `test/tooling/` exits 0 | `criterion6-no-guard.log`, `criterion6-tooling.log` |
| 7. `./scripts/dev/audit_template.sh` exits 0 | `criterion7-audit_template.log` |

`analyze.log`, `format.log`, `tests.log` and `goldens.log` are the standard
`scripts/test/run_acceptance.sh` gates. All exit 0.

## Criterion 4, stated precisely

Before and after are the **same type**: `ServerException`, with `statusCode`
preserved. `criterion4-before.log` is the same new test file run against the
unmodified tree at `7f63283` (before PR #191), so "unchanged" is a measurement,
not a claim. Both runs: 4 tests, 4 passed.

## The PNGs prove nothing about this issue

`run_acceptance.sh` copies every PNG under `test/acceptance/goldens/` into this
directory. This change has no visual surface - it is a return-type refactor at
the transport boundary - so **no criterion above rests on a screenshot.**

All 13 were opened and inspected anyway, and `goldens-checksums.txt` shows each
one is byte-identical to its committed golden (13 pairs, every hash appearing an
even number of times). The run did not perturb them, so there is no golden
regression to explain.

Standing caveat that applies to all of them: `flutter test` renders text with
the Ahem font, so every glyph is an opaque block. These goldens could not show
wording even if a criterion needed them to.

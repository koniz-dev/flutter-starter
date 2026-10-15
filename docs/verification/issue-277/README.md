# Issue 277 - security guide build script passes a key nothing reads

Change: `docs/guides/security/implementation.md`, section "2. Code Obfuscation".

- The build script and the CI example pass `API_SSL_FINGERPRINTS` instead of
  `CERTIFICATE_FINGERPRINTS`, which is not in `DartDefines.values` and was
  dropped at compile time.
- The script derives `BASE_URL` from the environment argument (production or
  staging, overridable by exporting `BASE_URL`), rejects an unknown environment
  or build type, and refuses to build when `API_SSL_FINGERPRINTS` is empty.
  Pinning is on by default in both environments, so an empty list would ship an
  unpinned release.
- The shebang is now on the first line (shellcheck SC1128).
- "Step 3" points at the deployment guides that exist instead of the missing
  `docs/guides/build-and-deploy.md`.

The original criterion 2, a permanent guard in `tool/check_docs.dart`, was split
out to koniz-dev/flutter-starter#379 because it belongs to `epic:tooling-ci`.

Reproduce every log with `bash docs/verification/issue-277/evidence.sh <scratch-dir> docs/verification/issue-277`.
`<scratch-dir>/bin/flutter` must be a stub that prints its argv.

| Criterion | Artifact | Result |
|---|---|---|
| 1. No `CERTIFICATE_FINGERPRINTS` outside `docs/verification`; fingerprints use `API_SSL_FINGERPRINTS` | `criterion1-grep.txt` | PASS: the pipeline exits 1 (no match). Lines 160 and 203 use `API_SSL_FINGERPRINTS`. |
| 2. Every `--dart-define` key in the section is in `DartDefines.values` | `criterion2-define-keys.txt` | PASS: `ENVIRONMENT`, `BASE_URL` and `API_SSL_FINGERPRINTS` are all OK. The control run against `origin/main` FAILs on `CERTIFICATE_FINGERPRINTS`. |
| 3. `BASE_URL` comes from the environment argument | `criterion3-build-script-run.txt` | PASS: the script was extracted verbatim from the guide, shellcheck reports nothing, and it ran against the stub. `production` gets `https://api.example.com`. `staging` (appbundle and ios) gets `https://api-staging.example.com`. An exported `BASE_URL` wins. Unset fingerprints, `prod` and `web` each exit 1. |
| 4. The Step 3 reference exists | `criterion4-step3-link.txt` | PASS: `ls` of both deployment guides exits 0, and no reference to `build-and-deploy.md` remains. |
| 5. Gates | `format.log`, `analyze.log`, `tests.log`, `check_docs.log`; Docs check on the PR | PASS: format reports 0 changed, analyze reports no issues, and the test log shows 2849 passed with 8 skipped. `check_docs` reports OK. See below for goldens. |

## Goldens

`run_acceptance.sh 277` reported `FAIL` on one gate, acceptance goldens.
`goldens.log` shows that the single failure is
`forced_logout_acceptance_test.dart`, which is koniz-dev/flutter-starter#288.
That test has failed on `main` since #242. This change touches only a
Markdown guide, so it cannot affect the test.

The 13 PNGs here are the repository's standing goldens. Each one is
byte-identical to its counterpart in `test/acceptance/goldens/`
(`goldens-checksums.txt`). The closing session opened all 13, and no
criterion rests on them.

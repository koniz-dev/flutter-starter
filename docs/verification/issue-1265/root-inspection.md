# Root inspection of deploy-template URL validation

Reviewed accepted HEAD b5837782c4fef116cf4e57a21888cac8aeb3ada2 against base a03d07d3b1246665549919163e3d8785cf929009. Four-file change: three dormant deploy templates and the executable regression test.

All five build steps now read BASE_URL_STAGING and BASE_URL_PRODUCTION from repository variables with secret fallback, resolve the existing chosen ENV through the same release_base_url helper as build.yml, and refuse before any Flutter invocation. Mobile pinning still resolves after the URL guard. URLs travel through step environment variables and quoted shell expansion rather than direct expression interpolation inside a shell assignment. No live endpoint or credential was introduced; tests use synthetic .test URLs and disabled pinning only in the local fixture.

Read every new test assertion. The test enables real YAML steps, evaluates only their known Actions contexts, copies the actual release/pinning scripts, and executes Bash against a recording Flutter stub. It verifies both staging and production, missing/http/example.com refusal with no call, variable-only and secret-only acceptance, variable precedence and exact compile-time environment/URL. One discovery control ensures exactly five distinct builds were found. Vercel's actual parsed deployment step must use build/web.

Before editing workflows, the exact regression produced one discovery PASS and six failures: all five empty-URL commands returned exit0, plus Vercel's root directory mismatch. Original expanded Android workflow also reproduces SC2129. Fixed fully uncommented Android/iOS/Web workflows pass actionlint with no findings; expanded fixtures, command and exit0 are preserved. Keystore properties use one redirected group; the base64 write is unchanged. Root focused audit passes30 tests, including existing URL/pinning/upload examples and assertionless-test guard, with format/analyzer clean.

This verifies the starter mechanisms and dormant template syntax. No store build, signing, backend request or actual deployment was run. Full host completion, actual CI scope and independent reviewer output are recorded separately when available.

Accepted-head full host runner: format632 files unchanged, analyzer no issues, all4,501 tests pass with14 intentional golden skips (exit0). Read the actual completion summaries and independently persisted review/raw probes. No source edit followed acceptance.

Postmerge root QA: source tree parity at dbea2426a5866533d01a06bb7dc1c73e821b1c8a; reran template audit with existing release URL, upload-example and pinning tests:18 pass, format632 unchanged and analyzer clean. Read final issue state: sole koniz-dev assignee, epic:tooling-ci, one status:in-progress. All8 actual CI jobs successful, Quality random-order suite and coverage floor completed; raw tail reports96.69% against94%. No screenshot/golden evidence collected. Maintainers/evidence fetched and both0/0 beforepublication.

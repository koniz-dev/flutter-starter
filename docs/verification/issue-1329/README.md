# Issue 1329 - P3 findings from the second 2026-11-17 audit

Criterion: every box is ticked by a merged change or struck through with a reason. All 16 boxes are ticked in the issue, each naming its PR. Gates on `main` at `8b9b4a2c test(auth): the demo card fits 360dp at 2x text in every locale (#1339)`; `box_tests.log` is the targeted run at the same commit (`box-tests-head.txt`), 91 tests, all pass.

| Box | PR | Artifact |
|---|---|---|
| `_redactNestedParameters` skips an undecodable nested URL | 1332 | `box_tests.log`: nested_query_redaction_test "an undecodable nested URL is redacted whole, not skipped" |
| `_querySecret` disagrees with log redaction | 1332 | cache_header_isolation_test "/feed?redirect=https%3A%2F%2Fx%2F%3Ftoken%3Dabc names a secret and is not cached", "/feed;token=abc ..."; cache_rule_version_test |
| `destroy()` during `init()` leaves a sink open | 1335 | file_log_output_destroy_during_init_test "destroy() during init() leaves no sink open", "init() after that destroy() still opens the file" |
| No log output on production web or when the file cannot open | 1335 | `lib/core/logging/logging_service.dart:123` skips the file output on web; `docs/guides/configuration.md` documents web and an unopenable file (the criterion's documented branch) |
| Log files take the umask | 1335 | `docs/guides/configuration.md` documents desktop permissions (the criterion's documented branch) |
| Demo card title overflows at 2x Arabic on 360dp | 1331, test 1339 | demo_sign_in_card_overflow_test, all four locales; against the card without `Flexible` en, es and ar overflow (PR 1339 body) |
| `build_all.sh` production IPA fails without a team | 1334 | build_all_analyze_size_test "production on macOS an IPA that cannot be signed ...", "... an IPA that signs is kept, with no unsigned build"; `scripts-smoke.yml` "build_all.sh (production)" passed on `524ddea` (run 44116602032) |
| Summary path and `/tmp/flutter_deps.txt` | 1334 | build_all_analyze_size_test "criterion 3", "staging", "production" |
| Branding rewrites the asset-symbol setting | 1334 | setup_branding_pbxproj_test "branding leaves the Swift asset-symbol setting at YES" |
| Branding message names platforms it does not cover | 1334 | `scripts/dev/setup_branding.sh` closing message and README branding line (the criterion's "name what is covered" branch) |
| Untracked workspace `Package.resolved` | 1334 | supply_chain_pins_test "ios/macos: the workspace Package.resolved matches the project" |
| Linux needs libsecret | 1333 | `docs/guides/onboarding/getting-started.md` (libsecret) |
| Gradle checksum and mason_cli pins | 1334, 1337 | supply_chain_pins_test "the Gradle wrapper pins the distribution checksum", "every workflow that activates a pub CLI names its version", "docs activate the mason_cli version the workflows pin". A stale checksum fails the wrapper download itself, which the JDK 25 job runs on every `android/**` change; that job passed on PR 1334 with the pinned value |
| Mason prose survives `--remove-bricks` | 1333 | strip_bricks_prose_test; the five Strip jobs on PR 1333 |
| Realtime example `ref.read`s the client | 1333 | `docs/api/core/network.md` uses `ref.watch`; the Docs check passed |
| Minor: `screenName`, whitespace name, 8-character minimum | 1335, 1331, 1333 | performance_screen_name_test "a \"State\" inside the screen name is kept"; auth_form_keyboard_test "register a whitespace-only name is required, not too short" (named in `../issue-1327/auth_form_keyboard_test.log`; the parallel reporter here prints only some names, all 91 pass); `docs/guides/onboarding/getting-started.md:214` documents the minimum |
| Host gates (G2) | - | `audit_template.log`, `epic.log`, `deliverable.log`, `refs.log`, `summary.txt`, all exit 0 |

No screenshots; no golden is cited.

# Independent adversarial review — issue 1281 / PR 1295

Reviewed base `1cb05ae13b6946bc6c12e0304ab63c3dfbaf0252` through head `b95d0a61038aecc9827794560dddbba23843e187` on `codex/fix-preference-value-types`. Fresh review of the complete four-file diff, without relying on the implementer's verdict. Read CLAUDE.md, maintainers/process.md and the issue acceptance criteria in 1281-live.json.

## Verdict

No actionable introduced correctness or security defect found. Suitable to merge subject to the owner's current-head CI and host gates. This review did not run those full gates and makes no device/backend claim.

## Adversarial assessment

- `StorageService.getString` reads the same preferences cache through `get`, explicitly preserves missing/null and all valid strings (including empty and Unicode), and converts non-string values into a coded `CacheException`. It neither coerces nor deletes stored values. The exception does not include the key or stored contents, reducing accidental payload disclosure in downstream error messages.
- Checked every production getString caller: locale selection catches Exception and resolves the platform locale; auth and tasks convert the read failure through their existing cache-error paths; feature flags map exceptions to failures; HTTP cache reads already catch Object and return a miss. Migration version reads fail closed before mutations. No caller requiring the former TypeError behavior was found except the intentionally idempotent legacy reader, which this diff adapts.
- The legacy reader skips only the explicitly coded wrong-type CacheException, plus its existing TypeError compatibility path for older/custom stores. Thus a previously converted `List<String>` does not brick a retry. Other CacheExceptions, including those with no code, propagate: no false success/schema advancement over unreadable legacy tags. Encoded lists on string-only secure stores remain unchanged. Skipping other wrong primitive types for user_tags is unchanged from the former broad TypeError behavior.
- Migration writes/removes still require success; a rejected mutation prevents the final stamp. Existing rejected-write tests cover all migration mutation keys, preservation of rename sources on rejected destination writes, and subsequent recovery. Independent real-SharedPreferences probe rejects the final v2 stamp after tags have converted, then retries successfully with the same list preserved. Another probe injects an uncoded read failure after a rename, verifies v1 and original tags remain, then recovers without losing the renamed username. This migration is resumable, not transactional; earlier completed operations can remain after a later failure, as before.
- The new tasks widget test uses the real screen, repository, datasource and preference adapter. It verifies settled CacheFailure UI/retry text, no spinner, a rejected create preserving the original blob, then successful refresh after explicit repair. This proves recovery after storage repair; retry alone intentionally cannot repair arbitrary data.
- The new startup test calls real main and asserts MyApp, absence of StartupFailureApp, Vietnamese device locale, and preservation of the corrupt language preference. This is host-widget evidence, not real-device rendering evidence.
- Other typed getters (`getInt`, `getBool`, `getDouble`, `getStringList`) retain their existing wrong-type behavior. That is outside the string-read issue and unchanged; no generalized typed-storage claim is made.

## Independent execution

Actual output: `1281-independent-tests.log`. SDK: repository-local sdk-350, Flutter 3.50 / Dart 3.14. No tracked file was edited, no global SDK changed, no outbound mutation made.

1. Focused final-head run: **109 tests passed** across wrong_preference_type_test, storage_service_test, migration_v1_to_v2_test, migration_rejected_write_test, migration_read_failure_test, startup_reachability_test. No duplicate full-suite run.
2. Three independent probes in `1281-independent-probes_test.dart`: **3 passed** (string contract/redacted coded error; uncoded read failure plus recovery; real preferences retry after rejected final stamp).
3. Isolated base archive counterfactual: copied final test files onto the exact base snapshot and ran from the snapshot CWD, reusing the same dependency configuration/SDK. **All six wrong-type regression cases fail on base**: int, bool, double, List<String>, real tasks screen, real main locale. Tasks fails with the original TypeError and pumpAndSettle timeout; startup fails to reach MyApp. This confirms the tests detect the reported defect.
4. The seventh added case, generic migration read-failure preservation, **passes on base as well**. It is a compatibility/safety control for the changed catch logic, not an independently red-on-base regression. Existing idempotency tests exercise why swallowing only the new coded mismatch is necessary.

The log also contains one incidental extra HEAD control invocation using snapshot test paths from the main CWD; it is explicitly annotated and is not cited as base evidence. The actual base run uses the isolated snapshot as CWD and its stack traces resolve the old StorageService line 90.

## Final-head addendum

Final reviewed head: `fccc062991fbe1f7e2661cbe45c6bf225baba06a`. Inspected the complete delta from the initial review head: the sole change is returning `await super.getString(key)` in the test-only unreadable-storage fixture to satisfy its async-return lint. No production delta. Independently reran all six tests in wrong_preference_type_test.dart on this final head: **6 passed**; actual output appended to the same independent tests log. The initial 109-test and three-probe results still cover the unchanged production code. Verdict unchanged: no actionable introduced defect found.

## Strip-placement correction and final re-review

The earlier review missed an introduced template-stripping regression: the task widget test lived under `test/core/storage`, so `--remove-tasks` retained imports of the removed task feature. CI exposed this at fccc062991f (job 133466797024; root captured 1281-strip-before.log). The initial no-defect verdict was incomplete on that surface.

Inspected final head `30b60e2724b602388fec2ffca56854d2611ba429`. The fix moves the task widget test to `test/features/tasks/presentation/screens/wrong_preference_type_test.dart`, which the strip already removes with task tests. Independently compared the moved test body byte for byte against fccc: identical, including preservation, CacheFailure UI, no-spinner and repair/refresh assertions. Core fixture imports are now exclusively core, shared preferences and flutter_test. No production change.

Independent verification on this final head, actual output appended to 1281-independent-tests.log:

- Both final regression files: **6 passed**.
- Fresh isolated `git archive HEAD` with the existing dependency configuration and local 3.50 SDK: `dart run tool/strip_sample_features.dart --apply --remove-tasks --force` **exit 0**. Its forbidden-reference guard passed. `--force` only bypasses the absent-git archive's working-tree safety check; it does not disable the forbidden-reference guard.
- Confirmed the snapshot removed `lib/features/tasks` and the moved task widget fixture, while retaining the core regression file.
- Ran the retained core regression fixture in that stripped snapshot: **5 passed**. No full suite duplicated.

Final verdict: the CI-reported introduced placement defect is fixed; no remaining actionable introduced storage/security/correctness defect found in the final diff. Current-head CI and host gates remain the owner's responsibility.

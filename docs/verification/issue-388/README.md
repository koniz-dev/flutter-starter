# Issue 388 - freerasp 8.2.4 so Android release builds survive AGP 9

Change:

- `pubspec.yaml`: `freerasp: ^6.1.1` becomes `^8.2.4`. `pubspec.lock` changes
  only the freerasp entry. The SDK-pinned churn a local `pub get` produces is
  koniz-dev/flutter-starter#338 and is not committed.
- `FreeRaspServiceImpl`: `attachListener` returns a `Future` in 8.x, and it is
  now awaited. That is the only API change the starter meets.
- New `test/core/security/infrastructure/freerasp_service_impl_test.dart`. It
  drives the service through freerasp's real Dart API with its method and
  event channels mocked, and checks that a threat freeRASP reports (the wire
  code for `Threat.debug`) reaches `onThreatDetected` as
  `SecurityThreat.debugger`.

| Criterion | Artifact | Result |
|---|---|---|
| 1. freerasp ^8.2.4; `lib/core/security/` compiles and keeps its behaviour; the security suite passes; the API change is covered by a test | `criterion1-on-8.2.4.log`, `criterion1-on-6.12.0.log`, `analyze.log` | PASS: 3/3 on both versions, so the behaviour is unchanged. The new test exercises the awaited `attachListener`. |
| 2. The resolved package's consumer rules carry no `-flattenpackagehierarchy` | `criterion2-consumer-rules.txt` | PASS. 6.12.0 declares `consumerProguardFiles 'consumer-rules.pro'`, which contains the rule. 8.2.4 has no consumer rules; the rule moved to `proguard-rules.pro` (`proguardFiles`, the library's own build only). |
| 3. With #329's toolchain, a `build.yml` `platform=android` release build passes `:freerasp:exportReleaseConsumerProguardFiles` | `criterion3-build-yml-release.log` | PASS: run 38775610398 on a temporary branch with this commit plus the #329 toolchain commit, JDK 17, `assembleRelease`, `Built build/app/outputs/flutter-apk/app-release.apk`. Control: run 38772175320, the toolchain alone with freerasp 6.12.0, failed in that task. |
| 4. Audit, plus security phase | `format.log`, `analyze.log`, `tests.log` | PASS: 0 changed, no issues, 2871 passed. Security phase: see the closing comment. |

Found while testing, and already tracked: the shipped placeholder signing hash
`'AKa...'` fails freeRASP's Android config check in the `AndroidConfig`
constructor, so on Android `startProtection()` throws before the listener is
attached. This is the same on 6.12.0 and 8.2.4, and it is
koniz-dev/flutter-starter#317. The new test therefore targets iOS.

Gates: `run_acceptance.sh 388` reported FAIL on one gate, acceptance goldens.
Its only failure is `forced_logout_acceptance_test`
(koniz-dev/flutter-starter#288), which already fails on `main`. The 13 PNGs
are the repository's standing goldens, byte-identical to
`test/acceptance/goldens/` (`goldens-checksums.txt`). The closing session
opened all 13, and no criterion rests on them.

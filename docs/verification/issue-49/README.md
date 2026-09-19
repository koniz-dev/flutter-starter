# Issue 49 - Android release manifest INTERNET permission

Verification evidence for koniz-dev/flutter-starter#49, against the merged fix
on `main` (PR #66, commit `7d98ca4`).

## Correction to the issue's premise

The issue states that the merged **release** manifest had no network permission
and that "login is permanently broken in release only". **That part is wrong.**

A release APK built from the parent commit `a26ab91` (before the fix) already
contains `android.permission.INTERNET` - see
[`baseline-release-manifest.xml`](baseline-release-manifest.xml) line 19. It
arrives through manifest merge from an **Android library (AAR) manifest** in the
dependency graph, not from any Flutter plugin's own
`android/src/main/AndroidManifest.xml`. The issue only surveyed the latter,
which is why it missed this. The co-occurring merged permissions
(`ACCESS_NETWORK_STATE`, `USE_BIOMETRIC`, `USE_FINGERPRINT`, Google's
`READ_GSERVICES`) and the `com.huawei.hwid` package query all point at the
Talsec AAR that `freerasp` pulls in
(`com.aheaditec.talsec.security:TalsecSecurity-Community-Flutter:14.0.1`,
declared in `~/.pub-cache/hosted/pub.dev/freerasp-6.12.0/android/build.gradle`).
That attribution could not be confirmed against the AAR itself - Maven Central
is not reachable from this environment - so treat the specific library as
likely, not proven. What *is* proven is that the permission came from outside
this repository's own manifests.

The fix is still correct and worth keeping: an app must declare the permissions
its own traffic needs, rather than inherit them from a dependency that an
adopter of this template may well remove (`freerasp` is exactly the kind of
thing `tool/strip_sample_features.dart` users drop). The commit message on
`7d98ca4` repeats the issue's incorrect impact claim; this file is the
correction of record.

## How the merged manifests were obtained

No Android SDK or JDK exists on this machine (`flutter doctor` reports
"Unable to locate Android SDK"), so `flutter build apk --release` and
`aapt dump permissions` cannot run locally. Instead:

1. `gh workflow run build.yml --ref main -f platform=android -f environment=development`
   - run [35433291072](https://github.com/koniz-dev/flutter-starter/actions/runs/35433291072),
   head SHA `7d98ca4` (the merged fix). Its `Build APK` step runs
   `flutter build apk`, which is a release build, and uploads
   `build/app/outputs/flutter-apk/app-release.apk`.
2. The same workflow on a throwaway branch at the parent commit `a26ab91`
   - run [35433621227](https://github.com/koniz-dev/flutter-starter/actions/runs/35433621227).
   The branch was deleted afterwards.
3. Both APKs downloaded with `gh run download`; SHA-256 in
   [`apk-sha256.txt`](apk-sha256.txt).
4. `AndroidManifest.xml` inside each APK is binary AXML. It was decoded with
   [`decode_axml.py`](decode_axml.py), committed here so the two XML files can
   be regenerated and checked rather than taken on trust:
   `python3 decode_axml.py app-release.apk`.

The decoded files are the **merged** release manifests (the APK manifest is the
merger's output after variant and library merge), which is the artifact
criterion 2 asks for.

## Files

| File | What it is |
|---|---|
| [`merged-release-manifest.xml`](merged-release-manifest.xml) | Release manifest decoded from the post-fix APK (`main` @ `7d98ca4`) |
| [`baseline-release-manifest.xml`](baseline-release-manifest.xml) | Same, from the pre-fix APK (`a26ab91`) |
| [`merged-manifest.diff`](merged-manifest.diff) | Unified diff of the two: the only change is INTERNET moving ahead of the library-merged block |
| [`permissions.txt`](permissions.txt) | Every `uses-permission` in both merged manifests |
| [`source-manifests.txt`](source-manifests.txt) | The commit diff plus the untouched debug and profile source-set manifests |
| [`apk-sha256.txt`](apk-sha256.txt) | Provenance of the two downloaded APKs |
| [`audit_template.log`](audit_template.log) | `./scripts/dev/audit_template.sh`, `exit: 0` |
| [`format.log`](format.log) / [`analyze.log`](analyze.log) / [`tests.log`](tests.log) | `scripts/test/run_acceptance.sh 49 --no-goldens` |

Goldens were skipped deliberately (`--no-goldens`): this change has no visual
surface, and copying unrelated PNGs in would invite a PASS row that proves
nothing.

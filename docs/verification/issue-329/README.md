# Issue 329 - Android builds on JDK 25 (Gradle 9.3.1, AGP 9.1.0, Kotlin 2.4.0)

Change, matching what `flutter create` writes on Flutter 3.47:

- `gradle-wrapper.properties`: Gradle 8.14 becomes 9.3.1.
- `settings.gradle.kts`: AGP 8.11.1 becomes 9.1.0, and Kotlin 2.2.20 becomes
  2.4.0.
- `gradle.properties`: `android.newDsl=false` and `android.builtInKotlin=false`,
  the two flags the template carries.
- `app/build.gradle.kts`: `android { kotlinOptions { jvmTarget } }`, which
  Kotlin 2.4 rejects, is replaced by the top-level
  `kotlin { compilerOptions { jvmTarget = JVM_17 } }`.
- `android/.gitignore`: ignores `/build/`, because Gradle 9 writes
  `reports/problems/problems-report.html` there on every build.

The release build also needed freerasp 8.2.4 (koniz-dev/flutter-starter#388,
merged first). The permanent JDK 25 CI leg and the version-floor check are
koniz-dev/flutter-starter#387.

| Criterion | Artifact | Result |
|---|---|---|
| 1. Gradle 9.3.1 or newer, AGP 9.1.0 or newer, Kotlin 2.4.0 or newer | `criterion1-versions.txt` | PASS. The file also quotes Flutter's floors (9.1.0, 9.0.1, 2.3.20) and template targets (9.3.1, 9.1.0, 2.4.0) from the SDK sources. |
| 2. A JDK 25 build passes with no "will soon be dropped" warning | `criterion2-jdk25-ci.log`; `before-jdk25.log`; `criterion2-local-jbr25-attempt.log` | PASS, **on CI rather than on this machine**. Run 38778710010 (Temurin 25.0.4) built the release APK, a stricter build than the debug APK the criterion names, with 0 "soon be dropped" warnings. It ran on a throwaway branch identical to this one except for `java-version: '25'` in build.yml; that branch has been deleted. Locally, on `main`, JBR 25.0.3 fails with "incompatible with Gradle 8.14" (`before-jdk25.log`). On this branch, JBR 25 gets past Gradle and Kotlin and stops only at installing NDK 28.2: "No space left on device", with under 1 GB free. |
| 3. The JDK 17 path CI uses still builds | `criterion3-jdk17-ci.log` | PASS: run 38778654206 on this branch built the release APK with 0 warnings. |
| 4. A fresh build leaves `android/gradle.properties` unmodified | `criterion4-no-migrator-rewrite.txt` | PASS: `flutter build apk --config-only` leaves `git status android/` empty. The control on `main` shows the migrator appending both flags. |
| 5. Audit | `format.log`, `analyze.log`, `tests.log` | PASS: 0 changed, no issues, 2871 passed. |

Gates: `run_acceptance.sh 329` reported FAIL on one gate, acceptance goldens.
Its only failure is `forced_logout_acceptance_test`
(koniz-dev/flutter-starter#288), which already fails on `main`. The 13 PNGs
are the repository's standing goldens, byte-identical to
`test/acceptance/goldens/` (`goldens-checksums.txt`). The closing session
opened all 13, and no criterion rests on them.

# Criterion 3 - release signing, both directions, in real CI

Gradle does not run in this session (`java -version` -> "Unable to locate a Java
Runtime", no Android SDK), so both halves were driven by dispatching
`.github/workflows/build.yml`, which runs `flutter build apk` (release by
default) on `ubuntu-latest`.

## A. With `android/key.properties`: signed with the release key

Run [36134640833](https://github.com/koniz-dev/flutter-starter/actions/runs/36134640833)
on `main` at `dbee1c6` - **success**.

The workflow follows the exact recipe `deploy-android.yml` documents: write a
keystore under `android/`, then a `key.properties` whose `storeFile` is a path
*relative to `android/`*. That relative resolution is the thing that was broken;
a bare `file(...)` in `android/app/build.gradle.kts` would have resolved it
against `android/app/`.

```
Generate throwaway release keystore
  keytool -genkeypair -v \
    -keystore android/ci-throwaway-keystore.jks \
    -storetype JKS \
    -storepass ci-throwaway -keypass ci-throwaway \
    -alias ci-throwaway \
    -keyalg RSA -keysize 2048 -validity 30 \
    -dname "CN=CI Throwaway, OU=flutter-starter, O=flutter-starter, C=US"
  Generating 2,048 bit RSA key pair and self-signed certificate (SHA256withRSA)
    for: CN=CI Throwaway, OU=flutter-starter, O=flutter-starter, C=US
  [Storing android/ci-throwaway-keystore.jks]

  { storeFile=ci-throwaway-keystore.jks
    storePassword=ci-throwaway
    keyAlias=ci-throwaway
    keyPassword=ci-throwaway } > android/key.properties
```

The APK artifact was downloaded and its signer certificate read locally. This is
the decisive check: a debug-signed artifact carries
`CN=Android Debug, O=Android, C=US`.

```console
$ gh run download 36134640833
$ strings -a app-release.apk | grep -c "Android Debug"
0
$ strings -a app-release.apk | grep -c "CI Throwaway"
2

$ python3 extract_cert.py app-release.apk    # scans the APK Signing Block for
                                             # DER SEQUENCEs openssl can parse
--- X.509 certificate found at offset 73127148 ---
subject=C=US, O=flutter-starter, OU=flutter-starter, CN=CI Throwaway
issuer=C=US, O=flutter-starter, OU=flutter-starter, CN=CI Throwaway
sha256 Fingerprint=BB:22:37:B7:74:FD:53:5D:46:AD:15:D2:48:29:7A:62:A5:02:92:A3:BB:13:5A:AA:CA:59:E9:02:DB:D8:64:97
```

Zero occurrences of the debug identity, two of the release identity (v2 and v3
signature blocks). The APK is signed by the key `key.properties` named.

### Defect found in my own workflow step, fixed in this PR

The `Print APK signer certificate` step I added to `build.yml` read
`META-INF/*.RSA`, which is **v1 (JAR) signing only**. This APK carries v2/v3
signatures, which live in the APK Signing Block ahead of the central directory,
so the step's loop matched nothing and the step printed a single line:

```
Print APK signer certificate    APK: build/app/outputs/flutter-apk/app-release.apk
```

A green step that verified nothing - the precise failure mode `CLAUDE.md` warns
about for the Patrol job. Rewritten to use `apksigner verify --print-certs` from
`$ANDROID_HOME/build-tools`, and to `exit 1` both when no certificate DN is
printed and when the DN contains `CN=Android Debug`. The local extraction above
is what actually proves criterion 3 for this run; the rewritten step is so the
next run proves it by itself. **The rewritten step has not itself been executed
in CI** - it ships unrun.

## B. Without `android/key.properties`: fails loudly

Run [36135666505](https://github.com/koniz-dev/flutter-starter/actions/runs/36135666505)
on a throwaway branch `ci/62-no-keystore-probe` (identical to `main` except the
keystore-generation step was deleted; branch deleted after the run) -
**failure**, as intended. Before this change the same build would have succeeded
and produced a debug-signed AAB that Play Console rejects.

```
Build APK   Release signing is not configured, so this build would produce an
Build APK   unsigned (previously: debug-signed) artifact. Refusing.
Build APK
Build APK   Create android/key.properties:
Build APK       storeFile=upload-keystore.jks   # relative to android/, or absolute
Build APK       storePassword=...
Build APK       keyAlias=...
Build APK       keyPassword=...
Build APK
Build APK   Generate a keystore with:
Build APK       keytool -genkey -v -keystore android/upload-keystore.jks \
Build APK         -keyalg RSA -keysize 2048 -validity 10000 -alias upload
Build APK
Build APK   In CI see the "Setup Android keystore" step in
Build APK   .github/workflows/deploy-android.yml.
Build APK
Build APK   To build an UNSIGNED release anyway - local smoke tests only, the
Build APK   artifact cannot be installed or uploaded - pass:
Build APK       flutter build apk --release -PallowUnsignedRelease=true
Build APK
Build APK   BUILD FAILED in 2m 25s
Build APK   Gradle task assembleRelease failed with exit code 1
```

The check runs from `gradle.taskGraph.whenReady` and only fires for
`assemble*Release` / `bundle*Release` / `package*Release`, so `flutter test`,
`flutter analyze` and every debug build still work on a machine with no
keystore - confirmed by `./scripts/dev/audit_template.sh` exiting 0 and by the
Quality gate and three Strip jobs passing on PR #132.

`-PallowUnsignedRelease=true` is a deliberate, explicit escape hatch for local
smoke builds. It is an opt-in flag, not a silent fallback: the default path
fails.

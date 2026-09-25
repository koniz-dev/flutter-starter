# Issue 153 - APK signer check accepted only a v1-only label

Verified against `main` after PR #186 merged as `f4e9333`.

The fix moved the guard out of the inline `run:` block in
[`build.yml`](../../../.github/workflows/build.yml) into
[`scripts/ci/verify_apk_signer.sh`](../../../scripts/ci/verify_apk_signer.sh),
matched the `certificate DN:` **value** instead of apksigner's scheme label,
and added a `Number of signers` assertion.

## Criterion map

| Criterion | Result | Artifact |
|---|---|---|
| 1. Dispatched `Build (Manual)` android run on `main` succeeds and prints the DN of a v2-signed APK | PASS | [`run-36143567980-main-pass.log`](run-36143567980-main-pass.log) - [run 36143567980](https://github.com/koniz-dev/flutter-starter/actions/runs/36143567980) |
| 2a. A debug-signed APK still fails the step | PASS | [`run-36141948275-probe-debug-signed.log`](run-36141948275-probe-debug-signed.log) - [run 36141948275](https://github.com/koniz-dev/flutter-starter/actions/runs/36141948275) |
| 2b. An APK whose certificate cannot be read at all still fails the step | PASS | [`run-36142784856-probe-unsigned.log`](run-36142784856-probe-unsigned.log) - [run 36142784856](https://github.com/koniz-dev/flutter-starter/actions/runs/36142784856) |
| 3. Every signature scheme this project can emit is accepted | PASS | [`replay.log`](replay.log) cases 1-3, plus criterion 1's real v2 run |
| 4. `Number of signers` is asserted to be at least 1 | PASS | [`replay.log`](replay.log) cases 6 and 8; real unsigned APK in criterion 2b |
| 5. `./scripts/dev/audit_template.sh` exits 0 | PASS | [`format.log`](format.log), [`analyze.log`](analyze.log), [`tests.log`](tests.log) |

## What each run shows

### Baseline, before the fix

[`run-36136950123-before-the-fix.log`](run-36136950123-before-the-fix.log) is
the run that produced this issue, on `main` at `875113e`. apksigner reported
`Number of signers: 1` and
`V2 Signer: certificate DN: CN=CI Throwaway, OU=flutter-starter, O=flutter-starter, C=US`,
and the step still exited 1 with `apksigner printed no certificate DN.` - the
pattern it grepped, `Signer #1 certificate DN:`, is emitted only for v1/JAR
signing.

### Criterion 1 - the pass direction

Run 36143567980, `Build (Manual)`, `platform=android`, `environment=production`,
ref `main` at `f4e9333`. The `Build Android` job is green. The guard step reads:

```
APK: build/app/outputs/flutter-apk/app-release.apk
Using: /usr/local/lib/android/sdk/build-tools/37.0.0/apksigner
Verified using v1 scheme (JAR signing): false
Verified using v2 scheme (APK Signature Scheme v2): true
Number of signers: 1
V2 Signer: certificate DN: CN=CI Throwaway, OU=flutter-starter, O=flutter-starter, C=US
Signers: 1
Certificate DN(s):
  CN=CI Throwaway, OU=flutter-starter, O=flutter-starter, C=US
OK: build/app/outputs/flutter-apk/app-release.apk is signed by 1 non-debug signer(s).
```

Same APK shape as the baseline, opposite verdict.

### Criterion 2 - the fail directions

Both ran on the throwaway branch `chore/153-signer-probe` (branched off the fix,
deleted afterwards). That branch changed only which APK gets built; the
`Print APK signer certificate` step and the script it calls were byte-identical
to what merged to `main`. Both APKs are genuine Flutter outputs, not
hand-crafted zips.

- **Debug-signed** (run 36141948275): `flutter build apk --debug`, no
  `key.properties`. apksigner printed
  `V2 Signer: certificate DN: C=US, O=Android, CN=Android Debug` and the step
  exited 1 with `APK is DEBUG-signed.` Worth noting that this debug APK is
  itself v2-only, so the old v1-shaped pattern would have "caught" it for
  entirely the wrong reason.
- **Unsigned** (run 36142784856): `flutter build apk --release
  -PallowUnsignedRelease=true`, the escape hatch
  `android/app/build.gradle.kts` documents. apksigner printed
  `DOES NOT VERIFY / ERROR: Missing META-INF/MANIFEST.MF` and exited 1; the
  step exited 1 with `apksigner could not verify ...: no readable certificate.`

[`run-36141960926-probe-attempt-gradle-refused.log`](run-36141960926-probe-attempt-gradle-refused.log)
is the first attempt at the unsigned case, kept because it is part of the
record: `build.gradle.kts` refuses to produce an unsigned release at all, so
that run died inside Gradle and never reached the guard. It proves nothing
about the guard.

### Criteria 3 and 4 - the branches CI cannot reach

[`replay.log`](replay.log) is the output of
[`replay/replay.sh`](replay/replay.sh), which runs the **real, unmodified**
`scripts/ci/verify_apk_signer.sh` with `APKSIGNER` pointed at a stub that
replays a recorded transcript. Eight cases, all as expected:

| # | Transcript | Guard |
|---|---|---|
| 1 | v2-only (verbatim from run 36136950123) | accepts |
| 2 | v1/JAR, `Signer #1 certificate DN:` | accepts |
| 3 | v3 and v3.1, `V3 Signer:` / `V3.1 Signer:` | accepts |
| 4 | debug-signed | rejects: DEBUG-signed |
| 5 | unsigned, apksigner exits 1 | rejects: no readable certificate |
| 6 | verifies but `Number of signers: 0` | rejects: unsigned |
| 7 | verifies but prints no DN | rejects: no certificate DN |
| 8 | verifies but prints no signer count | rejects: cannot confirm signed |

Be precise about what this is and is not. Cases 1, 4 and 5 correspond to real
CI runs above and merely agree with them. Cases 2, 3, 6, 7 and 8 are the value
this file adds: no APK this project can build produces a v1 or v3 label, and a
real unsigned APK makes apksigner exit 1 before any signer count is printed, so
those branches are unreachable from CI. They are replayed against recorded
output instead. Only case 1 is verbatim tool output; the other seven
transcripts are hand-written in apksigner's format, so they test the guard's
parsing, not apksigner's behaviour.

### Criterion 5 - the local gate

`./scripts/test/run_acceptance.sh 153 --no-goldens`, exit 0, on `main` at
`e9e80eb`. Format, analyze and the full unit/widget suite are in
[`format.log`](format.log), [`analyze.log`](analyze.log) and
[`tests.log`](tests.log). Run with `--no-goldens` deliberately: this change is
a shell script and a workflow step, nothing renders, and the golden layer would
have copied six standing PNGs in that prove nothing about it. There are
therefore no screenshots in this directory and no criterion rests on one.

## Label versus value

The guard matches the DN **value**, not the scheme label. apksigner names each
signer after the scheme that verified it, and the set of names grows with the
format: `Signer #1` (v1/JAR), `V2 Signer:`, `V3 Signer:`, `V3.1 Signer:`,
`Source Stamp Signer`. Enumerating them is what broke this twice - a list of
labels is a list of the schemes someone happened to think of, and it fails
closed on a correctly signed APK the moment the toolchain emits a new one. The
DN line's shape, `<anything> certificate DN: <value>`, has been stable across
every scheme, so the guard keys on that and requires a non-empty value.

The relaxation risk that comes with a looser pattern is covered separately:
`Number of signers` must be at least 1, apksigner itself must exit 0, and no DN
may read `CN=Android Debug`. Runs 36141948275 and 36142784856 are what show the
guard can still fail.

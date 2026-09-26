# Issue 135 - the bundled-.env guard now runs on the release-build path

`tool/check_env_assets.dart` ran in `scripts/dev/audit_template.sh` and, through
`test/tooling/check_env_assets_test.dart`, in `flutter test`. Neither is the
path that produces an artifact, and the case that matters most - a developer who
adds `- .env` to the asset list locally and never commits it - is invisible to
both, because CI never sees the edit.

Shipped in PR #236, merged as `b92240b`.

## Evidence

| File | What it is |
|---|---|
| `criteria-3-4-build-path.log` | Four runs of `./scripts/ci/build_all.sh development`: `origin/main`'s copy with `- .env` declared, this change's copy with the same pubspec, the acknowledged entry, and the committed pubspec |
| `criterion-2-workflow-steps.log` | The step list of every job in the three deploy workflows, read back from the YAML, plus the guard step in context |
| `format.log`, `analyze.log`, `tests.log` | `./scripts/test/run_acceptance.sh 135 --no-goldens` |

`--no-goldens`: shell script, workflow YAML and two guides. Nothing renders,
there is no PNG here, no criterion rests on a golden, and the standing goldens
under `test/acceptance/goldens/` were neither copied here nor touched.

**Read the "No Android SDK" lines correctly.** This machine has no Android SDK,
so every run that gets *past* the guard stops at the Android build with
`[!] No Android SDK found`. That is a pre-existing property of the environment,
identical before and after this change - the `A-before` run in the log shows
`origin/main`'s script hitting it too. It is why no run here reaches an
artifact, and it is not evidence of anything about this change.

## Criterion 1 - the guard runs before the build step in build_all.sh, and aborts it

PASS. `criteria-3-4-build-path.log`, sections `A-before` and `A-after`, same
pubspec (`- .env` added to the asset list) and the same command:

```
A-before   (origin/main's script)        A-after   (this change)
Building for environment: development    Building for environment: development
Cleaning previous builds...              Cleaning previous builds...
✓ Cleaned                                ✓ Cleaned
                                         Checking for bundled secrets files...
                                         SECURITY: a secrets file is bundled as a Flutter asset.
                                           pubspec.yaml:174  - .env  [environment file]
Building Android...                      ✗ Refusing to build: a secrets file would be bundled...
[!] No Android SDK found.
exit: 1                                  exit: 1
```

Before, the script walked straight into the build. After, it never reaches
`Building Android...` at all. The guard sits after `flutter pub get` - `dart
run` needs the `.dart_tool/package_config.json` that `flutter clean` has just
deleted - and before every build step.

## Criterion 2 - the guard is a step in all three deploy workflows, before the build

PASS, structurally. `criterion-2-workflow-steps.log` lists every step of every
job, read back out of the YAML on `main`:

| Workflow | Job | Guard position |
|---|---|---|
| `deploy-android.yml` | `deploy` | step 6, after `Determine environment`, before the (commented) `Build App Bundle` |
| `deploy-ios.yml` | `deploy` | step 7, after `Setup Xcode` and `Determine environment`, before the (commented) `Build IPA` |
| `deploy-web.yml` | `deploy-firebase` | step 5, before the (commented) `Build Web` |
| `deploy-web.yml` | `deploy-netlify` | step 5, same |
| `deploy-web.yml` | `deploy-vercel` | step 5, same |

The step runs `dart run tool/check_env_assets.dart` - the same command as the
other three call sites, shown side by side in the log's `grep` section. It is
placed after every step that writes into the working tree (the keystore and
certificate steps on Android and iOS), so it sees the tree the build will see
rather than the tree the checkout produced.

**Not done: no live deploy run.** These are deploy workflows and this session is
not permitted to dispatch one, so the step is verified by its position and its
command, not by a green job. The command itself is exercised four times in
`criteria-3-4-build-path.log`, in both the failing and the passing direction.

## Criterion 3 - demonstrated both ways

PASS.

**Failing half:** section `A-after` above. Exit 1, and
`ls build/app/outputs build/web` reports `No such file or directory` for both -
no artifact. `flutter clean` had just emptied `build/`, and the script aborted
before anything could refill it.

**Passing half:** section `C`, the committed pubspec with
`git status --porcelain pubspec.yaml` empty. The script prints
`Checking for bundled secrets files...` then
`✓ No unacknowledged secrets file in the asset list` and proceeds to
`Building Android...` - the same point `A-before` reached without a guard at
all. Behaviour is unchanged apart from the two lines the guard prints.

## Criterion 4 - the inline `# env-asset-ack:` exception still passes

PASS. Section `B`, with
`- .env # env-asset-ack: web build, contains no secrets`:

```
$ dart run tool/check_env_assets.dart
OK: no unacknowledged secrets file in the Flutter asset list, and none inside a declared asset directory.
exit: 0
```

and then, through `build_all.sh`:

```
Checking for bundled secrets files...
check_env_assets: pubspec.yaml:174 bundles ".env" with an acknowledgement. It ships in every build mode and is public - keep secrets out of it.
✓ No unacknowledged secrets file in the asset list
Building Android...
```

The stderr reminder is printed, the build is not blocked, and the script
continues to the same place as the unmodified pubspec does. A deliberate web
configuration build still works.

## Criterion 5 - audit_template.sh exits 0

`format.log`, `analyze.log`, `tests.log`, each ending `exit: 0`, from
`./scripts/test/run_acceptance.sh 135 --no-goldens`.

## Also updated

`docs/guides/configuration.md` said the guard "runs in two places" and that "it
is not on the release-build path (koniz-dev/flutter-starter#135)"; both are now
false, so both were rewritten. `docs/guides/security/checklist.md` said "nothing
runs it on the release-build path yet"; same. `scripts/ci/release.sh` needed no
change and the guides now say why: it has no build step and refuses to run with
a dirty working tree, so it reaches a build only through one of the paths above.

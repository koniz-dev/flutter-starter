# Issue 170 - the env-asset acknowledgement was a substring match

Fix merged as `e56c93b` (PR #209). Evidence produced on that commit.

`AssetDeclaration.acknowledges` matched the `env-asset-ack:` comment with a raw
`contains` against free-form prose. Every env file name is a prefix of a longer
one, so `# env-asset-ack: .env.example, publishable placeholders only` on a
declared directory also acknowledged a real `.env` inside it, and prose denying
the file existed acknowledged it too. The guard exited 0 and the secrets file
shipped in the release APK, the release IPA and the web build.

## Artifacts

| File | What it is |
|---|---|
| `criterion-1-2-3-4-cli-counterfactual.log` | the real CLI run over six fixtures, once with the pre-fix guard and once with the merged one |
| `criterion-5-tooling-tests.log` | `flutter test test/tooling/check_env_assets_test.dart` - 33 cases, up from 18 |
| `criterion-5-test-counterfactual.log` | three of the new cases run against the pre-fix guard: all three fail |
| `criterion-7-audit-template.log` | `./scripts/dev/audit_template.sh`, filtered to step banners, exit 0 |
| `format.log`, `analyze.log`, `tests.log` | `./scripts/test/run_acceptance.sh 170 --no-goldens` |

No PNG is present. The run used `--no-goldens` because nothing in this change
renders, so no criterion rests on a screenshot and the standing goldens under
`test/acceptance/goldens/` were not copied in.

## Criteria

| # | Criterion | Artifact | Verdict |
|---|---|---|---|
| 1 | a directory ack matches the named file exactly, not as a substring | `criterion-1-2-3-4-cli-counterfactual.log`, case `criterion 1+2` - the same fixture and the same comment, `exit=0` before and `exit=1` after | PASS |
| 2 | the reproduction exits 1 and prints `assets/config/.env` in the `SECURITY:` block | same case: `SECURITY: a secrets file is bundled as a Flutter asset.` then `pubspec.yaml:7  - assets/config/.env (via "assets/config/")  [environment file]`, `exit=1` | PASS |
| 3 | still exits 0 for a genuine ack naming the file, and for a list | same log, cases `criterion 3` a/b/c: `.env.web` alone, `.env.web, .env.staging`, and `.env.web - publishable values only`, all `exit=0` after the fix | PASS |
| 4 | prose that mentions a file without acknowledging it exits 1 | same log, case `criterion 4`: `# env-asset-ack: .env.web only; there is no .env here` with a `.env` present, `exit=0` before and `exit=1` after, listing `assets/config/.env` **and** `assets/config/.env.web` | PASS |
| 5 | the test file gains cases for 2, 3 and 4, each failing against the old implementation; the counterfactual is recorded | `criterion-5-tooling-tests.log` (33 pass) and `criterion-5-test-counterfactual.log` (the same assertions, 3 failures, against the pre-fix guard) | PASS |
| 6 | the tool header and `docs/guides/configuration.md` state the matching rule precisely enough to predict what a comment covers | `tool/check_env_assets.dart` - the `parseAcknowledgedNames` doc comment carries the grammar; `docs/guides/configuration.md` - the "What a given comment covers" section, with the grammar and a six-row table of comment to covered set | PASS |
| 7 | `./scripts/dev/audit_template.sh` exits 0 | `criterion-7-audit-template.log`: env asset guard OK, format 0 changed, analyze no issues, 2742 tests pass, `exit=0` | PASS |

## The grammar this settles on

```
ack       := 'env-asset-ack:' names? separator? prose?
names     := name (',' name)*
name      := a bare file name containing a dot - no spaces, no directory part
separator := ';' | an em or en dash | a hyphen with spaces around it
             | the first ',' segment that is not a name
```

The covered set is the leading comma-separated run of bare file names, matched
against the file's own name exactly and case-insensitively. A comma is the
separator because the documented form already used one; a segment containing a
space is prose, which is how `.env.web, publishable values only` keeps working.
`;` and the dashes exist so `# env-asset-ack: .env.web - publishable values
only` parses without a comma at all. A name must contain a dot, which costs
nothing - every file the guard can flag has one - and makes a one-word segment
such as `reviewed` read as prose rather than as a file that will never exist.

A malformed ack (prose first) covers **nothing** and the run fails, naming the
file that is still unacknowledged. The old behaviour on the same input was to
cover everything the prose happened to spell.

A name matching no file in the directory is stale: a `note:` on stderr, exit
code unchanged. Hard-failing was rejected because `.env` and `.env.*.local` are
gitignored and a web deployment may write its env file at deploy time, so a
fresh checkout can legitimately lack the file and a red build there would punish
a tree that is strictly safer.

## Reproducing the counterfactual

`criterion-1-2-3-4-cli-counterfactual.log` was produced by the script below, run
from the repository root. It is reproduced here rather than committed, because a
`.dart` or fixture tree under `docs/verification/` is analyzed like any other
source (koniz-dev/flutter-starter#187).

```bash
#!/usr/bin/env bash
set -uo pipefail
WORK=$(mktemp -d)
git show 75c8d1d:tool/check_env_assets.dart > "$WORK/before.dart"
cp tool/check_env_assets.dart "$WORK/after.dart"

# fixture <name> <directory-entry-comment> <files...>
fixture() {
  local name="$1"; shift
  local comment="$1"; shift
  mkdir -p "$WORK/$name/assets/config"
  for f in "$@"; do
    printf 'API_KEY=supersecret\n' > "$WORK/$name/assets/config/$f"
  done
  cat > "$WORK/$name/pubspec.yaml" <<YAML
name: fixture_$name

flutter:
  uses-material-design: true
  assets:
    - .env.example
    - assets/config/$comment
YAML
}

run_case() {
  echo "CASE: $1"
  for variant in before after; do
    echo "--- $variant ---"
    ( cd "$WORK/$2" && dart run "$WORK/$variant.dart" pubspec.yaml 2>&1 )
    ( cd "$WORK/$2" && dart run "$WORK/$variant.dart" pubspec.yaml >/dev/null 2>&1 )
    echo "exit=$?"
  done
}

fixture c2 ' # env-asset-ack: .env.example, publishable placeholders only' .env.example .env
run_case 'criterion 1+2' c2
fixture c3a ' # env-asset-ack: .env.web, publishable values only' .env.web
run_case 'criterion 3' c3a
fixture c3b ' # env-asset-ack: .env.web, .env.staging, publishable values only' .env.web .env.staging
run_case 'criterion 3, list' c3b
fixture c3c ' # env-asset-ack: .env.web - publishable values only' .env.web
run_case 'criterion 3, dash prose' c3c
fixture c4 ' # env-asset-ack: .env.web only; there is no .env here' .env.web .env
run_case 'criterion 4' c4
fixture stale ' # env-asset-ack: .env.web, publishable values only' .gitkeep
run_case 'stale ack' stale
```

`criterion-5-test-counterfactual.log` came from copying the pre-fix guard to
`tool/cf170_before.dart`, pointing a throwaway copy of three of the new cases at
it, and running `flutter test` on that file. Both files were deleted after the
run; neither is committed.

## What this still does not catch

- A file created **after** the guard runs, and any build that never runs it -
  `scripts/ci/build_all.sh` and the deploy workflows still can
  (koniz-dev/flutter-starter#135, untouched here).
- Whether an acknowledged file really holds no secrets. The marker records that
  a human said so; nothing reads the file.
- A secret inside an innocuously named file: matching is by name only.
- A secret in a sub-directory of a declared directory - Flutter does not bundle
  those either, so it is out of scope by construction.

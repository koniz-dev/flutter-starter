# Issue 140 - the pre-commit hook no longer lets git hijack the Flutter SDK

## What the defect actually is

Not "worktrees are special to Flutter". Git exports `GIT_DIR` into a hook
process whenever the git directory is **not** the default `.git` beside the
working directory. A worktree is exactly that case: its `.git` is a file
pointing at `<main>/.git/worktrees/<name>`, so git resolves the path and
exports it.

`flutter` works out which SDK it is by shelling out to git, and an exported
`GIT_DIR` overrides even an explicit `-C`. So inside such a hook the SDK
describes **this repository** and calls the answer its own version. On the
reporting machine that came out as `The current Flutter SDK version is
0.0.0-unknown`, which fails the `environment: sdk:` constraint in
`pubspec.yaml` and rejects the commit - while `flutter analyze` run by hand in
the same tree is clean, because an ordinary shell has no `GIT_DIR`.

`command -v flutter` cannot catch this, exactly as the issue says: `flutter`
is on `PATH`; it is the SDK's identity that is wrong.

## Approach taken (criterion 3)

**Resolve the SDK, not detect and report.** `pre-commit` and `pre-push` now run
every Flutter and Dart command through
`env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_COMMON_DIR -u
GIT_OBJECT_DIRECTORY -u GIT_ALTERNATE_OBJECT_DIRECTORIES -u GIT_PREFIX`.
Neither hook calls git itself, so nothing else wants those variables, and a
state the hook simply cannot be in needs no error message. `pre-push` was
fixed alongside `pre-commit`: it is the same class of command run from the same
kind of process, and fixing one and filing the other would have been noise.

## Evidence

| File | What it is |
|---|---|
| `hook-environment.log` | Two real hook invocations, dumping the environment git handed them: an ordinary commit, and a commit whose git directory is not the default |
| `criteria-2-4-hook-behaviour.log` | The leak at the git level and the Flutter level, the before/after hook comparison under a worktree-shaped environment, the criterion 2 rejection matrix, and the `commit-msg` re-derivation |
| `format.log`, `analyze.log`, `tests.log` | `./scripts/test/run_acceptance.sh 140 --no-goldens` |

`--no-goldens`: shell hooks and a markdown section. Nothing renders, there is no
PNG here, no criterion rests on a golden, and the standing goldens under
`test/acceptance/goldens/` were neither copied here nor touched.

## Criterion 1 - commit from inside a worktree succeeds

**Routed to `status:needs-uat`.** This session is instructed not to create a
`git worktree` on this repository, and criterion 1 asks specifically for a
transcript from inside one. What was established without one:

- **git exports an absolute `GIT_DIR` as soon as the git directory is not the
  default.** `hook-environment.log`, probe B: a commit run as
  `git --git-dir="$PWD/.git" --work-tree="$PWD" commit` handed its hook
  `GIT_DIR=/Users/.../flutter-starter/.git`, `GIT_WORK_TREE=.` and an absolute
  `GIT_INDEX_FILE`. Probe A, an ordinary commit, exported none of them.
- **That variable is what breaks the SDK lookup.**
  `criteria-2-4-hook-behaviour.log` section 2:

  ```
  $ git -C $FLUTTER_ROOT describe --tags
  3.47.0

  $ GIT_DIR=<repo>/.git git -C $FLUTTER_ROOT describe --tags
  fatal: No tags can describe 'c7f57135c4c72ed31cf6f39271cf1ee541c5824a'.
  ```

  A failed `describe` is precisely the input that produces `0.0.0-unknown`.
  Section 3 shows the consequence end to end: `flutter --version` reports
  `Flutter 3.47.0 • channel stable • https://github.com/flutter/flutter.git`
  normally and
  `Flutter 3.49.0-0.1.pre • channel [user-branch] • https://github.com/koniz-dev/flutter-starter.git`
  with `GIT_DIR` exported. It reads this project's remote as the SDK's.
- **The fix removes the variable before Flutter sees it.** Section 4 runs
  `origin/main`'s hook and this branch's hook under the same exported
  environment, with `flutter`/`dart` replaced by a shim that only prints the
  environment it was handed:

  ```
  --- origin/main's .githooks/pre-commit, with GIT_DIR exported:
    [shim] flutter analyze invoked with GIT_DIR=/Users/.../.git GIT_INDEX_FILE=/Users/.../.git/index
  --- this branch's .githooks/pre-commit, same environment:
    [shim] flutter analyze invoked with GIT_DIR=(unset) GIT_INDEX_FILE=(unset)
  ```

What is **not** established here: that a `git worktree add`-created worktree on
the reporter's machine produces the literal string `0.0.0-unknown`, and that the
commit now succeeds there. This machine's SDK has a cached version stamp, so it
degrades to a wrong-but-parseable version instead of an unknown one. The
hand-off comment on the issue carries the exact steps.

## Criterion 2 - the hook still rejects code that fails analyze

PASS, in both environments. `criteria-2-4-hook-behaviour.log` section 5, with a
deliberate `int probe140 = 'not an int';` in `lib/`, real Flutter (no shim):

| Environment | Tree | Result |
|---|---|---|
| ordinary | broken | `invalid_assignment` reported, `flutter analyze failed.`, **exit 1** |
| `GIT_DIR` exported (worktree-shaped) | broken | same error, **exit 1** |
| ordinary | clean | `No issues found!`, `Pre-commit checks passed.`, exit 0 |
| `GIT_DIR` exported (worktree-shaped) | clean | `No issues found!`, `Pre-commit checks passed.`, exit 0 |

The analyzer still runs and still decides. The fix did not buy a green hook by
skipping it.

## Criterion 4 - commit-msg, re-derived on current main

PASS, unaffected. `criteria-2-4-hook-behaviour.log` section 6:
`grep -nE 'flutter|dart |command -v' .githooks/commit-msg` prints nothing, and
the only commands the hook runs are `head`, `grep`, `echo` and `exit`. No
toolchain, so no SDK to misidentify. Demonstrated anyway under an exported
`GIT_DIR`: a Conventional subject exits 0, a non-conforming one prints the
rejection and exits 1. The `#57` allowances (`Merge `, `Revert "`,
`fixup!`/`squash!`/`amend! `) are still in the file at the top of the pattern
block and were not touched.

## Criterion 5 - CONTRIBUTING.md says whether hooks work in a worktree

PASS. `CONTRIBUTING.md` had **no** hook section at all, so one was added under
Commit Message Guidelines: how to install them, what each one runs, how to skip
them, and then the direct answer - "**They are expected to work inside a `git
worktree`**" - with the reason (`.git/hooks/` is shared by every worktree) and
the symptom to watch for if it ever regresses. `dart run tool/check_docs.dart`
passes on the edited file.

(The issue says `CONTRIBUTING.md` tells contributors to run
`setup_git_hooks.sh`. It did not; only `CLAUDE.md` did. It does now.)

## Criterion 6 - audit_template.sh exits 0

`format.log`, `analyze.log`, `tests.log`, each ending `exit: 0`, from
`./scripts/test/run_acceptance.sh 140 --no-goldens`.

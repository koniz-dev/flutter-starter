# Issue 164 - .gitignore now covers *.pem, *.key (and *.pfx)

`.gitignore` ignored most code-signing containers but not the two commonest raw
private-key formats, while `tool/check_env_assets.dart` has treated `.pem` and
`.key` as secret since #138. One policy, two answers. This closes the gap on the
git side.

## Evidence

| File | What it is |
|---|---|
| `criterion-2-nothing-tracked-before.log` | `git ls-files` and a `find`, run on `29005c3` **before** the change |
| `criteria-1-3-check-ignore.log` | `git check-ignore -v` over every affected and unaffected extension, after the change, plus the resulting `.gitignore` block |
| `format.log`, `analyze.log`, `tests.log` | `./scripts/test/run_acceptance.sh 164 --no-goldens` |

`--no-goldens`: this change is `.gitignore` plus one markdown checklist item.
Nothing renders, there is no PNG in this directory, no criterion rests on a
golden, and the standing goldens under `test/acceptance/goldens/` were neither
copied here nor touched.

## Criterion 1 - `*.pem` and `*.key` are ignored

`criteria-1-3-check-ignore.log`:

```
$ git check-ignore -v signing.pem private.key export.pfx
.gitignore:86:*.pem	signing.pem
.gitignore:87:*.key	private.key
.gitignore:88:*.pfx	export.pfx
(exit 0)
```

Each resolves to a `.gitignore` line, as the criterion asks. The log also shows
the patterns match at any depth
(`docs/verification/issue-164/nested/signing.pem`), which is what a leading
wildcard pattern does and what a developer dropping a key into a subdirectory
depends on.

## Criterion 2 - nothing tracked becomes ignored

`criterion-2-nothing-tracked-before.log`, taken on `29005c3` before the edit:

```
$ git ls-files | grep -E '\.(pem|key)$'   # BEFORE the change
(grep exit 1: 1 = no match, nothing tracked would become ignored)
```

`find` over the working tree found no `.pem` or `.key` on disk at all, so there
was nothing to decide per file. `criteria-1-3-check-ignore.log` repeats the
`git ls-files` check after the change, including `.pfx`; still empty.

## Criterion 3 - the existing block is unchanged, and the exclusions are explained

Three parts.

**`key.properties` untouched.** `git check-ignore -v android/key.properties`
still resolves to `android/.gitignore:12:key.properties`. The root `.gitignore`
never carried that pattern and still does not.

**The code-signing block is unchanged.** The log prints it verbatim: `*.p12`,
`*.p8`, `*.mobileprovision`, `*.provisionprofile`, `*.cer`,
`*.certSigningRequest`, `*.keystore`, `*.jks` all still resolve to lines 70-77,
the same lines they were on before. Nothing was removed, reordered or rewritten;
the new patterns were appended below them.

**`.crt` and `.der` remain trackable, with the reason in the file.**
`git check-ignore -v pinned.crt pinned.der` prints nothing and exits 1. The
comment block above them names #138's reasoning, points at the "Public
certificates" note in `tool/check_env_assets.dart`, and says explicitly that
this is the reason not to "fix the inconsistency".

**One correction to the issue's premise.** The issue says ".cer, .crt and .der
stay trackable". `.cer` was already ignored before this change - it arrived in
`dbee1c6` with the Apple signing block, and `git check-ignore -v apple.cer`
resolves to `.gitignore:74`, a line this change did not touch. Since criterion 3
also requires the existing block to stay unchanged, the two halves cannot both
be satisfied for `.cer`, so the block was left alone and the asymmetry is now
documented in place rather than silently inherited. `.crt` and `.der`, the two
formats a pinning setup actually ships, are trackable.

## Beyond the criteria - `*.pfx`

`*.pfx` was added alongside `*.pem` and `*.key`. It is not a new policy: `.pfx`
is the same PKCS#12 container as `.p12`, which line 70 has always ignored, under
its Windows extension, and `secretAssetExtensions` in
`tool/check_env_assets.dart` already listed it. Leaving it out would have
reproduced exactly the gap this issue exists to close, one extension over. The
two lists are now the same set of private formats.

## Criterion 4 - the security checklist reads as one policy

`docs/guides/security/checklist.md`, `### Code Security`, immediately after the
`.env` asset item: a new **Confirm no private key material is tracked
(shipped)** entry. It names both enforcement points (`.gitignore` and
`tool/check_env_assets.dart`, with the guard's `secretAssetExtensions` listed
so the difference from the ignore list is visible), gives the pre-release
command, and states the thing a checklist reader most needs to know - that
`.gitignore` does not retroactively untrack a file, so a hit means `git rm
--cached` **and rotate the key**. It closes by naming `.crt` and `.der` as
deliberately trackable, so the checklist and the ignore file agree.

`dart run tool/check_docs.dart` passes on the edited file: 711 relative links
checked, 0 broken; 0 lines with emoji.

## Criterion 5 - audit_template.sh exits 0

`format.log`, `analyze.log`, `tests.log`, all ending `exit: 0`, from
`./scripts/test/run_acceptance.sh 164 --no-goldens`.

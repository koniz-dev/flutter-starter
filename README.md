# Verification evidence

This orphan branch holds the acceptance evidence for issues in
[koniz-dev/flutter-starter](https://github.com/koniz-dev/flutter-starter): logs,
screenshots, test output and checksums, one directory per issue under
`docs/verification/issue-<N>/`.

It shares no history with `main`, so a project created with "Use this template"
(which copies the default branch) never inherits it. Until 2026-10-20 these
files lived on `main`; they were moved here unchanged (every blob identical to
`main` at `9b76995`), and issue comments that linked
`blob/main/docs/verification/...` were rewritten to `blob/evidence/...`
(koniz-dev/flutter-starter#619). Their history on `main` before that commit is
unchanged.

## Adding evidence

From a clone of the repository:

```bash
git fetch origin evidence
git worktree add ../flutter-starter-evidence evidence   # once
cd ../flutter-starter-evidence && git pull --ff-only
mkdir -p docs/verification/issue-<N>
# copy the issue's logs, screenshots and goldens-checksums.txt in
git add docs/verification/issue-<N>
git commit -m "docs(verification): evidence for #<N>" \
  -m "Refs koniz-dev/flutter-starter#<N>"
git push origin evidence
```

Link it from the issue as
`https://github.com/koniz-dev/flutter-starter/blob/evidence/docs/verification/issue-<N>/<file>`.
Links from here to code use URLs pinned to the commit that was verified,
because `main`'s files are not on this branch.

# setup_git_hooks.ps1
# Points this repository's git hooks at .githooks/ (core.hooksPath), as
# setup_git_hooks.sh does - see that script for why the hooks are no longer
# copied into .git/hooks/.

$ErrorActionPreference = 'Stop'
Set-Location (Join-Path $PSScriptRoot '..\..')

git rev-parse --git-dir *> $null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[Error] Not inside a Git repository." -ForegroundColor Red
    exit 1
}

foreach ($name in 'pre-commit', 'commit-msg', 'pre-push') {
    if (!(Test-Path (Join-Path '.githooks' $name))) {
        Write-Host "[Error] Required hook missing: .githooks/$name" -ForegroundColor Red
        exit 1
    }
}

# Relative to the top of the working tree, as git reads it: a bare .githooks
# ran no hook with the app in a subdirectory of a larger repository.
$hooksPath = (git rev-parse --show-prefix) + '.githooks'

# A bare .githooks is this script's own (an earlier version wrote it, even in
# a monorepo, where it named nothing), so it is replaced.
$localPath = git config --local --get core.hooksPath
if ($localPath -and $localPath -ne $hooksPath -and $localPath -ne '.githooks') {
    Write-Host "[Error] This repository already sets core.hooksPath to '$localPath'," -ForegroundColor Red
    Write-Host "        so git runs the hooks there, not .githooks/. Either run"
    Write-Host "          git config --local core.hooksPath '$hooksPath'"
    Write-Host "        or call .githooks/* from your own hooks in '$localPath'."
    exit 1
}
$globalPath = git config --global --get core.hooksPath

git config --local core.hooksPath $hooksPath

$resolved = git rev-parse --git-path hooks
if ($resolved -ne '.githooks') {
    # Put the previous setting back rather than leave one that runs no hook.
    if ($localPath) {
        git config --local core.hooksPath $localPath
    } else {
        git config --local --unset core.hooksPath
    }
    Write-Host "[Error] git still resolves hooks to '$resolved', not .githooks/." -ForegroundColor Red
    Write-Host "        core.hooksPath was restored to what it was before."
    exit 1
}

Write-Host "[Done] Git hooks active: core.hooksPath = $hooksPath" -ForegroundColor Green
if ($globalPath) {
    Write-Host "       (overrides your global core.hooksPath '$globalPath' for this repository)"
}
Write-Host "  - pre-commit: Format check + code analysis"
Write-Host "  - commit-msg: Conventional Commits validation"
Write-Host "  - pre-push: Run tests"
Write-Host ""
Write-Host "To skip hooks (when needed): git commit --no-verify | git push --no-verify"

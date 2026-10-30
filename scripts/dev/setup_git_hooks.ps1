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

$localPath = git config --local --get core.hooksPath
if ($localPath -and $localPath -ne '.githooks') {
    Write-Host "[Error] This repository already sets core.hooksPath to '$localPath'," -ForegroundColor Red
    Write-Host "        so git runs the hooks there, not .githooks/. Either run"
    Write-Host "          git config --local core.hooksPath .githooks"
    Write-Host "        or call .githooks/* from your own hooks in '$localPath'."
    exit 1
}
$globalPath = git config --global --get core.hooksPath

git config --local core.hooksPath .githooks

$resolved = git rev-parse --git-path hooks
if ($resolved -ne '.githooks') {
    Write-Host "[Error] git still resolves hooks to '$resolved', not .githooks/." -ForegroundColor Red
    exit 1
}

Write-Host "[Done] Git hooks active: core.hooksPath = .githooks" -ForegroundColor Green
if ($globalPath) {
    Write-Host "       (overrides your global core.hooksPath '$globalPath' for this repository)"
}
Write-Host "  - pre-commit: Format check + code analysis"
Write-Host "  - commit-msg: Conventional Commits validation"
Write-Host "  - pre-push: Run tests"
Write-Host ""
Write-Host "To skip hooks (when needed): git commit --no-verify | git push --no-verify"

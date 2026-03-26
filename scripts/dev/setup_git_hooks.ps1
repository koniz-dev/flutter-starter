# setup_git_hooks.ps1
# Git Hooks Installation Script for Windows (PowerShell)

Write-Host "[Git Hooks] Installing..." -ForegroundColor Cyan

$gitHooksDir = Join-Path (Get-Location) ".git\hooks"
$sourceHooksDir = Join-Path (Get-Location) ".githooks"

if (!(Test-Path $sourceHooksDir)) {
    Write-Host "[Error] .githooks directory not found!" -ForegroundColor Red
    exit 1
}

if (!(Test-Path $gitHooksDir)) {
    Write-Host "[Error] .git/hooks directory not found. Are you in a Git repository?" -ForegroundColor Red
    exit 1
}

# Copy hooks to .git/hooks
try {
    # Remove existing hooks first to avoid PermissionDenied
    if (Test-Path (Join-Path $gitHooksDir "pre-commit")) { Remove-Item (Join-Path $gitHooksDir "pre-commit") -Force }
    if (Test-Path (Join-Path $gitHooksDir "commit-msg")) { Remove-Item (Join-Path $gitHooksDir "commit-msg") -Force }
    if (Test-Path (Join-Path $gitHooksDir "pre-push")) { Remove-Item (Join-Path $gitHooksDir "pre-push") -Force }
    
    # Copy files
    Copy-Item -Path (Join-Path $sourceHooksDir "*") -Destination $gitHooksDir -Force
    
    Write-Host "[Done] Git hooks installed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Hooks installed:"
    Write-Host "  - pre-commit: Format check + code analysis"
    Write-Host "  - commit-msg: Conventional Commits validation"
    Write-Host "  - pre-push: Run tests"
    Write-Host ""
    Write-Host "To skip hooks (when needed):"
    Write-Host "  git commit --no-verify"
    Write-Host "  git push --no-verify"
} catch {
    Write-Host "[Error] Error installing hooks: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}


# test_coverage.ps1
# Test coverage script for Windows (PowerShell)
#
# Runs the tests with coverage only. It takes none of test_coverage.sh's
# options (--html, --min, --exclude, --analyze, --no-test); use that script
# under Git Bash or WSL for them (see docs/guides/testing/test-coverage.md).

$ErrorActionPreference = "Stop"

Write-Host "[Test] Running tests with coverage..." -ForegroundColor Cyan
# The helper imports every library under lib/, so a file no test loads still
# counts in the total, as it does in test_coverage.sh and CI. It is removed
# again however the run ends.
try {
    dart run tool/coverage_helper.dart
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[Error] tool/coverage_helper.dart failed (exit $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
    # $ErrorActionPreference does not stop on a native command's exit code:
    # without this check, failing tests ended in "Tests completed" and exit 0.
    flutter test --coverage
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[Error] flutter test failed (exit $LASTEXITCODE)" -ForegroundColor Red
        exit $LASTEXITCODE
    }
} finally {
    Remove-Item -Force -ErrorAction SilentlyContinue "test/coverage_helper_test.dart"
}

if (!(Test-Path "coverage/lcov.info")) {
    Write-Host "[Error] coverage/lcov.info not found!" -ForegroundColor Red
    exit 1
}

Write-Host "[Done] Tests completed. Coverage data generated." -ForegroundColor Green
Write-Host ""
Write-Host "To generate HTML report (requires lcov):"
Write-Host "  perl C:\bin\lcov-1.15\bin\genhtml coverage\lcov.info -o coverage\html" 
Write-Host "  (Path to genhtml may vary by installation)"
Write-Host ""
Write-Host "You can also use 'Coverage Gutters' extension in VS Code to see line coverage."


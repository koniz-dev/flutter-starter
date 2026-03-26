# test_coverage.ps1
# Test coverage script for Windows (PowerShell)

$ErrorActionPreference = "Stop"

Write-Host "[Test] Running tests with coverage..." -ForegroundColor Cyan
flutter test --coverage

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


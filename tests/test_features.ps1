# @file test_features.ps1
# @brief Feature test script for XY compiler

param(
    [string]$ExamplesDir = "examples",
    [switch]$Verbose
)

function Write-TestHeader($text) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  $text" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

function Write-Pass($text) {
    Write-Host "[PASS] $text" -ForegroundColor Green
}

function Write-Fail($text) {
    Write-Host "[FAIL] $text" -ForegroundColor Red
}

function Run-Test($name, $file, $expected) {
    $output = & cargo run -- "$ExamplesDir/$file" --run 2>&1 | Out-String
    $lines = $output -split "`n" | Where-Object { $_ -ne "" }
    $result = $lines[-1].Trim()

    if ($result -eq $expected) {
        Write-Pass "$name (expected: $expected, got: $result)"
        return $true
    } else {
        Write-Fail "$name (expected: $expected, got: $result)"
        return $false
    }
}

Write-TestHeader "XY Compiler Feature Tests"

$totalTests = 0
$passedTests = 0
$failedTests = 0

$tests = @(
    @{ Name = "Lambda Test"; File = "test_lambda.xy"; Expected = "6" },
    @{ Name = "Closure Test"; File = "test_closure.xy"; Expected = "15" },
    @{ Name = "Basic Function Test"; File = "test_generic.xy"; Expected = "30" },
    @{ Name = "Tail Call Test"; File = "test_tailcall.xy"; Expected = "120" }
)

foreach ($test in $tests) {
    $totalTests++
    if (Run-Test $test.Name $test.File $test.Expected) {
        $passedTests++
    } else {
        $failedTests++
    }
}

Write-TestHeader "Test Results"
Write-Host "Total: $totalTests" -ForegroundColor White
Write-Host "Passed: $passedTests" -ForegroundColor Green
Write-Host "Failed: $failedTests" -ForegroundColor Red

if ($failedTests -eq 0) {
    Write-Host ""
    Write-Host "All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host ""
    Write-Host "Some tests failed!" -ForegroundColor Red
    exit 1
}

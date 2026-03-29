# Simple test script
# Test extracting and saving IR

$ErrorActionPreference = "Continue"

Write-Host "Testing IR extraction..."

$PROJECT_ROOT = $PSScriptRoot | Split-Path
$XY_COMPILER = Join-Path $PROJECT_ROOT "target\debug\xy.exe"
$TEST_MODULE = Join-Path $PROJECT_ROOT "src\compiler_v2\runtime.xy"
$OUTPUT_IR = Join-Path $PROJECT_ROOT "target\test_output.ll"

Write-Host "Compiler: $XY_COMPILER"
Write-Host "Test module: $TEST_MODULE"
Write-Host "Output: $OUTPUT_IR"
Write-Host ""

if (-not (Test-Path $XY_COMPILER)) {
    Write-Host "ERROR: Compiler not found" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $TEST_MODULE)) {
    Write-Host "ERROR: Module not found" -ForegroundColor Red
    exit 1
}

Write-Host "Compiling..."
$output = & $XY_COMPILER $TEST_MODULE
$exitCode = $LASTEXITCODE

Write-Host "Exit code: $exitCode"
Write-Host "Output length: $($output.Length)"
Write-Host ""

# Find the IR marker
$found = $false
$irLines = @()

foreach ($line in $output) {
    if ($line -match "--- LLVM IR ---") {
        Write-Host "Found IR marker!" -ForegroundColor Green
        $found = $true
        continue
    }
    if ($found) {
        $irLines += $line
    }
}

Write-Host "Extracted $($irLines.Count) IR lines"

if ($irLines.Count -gt 0) {
    $irContent = $irLines -join "`n"
    $irContent | Out-File -FilePath $OUTPUT_IR -Encoding utf8
    Write-Host "Saved IR to: $OUTPUT_IR" -ForegroundColor Green
    
    $size = (Get-Item $OUTPUT_IR).Length
    Write-Host "File size: $size bytes" -ForegroundColor Green
} else {
    Write-Host "ERROR: No IR extracted" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Test completed successfully!" -ForegroundColor Green

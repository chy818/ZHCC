# bootstrap_test.ps1
# Self-hosting verification test script

$ErrorActionPreference = "Continue"

Write-Host "========================================"
Write-Host "  XY Compiler Bootstrap Test"
Write-Host "========================================"
Write-Host ""

$PROJECT_ROOT = $PSScriptRoot | Split-Path
$XY_COMPILER = Join-Path $PROJECT_ROOT "target\debug\xy.exe"
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "output"

if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR | Out-Null
}

$TOTAL_TESTS = 0
$PASSED_TESTS = 0
$FAILED_TESTS = 0

function Run-Test {
    param (
        [string]$Name,
        [string]$File,
        [string]$Flag
    )

    $script:TOTAL_TESTS++

    Write-Host "----------------------------------------"
    Write-Host "Test $TOTAL_TESTS : $Name"
    Write-Host "File: $File"
    Write-Host "----------------------------------------"

    if (Test-Path $File) {
        $output = & $XY_COMPILER $File $Flag 2>&1
        $exitCode = $LASTEXITCODE

        # 检查是否有编译错误或执行错误
        $hasError = $output -match "错误:|error:|Error:|FAIL|fail:"
        # 检查是否编译成功（exit code 0 且没有错误，或有成功标志，或有缓存标志）
        $isSuccess = $exitCode -eq 0 -and (-not $hasError)

        if ($isSuccess) {
            Write-Host "[PASS] $Name"
            $script:PASSED_TESTS++
        } else {
            Write-Host "[FAIL] $Name (exit code: $exitCode)"
            if ($output) {
                Write-Host $output
            }
            $script:FAILED_TESTS++
        }
    } else {
        Write-Host "[SKIP] File not found: $File"
        $script:FAILED_TESTS++
    }
    Write-Host ""
}

Write-Host "[1/5] Checking compiler..."
if (-not (Test-Path $XY_COMPILER)) {
    Write-Host "ERROR: Compiler not found: $XY_COMPILER"
    Write-Host "Run: cargo build"
    exit 1
}
Write-Host "OK: Compiler exists: $XY_COMPILER"
Write-Host ""

Write-Host "[2/5] Compiler info..."
Write-Host "Version: v0.1.0 (Bootstrap)"
Write-Host ""

Write-Host "[3/5] Testing bootstrap modules..."
Run-Test "Lexer (lexer.xy)" (Join-Path $SRC_DIR "lexer.xy") "--ir"
Run-Test "Parser (parser.xy)" (Join-Path $SRC_DIR "parser.xy") "--ir"
Run-Test "Sema (sema.xy)" (Join-Path $SRC_DIR "sema.xy") "--ir"
Run-Test "Codegen (codegen.xy)" (Join-Path $SRC_DIR "codegen.xy") "--ir"
Run-Test "Runtime (runtime.xy)" (Join-Path $SRC_DIR "runtime.xy") "--ir"
Run-Test "Main (main.xy)" (Join-Path $SRC_DIR "main.xy") "--ir"
Run-Test "Hello World" (Join-Path $PROJECT_ROOT "examples\hello.xy") "--ir"

Write-Host ""
Write-Host "[4/5] Testing examples..."

$testEnumPath = Join-Path $PROJECT_ROOT "examples\test_enum.xy"
if (Test-Path $testEnumPath) {
    Run-Test "test_enum.xy" $testEnumPath "--ir"
} else {
    Write-Host "[SKIP] test_enum.xy not found"
}

Write-Host ""
Write-Host "[5/5] Running hello.xy..."
$helloPath = Join-Path $PROJECT_ROOT "examples\hello.xy"
if (Test-Path $helloPath) {
    $runOutput = & $XY_COMPILER $helloPath --run 2>&1 | Select-Object -Last 30
    Write-Host $runOutput
}
Write-Host ""

Write-Host "========================================"
Write-Host "  Test Results"
Write-Host "========================================"
Write-Host "Total: $TOTAL_TESTS"
Write-Host "Passed: $PASSED_TESTS"
Write-Host "Failed: $FAILED_TESTS"
Write-Host ""

if ($FAILED_TESTS -eq 0) {
    Write-Host "ALL TESTS PASSED!"
    exit 0
} else {
    Write-Host "FAILED: $FAILED_TESTS tests"
    exit 1
}
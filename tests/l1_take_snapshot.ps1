# L1 Take Snapshot Script
# L1 Benchmark Snapshot Script
# Compile all XY modules with Rust compiler and save IR as L1 baseline

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  L1 - Take Snapshot" -ForegroundColor Cyan
Write-Host "  Compile all XY modules with Rust compiler" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$PROJECT_ROOT = $PSScriptRoot | Split-Path
$XY_COMPILER = Join-Path $PROJECT_ROOT "target\debug\xy.exe"
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$SNAPSHOT_DIR = Join-Path $PROJECT_ROOT "target\l1_snapshot"

# Create output directory
if (-not (Test-Path $SNAPSHOT_DIR)) {
    New-Item -ItemType Directory -Path $SNAPSHOT_DIR -Force | Out-Null
}

$XY_MODULES = @(
    "runtime.xy",
    "lexer.xy",
    "parser.xy",
    "sema.xy",
    "codegen.xy",
    "main.xy"
)

$TOTAL_MODULES = $XY_MODULES.Count
$SUCCESS_COUNT = 0
$FAIL_COUNT = 0

Write-Host "[Check] Compiler path: $XY_COMPILER"
if (-not (Test-Path $XY_COMPILER)) {
    Write-Host "[Error] Compiler not found: $XY_COMPILER" -ForegroundColor Red
    Write-Host "Please run: cargo build"
    exit 1
}
Write-Host "[OK] Compiler exists" -ForegroundColor Green
Write-Host ""

Write-Host "[Start] Compiling $TOTAL_MODULES modules..."
Write-Host "Output directory: $SNAPSHOT_DIR"
Write-Host ""

foreach ($module in $XY_MODULES) {
    $fullPath = Join-Path $SRC_DIR $module
    $irFileName = $module + ".ll"
    $irFilePath = Join-Path $SNAPSHOT_DIR $irFileName
    
    Write-Host "----------------------------------------"
    Write-Host "Module: $module"
    Write-Host "----------------------------------------"
    
    if (-not (Test-Path $fullPath)) {
        Write-Host "[FAIL] File not found: $fullPath" -ForegroundColor Red
        $FAIL_COUNT++
        continue
    }
    
    # Run compiler and capture output
    $output = & $XY_COMPILER $fullPath
    $exitCode = $LASTEXITCODE
    
    $hasError = $output -match "error:|Error:|FAIL|fail:"
    $isSuccess = $exitCode -eq 0 -and (-not $hasError)
    
    if ($isSuccess) {
        Write-Host "[PASS] Compiled successfully" -ForegroundColor Green
        
        # Extract IR from output
        $foundIR = $false
        $irLines = @()
        
        foreach ($line in $output) {
            if ($line -match "--- LLVM IR ---") {
                $foundIR = $true
                continue
            }
            if ($foundIR) {
                $irLines += $line
            }
        }
        
        if ($irLines.Count -gt 0) {
            $irContent = $irLines -join "`n"
            $irContent | Out-File -FilePath $irFilePath -Encoding utf8
            Write-Host "  IR saved: $irFilePath"
            
            $irSize = (Get-Item $irFilePath).Length
            Write-Host "  IR size: $irSize bytes"
            
            $SUCCESS_COUNT++
        } else {
            Write-Host "[FAIL] No IR extracted" -ForegroundColor Red
            $FAIL_COUNT++
        }
    } else {
        Write-Host "[FAIL] Compilation failed (exit code: $exitCode)" -ForegroundColor Red
        if ($output) {
            Write-Host $output
        }
        $FAIL_COUNT++
    }
    Write-Host ""
}

Write-Host "========================================"
Write-Host "  L1 Snapshot Complete"
Write-Host "========================================"
Write-Host "  Total modules: $TOTAL_MODULES"
Write-Host "  Success:     $SUCCESS_COUNT"
Write-Host "  Fail:        $FAIL_COUNT"
Write-Host "========================================"
Write-Host ""

if ($FAIL_COUNT -eq 0) {
    Write-Host "L1 Benchmark Snapshot Created Successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Snapshot location: $SNAPSHOT_DIR"
    Write-Host ""
    Write-Host "Next step: After L2 compiler is ready, run L3 verification"
    exit 0
} else {
    Write-Host "L1 Benchmark Snapshot Failed, $FAIL_COUNT modules failed to compile" -ForegroundColor Red
    exit 1
}

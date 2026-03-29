# L1 Simple Snapshot Script
# Compile each XY module and save IR

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  L1 - Simple Snapshot" -ForegroundColor Cyan
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

$SUCCESS_COUNT = 0
$FAIL_COUNT = 0

Write-Host "Compiler: $XY_COMPILER"
Write-Host "Source dir: $SRC_DIR"
Write-Host "Output dir: $SNAPSHOT_DIR"
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
    
    Write-Host "Compiling..."
    
    # Use the same method as test_simple.ps1
    $output = & $XY_COMPILER $fullPath
    $exitCode = $LASTEXITCODE
    
    Write-Host "Exit code: $exitCode"
    
    # Only check for critical compilation errors, not warnings or other output
    $isSuccess = $exitCode -eq 0
    
    if ($isSuccess) {
        Write-Host "[PASS] Compiled successfully" -ForegroundColor Green
        
        # Extract IR
        $foundIR = $false
        $irLines = @()
        
        foreach ($line in $output) {
            if ($line -match "--- LLVM IR ---") {
                Write-Host "  Found IR marker"
                $foundIR = $true
                continue
            }
            if ($foundIR) {
                $irLines += $line
            }
        }
        
        Write-Host "  Extracted $($irLines.Count) IR lines"
        
        if ($irLines.Count -gt 0) {
            $irContent = $irLines -join "`n"
            $irContent | Out-File -FilePath $irFilePath -Encoding utf8
            Write-Host "  Saved to: $irFilePath" -ForegroundColor Green
            
            $irSize = (Get-Item $irFilePath).Length
            Write-Host "  Size: $irSize bytes" -ForegroundColor Green
            
            $SUCCESS_COUNT++
        } else {
            Write-Host "[FAIL] No IR extracted" -ForegroundColor Red
            $FAIL_COUNT++
        }
    } else {
        Write-Host "[FAIL] Compilation failed" -ForegroundColor Red
        $FAIL_COUNT++
    }
    Write-Host ""
}

Write-Host "========================================"
Write-Host "  Done"
Write-Host "========================================"
Write-Host "  Success: $SUCCESS_COUNT"
Write-Host "  Fail:    $FAIL_COUNT"
Write-Host "========================================"

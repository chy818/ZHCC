# bootstrap_en.ps1
# ========================================
# Complete Bootstrap Verification Script
# ========================================
#
# Three-stage bootstrap process:
#
# L1:
#   - Compile all XY modules using Rust xy.exe
#   - Goal: Verify each module can be compiled independently
#   - Output: LLVM IR files for each module
#
# L2:
#   - Link all L1 modules into xyc.exe
#   - Goal: Verify complete self-hosted compiler can be built
#   - Output: xyc.exe (self-hosted compiler)
#
# L3:
#   - Recompile all XY modules using L2's xyc.exe
#   - Goal: Verify self-hosted compiler works correctly
#   - Output: L3 stage LLVM IR files
#
# Verification:
#   - Compare L1 and L3 IR for consistency
#   - Goal: Ensure bootstrap produces correct results
#
# ========================================

$ErrorActionPreference = "Continue"

Write-Host "========================================"
Write-Host "  Complete Bootstrap Test"
Write-Host "========================================"
Write-Host ""

# ==================== Configuration ====================

$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
$XY_COMPILER = Join-Path $PROJECT_ROOT "target\debug\xy.exe"
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "target\bootstrap_en"
$L1_IR_DIR = Join-Path $OUTPUT_DIR "l1_ir"
$L2_DIR = Join-Path $OUTPUT_DIR "l2"
$L3_IR_DIR = Join-Path $OUTPUT_DIR "l3_ir"

$XY_MODULES = @(
    "runtime.xy",
    "lexer.xy",
    "parser.xy",
    "sema.xy",
    "codegen.xy",
    "main.xy"
)

# Create output directories
New-Item -ItemType Directory -Force -Path $OUTPUT_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $L1_IR_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $L2_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $L3_IR_DIR | Out-Null

$L1_SUCCESS = $true
$L2_SUCCESS = $true
$L3_SUCCESS = $true
$VERIFY_SUCCESS = $true

# ==================== Helper Functions ====================

function Write-PhaseHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  $Title"
    Write-Host "========================================"
    Write-Host ""
}

function Compile-Single-Module {
    param(
        [string]$ModuleName,
        [string]$ModulePath,
        [string]$OutputDir,
        [string]$CompilerPath
    )
    
    Write-Host "Compiling: $ModuleName"
    
    if (-not (Test-Path $ModulePath)) {
        Write-Host "  [SKIP] File not found: $ModulePath"
        return $false
    }

    $output = & $CompilerPath $ModulePath --ir 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "  [OK] Compilation successful"
        
        # Extract only the LLVM IR part (skip compiler output)
        $irContent = ""
        $captureIR = $false
        foreach ($line in $output) {
            if ($line -match "--- LLVM IR ---") {
                $captureIR = $true
                continue
            }
            if ($captureIR -and $line -match "编译成功!") {
                break
            }
            if ($captureIR) {
                $irContent += $line + "`n"
            }
        }
        
        # If we didn't find IR markers, try to find "define" as fallback
        if ([string]::IsNullOrWhiteSpace($irContent)) {
            $inIR = $false
            foreach ($line in $output) {
                if ($line -match "^define ") {
                    $inIR = $true
                }
                if ($inIR) {
                    $irContent += $line + "`n"
                }
            }
        }
        
        $irFile = Join-Path $OutputDir "$ModuleName.ll"
        
        # Save without BOM (Byte Order Mark)
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($irFile, $irContent.Trim(), $utf8NoBom)
        
        Write-Host "  IR saved to: $irFile"
        return $true
    } else {
        Write-Host "  [FAIL] Compilation failed (exit: $exitCode)"
        return $false
    }
}

function Build-Object-Files {
    param(
        [string]$IrDir,
        [string]$ObjDir
    )
    
    $objFiles = @()
    
    foreach ($module in $XY_MODULES) {
        $irPath = Join-Path $IrDir "$module.ll"
        $objPath = Join-Path $ObjDir "$module.o"
        
        if (-not (Test-Path $irPath)) {
            Write-Host "  [SKIP] $module (no IR)"
            continue
        }
        
        Write-Host "  Building object file: $module"
        llc $irPath -filetype=obj -o $objPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [OK]"
            $objFiles += $objPath
        } else {
            Write-Host "    [FAIL]"
        }
    }
    
    return $objFiles
}

function Compare-IR {
    param(
        [string]$ModuleName,
        [string]$L1IrPath,
        [string]$L3IrPath
    )
    
    Write-Host "Comparing: $ModuleName"
    
    if (-not (Test-Path $L1IrPath)) {
        Write-Host "  [FAIL] L1 IR not found"
        return $false
    }
    if (-not (Test-Path $L3IrPath)) {
        Write-Host "  [FAIL] L3 IR not found"
        return $false
    }
    
    $content1 = Get-Content $L1IrPath -Raw
    $content2 = Get-Content $L3IrPath -Raw
    
    if ($content1 -eq $content2) {
        Write-Host "  [OK] IR matches"
        return $true
    } else {
        Write-Host "  [WARN] IR differs"
        return $false
    }
}

# ==================== L1 Stage ====================

Write-PhaseHeader "L1: Compile XY modules with Rust compiler"

if (-not (Test-Path $XY_COMPILER)) {
    Write-Host "[ERROR] Compiler not found: $XY_COMPILER"
    Write-Host "Run: cargo build"
    exit 1
}
Write-Host "Using compiler: $XY_COMPILER"
Write-Host ""

foreach ($module in $XY_MODULES) {
    $fullPath = Join-Path $SRC_DIR $module
    $success = Compile-Single-Module $module $fullPath $L1_IR_DIR $XY_COMPILER
    if (-not $success) {
        $L1_SUCCESS = $false
    }
}

Write-Host ""
Write-Host "L1 Summary: $(if ($L1_SUCCESS) { "PASS" } else { "FAIL" })"
if (-not $L1_SUCCESS) {
    Write-Host "Note: Some modules failed, L2 will continue with successful ones"
}

# ==================== L2 Stage ====================

Write-PhaseHeader "L2: Link into self-hosted compiler (xyc.exe)"

$objFiles = Build-Object-Files $L1_IR_DIR $L2_DIR

$runtimePath = Join-Path $PROJECT_ROOT "runtime\runtime.c"
if (-not (Test-Path $runtimePath)) {
    Write-Host "[ERROR] runtime.c not found"
    $L2_SUCCESS = $false
} else {
    $xycExe = Join-Path $L2_DIR "xyc.exe"
    Write-Host ""
    Write-Host "Linking into executable: $xycExe"
    
    if ($objFiles.Count -gt 0) {
        clang $runtimePath $objFiles -o $xycExe
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] L2 successful: $xycExe"
            $L2_SUCCESS = $true
        } else {
            Write-Host "[FAIL] Link failed"
            $L2_SUCCESS = $false
        }
    } else {
        Write-Host "[SKIP] No successfully compiled modules to link"
        $L2_SUCCESS = $false
    }
}

Write-Host ""
Write-Host "L2 Summary: $(if ($L2_SUCCESS) { "PASS" } else { "FAIL" })"

# ==================== L3 Stage ====================

Write-PhaseHeader "L3: Recompile with self-hosted compiler"

if ($L2_SUCCESS) {
    $xycExe = Join-Path $L2_DIR "xyc.exe"
    Write-Host "Using compiler: $xycExe"
    Write-Host ""
    
    foreach ($module in $XY_MODULES) {
        $fullPath = Join-Path $SRC_DIR $module
        $success = Compile-Single-Module $module $fullPath $L3_IR_DIR $xycExe
        if (-not $success) {
            $L3_SUCCESS = $false
        }
    }
} else {
    Write-Host "[SKIP] L2 not successful, cannot run L3"
    $L3_SUCCESS = $false
}

Write-Host ""
Write-Host "L3 Summary: $(if ($L3_SUCCESS) { "PASS" } else { "FAIL" })"

# ==================== Verification Stage ====================

Write-PhaseHeader "Verify L1 and L3 consistency"

if ($L1_SUCCESS -and $L3_SUCCESS) {
    foreach ($module in $XY_MODULES) {
        $l1Path = Join-Path $L1_IR_DIR "$module.ll"
        $l3Path = Join-Path $L3_IR_DIR "$module.ll"
        $success = Compare-IR $module $l1Path $l3Path
        if (-not $success) {
            $VERIFY_SUCCESS = $false
        }
    }
} else {
    Write-Host "[SKIP] L1 or L3 not successful"
    $VERIFY_SUCCESS = $false
}

Write-Host ""
Write-Host "Verification Summary: $(if ($VERIFY_SUCCESS) { "PASS" } else { "FAIL" })"

# ==================== Final Summary ====================

Write-PhaseHeader "Final Bootstrap Results"

Write-Host "L1 (Rust compile):        $(if ($L1_SUCCESS) { "PASS" } else { "FAIL" })"
Write-Host "L2 (Link executable):      $(if ($L2_SUCCESS) { "PASS" } else { "FAIL" })"
Write-Host "L3 (Self-host recompile):  $(if ($L3_SUCCESS) { "PASS" } else { "FAIL" })"
Write-Host "Verify (L1 vs L3):         $(if ($VERIFY_SUCCESS) { "PASS" } else { "FAIL" })"
Write-Host ""

$allOk = $L1_SUCCESS -and $L2_SUCCESS -and $L3_SUCCESS -and $VERIFY_SUCCESS

if ($allOk) {
    Write-Host "========================================"
    Write-Host "  FULL BOOTSTRAP SUCCESS!"
    Write-Host "========================================"
    exit 0
} else {
    Write-Host "========================================"
    Write-Host "  BOOTSTRAP INCOMPLETE"
    Write-Host "========================================"
    Write-Host ""
    Write-Host "Output directory: $OUTPUT_DIR"
    Write-Host "  - L1 IR: $L1_IR_DIR"
    Write-Host "  - L2 compiler: $L2_DIR"
    Write-Host "  - L3 IR: $L3_IR_DIR"
    exit 1
}

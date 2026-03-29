# simple_bootstrap_l2l3.ps1
# L2+L3 自展验证脚本（简化版）

$ErrorActionPreference = "Continue"

Write-Host "========================================"
Write-Host "  XY Compiler L2+L3 Bootstrap Test"
Write-Host "========================================"
Write-Host ""

$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
$XY_COMPILER = Join-Path $PROJECT_ROOT "target\debug\xy.exe"
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "target\bootstrap_simple"
$L1_IR_DIR = Join-Path $OUTPUT_DIR "l1_ir"
$L2_DIR = Join-Path $OUTPUT_DIR "l2"

$XY_MODULES = @(
    "runtime.xy",
    "lexer.xy",
    "parser.xy",
    "sema.xy",
    "codegen.xy",
    "main.xy"
)

# 创建输出目录
New-Item -ItemType Directory -Force -Path $OUTPUT_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $L1_IR_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $L2_DIR | Out-Null

$L1_SUCCESS = $true

# ========================================
# L1: 用 Rust 编译器编译所有 XY 模块
# ========================================

Write-Host "[1/3] L1: Compile XY modules with Rust compiler"
Write-Host "----------------------------------------"

if (-not (Test-Path $XY_COMPILER)) {
    Write-Host "ERROR: Compiler not found at $XY_COMPILER"
    Write-Host "Run: cargo build"
    exit 1
}

foreach ($module in $XY_MODULES) {
    $fullPath = Join-Path $SRC_DIR $module
    Write-Host "Compiling: $module"
    
    if (-not (Test-Path $fullPath)) {
        Write-Host "  SKIP: File not found"
        $L1_SUCCESS = $false
        continue
    }

    $output = & $XY_COMPILER $fullPath --ir 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "  OK"
        $irFile = Join-Path $L1_IR_DIR "$module.ll"
        $output | Out-File -FilePath $irFile -Encoding utf8
    } else {
        Write-Host "  FAIL (exit: $exitCode)"
        $L1_SUCCESS = $false
    }
}

if (-not $L1_SUCCESS) {
    Write-Host "L1 FAILED"
    exit 1
}

Write-Host "L1 OK"
Write-Host ""

# ========================================
# L2: Link into executable
# ========================================

Write-Host "[2/3] L2: Link modules into executable"
Write-Host "----------------------------------------"

$objFiles = @()

foreach ($module in $XY_MODULES) {
    $irPath = Join-Path $L1_IR_DIR "$module.ll"
    $objPath = Join-Path $L2_DIR "$module.o"
    
    if (-not (Test-Path $irPath)) {
        Write-Host "SKIP $module (no IR)"
        continue
    }

    Write-Host "Compiling $module to object file"
    llc $irPath -filetype=obj -o $objPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  OK"
        $objFiles += $objPath
    } else {
        Write-Host "  FAIL"
    }
}

$runtimePath = Join-Path $PROJECT_ROOT "runtime\runtime.c"
if (-not (Test-Path $runtimePath)) {
    Write-Host "ERROR: runtime.c not found"
    exit 1
}

$xycExe = Join-Path $L2_DIR "xyc.exe"

Write-Host "Linking into $xycExe"
clang $runtimePath $objFiles -o $xycExe

if ($LASTEXITCODE -eq 0) {
    Write-Host "L2 OK: $xycExe"
    $L2_SUCCESS = $true
} else {
    Write-Host "L2 FAIL"
    $L2_SUCCESS = $false
}

Write-Host ""

# ========================================
# Summary
# ========================================

Write-Host "[3/3] Summary"
Write-Host "----------------------------------------"
Write-Host "L1: $L1_SUCCESS"
Write-Host "L2: $L2_SUCCESS"
Write-Host "L3: Pending (requires L2 compiler to work"

if ($L1_SUCCESS -and $L2_SUCCESS) {
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  L1 + L2 OK!"
    Write-Host "========================================"
    exit 0
} else {
    Write-Host ""
    Write-Host "========================================"
    Write-Host "  FAILED"
    Write-Host "========================================"
    exit 1
}

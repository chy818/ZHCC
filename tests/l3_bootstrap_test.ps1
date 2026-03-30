# L3 Bootstrap Test Script
# L3 自举测试脚本

$ErrorActionPreference = "Stop"

Write-Host "========================================"
Write-Host "  L3 自举测试"
Write-Host "  玄语编译器完整自举验证"
Write-Host "========================================"
Write-Host ""

$PROJECT_ROOT = $PSScriptRoot | Split-Path
$XYC_L2 = Join-Path $PROJECT_ROOT "target\xyc\xyc.exe"
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$L3_OUTPUT_DIR = Join-Path $PROJECT_ROOT "target\l3_output"
$RUNTIME_PATH = Join-Path $PROJECT_ROOT "runtime\runtime.c"

# Step 1: Check L2 compiler
Write-Host "[1/5] 检查 L2 编译器..."
if (-not (Test-Path $XYC_L2)) {
    Write-Host "ERROR: L2 compiler not found: $XYC_L2"
    Write-Host "Run: .\build_xyc.ps1"
    exit 1
}
Write-Host "OK: L2 compiler found: $XYC_L2"
Write-Host ""

# Step 2: Create output directory
Write-Host "[2/5] 创建 L3 输出目录..."
if (-not (Test-Path $L3_OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $L3_OUTPUT_DIR -Force | Out-Null
}
Write-Host "OK: Output directory: $L3_OUTPUT_DIR"
Write-Host ""

# Step 3: Use L1 compiler to create L3 baseline
Write-Host "[3/5] 使用 L1 编译器编译 compiler.xy..."
$COMPILER_XY = Join-Path $SRC_DIR "compiler.xy"
$XY_COMPILER_L1 = Join-Path $PROJECT_ROOT "target\release\xy.exe"

if (-not (Test-Path $COMPILER_XY)) {
    Write-Host "ERROR: compiler.xy not found: $COMPILER_XY"
    exit 1
}
if (-not (Test-Path $XY_COMPILER_L1)) {
    Write-Host "ERROR: L1 compiler not found: $XY_COMPILER_L1"
    exit 1
}

$L3_IR_FILE = Join-Path $L3_OUTPUT_DIR "compiler.ll"
$CACHE_FILE = "$COMPILER_XY.cache"
if (Test-Path $CACHE_FILE) {
    Remove-Item $CACHE_FILE -Force
}

Write-Host "  Compiling: compiler.xy"
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
$irContent = & $XY_COMPILER_L1 $COMPILER_XY "--ir-pure" 2>&1
$exitCode = $LASTEXITCODE

if ($exitCode -eq 0) {
    [System.IO.File]::WriteAllLines($L3_IR_FILE, $irContent, $utf8NoBom)
    Write-Host "  OK: IR saved to $L3_IR_FILE"
} else {
    Write-Host "  FAIL (exit code: $exitCode)"
    Write-Host "  Output: $irContent"
    exit 1
}
Write-Host ""

# Step 4: Compile IR to object file
Write-Host "[4/5] 编译 IR 为对象文件..."
$L3_OBJ_FILE = Join-Path $L3_OUTPUT_DIR "compiler.o"
llc $L3_IR_FILE -filetype=obj -o $L3_OBJ_FILE
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: Object file: $L3_OBJ_FILE"
} else {
    Write-Host "FAIL: llc failed"
    exit 1
}
Write-Host ""

# Step 5: Link into L3 compiler
Write-Host "[5/5] 链接生成 L3 编译器..."
if (-not (Test-Path $RUNTIME_PATH)) {
    Write-Host "ERROR: runtime.c not found: $RUNTIME_PATH"
    exit 1
}

$XYC_L3 = Join-Path $L3_OUTPUT_DIR "xyc_l3.exe"
Write-Host "  Linking: $XYC_L3"
clang $RUNTIME_PATH $L3_OBJ_FILE -o $XYC_L3 "-Wl,/subsystem:console"
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK: L3 compiler created: $XYC_L3"
} else {
    Write-Host "FAIL: Link failed"
    exit 1
}
Write-Host ""

Write-Host "========================================"
Write-Host "  L3 自举测试完成！"
Write-Host "========================================"
Write-Host ""
Write-Host "Generated files:"
Write-Host "  - L3 IR: $L3_IR_FILE"
Write-Host "  - L3 Object: $L3_OBJ_FILE"
Write-Host "  - L3 Compiler: $XYC_L3"
Write-Host ""
Write-Host "Next steps:"
Write-Host "  1. Verify L3 compiler"
Write-Host "  2. Compare L1 and L3 IR"
Write-Host ""
exit 0

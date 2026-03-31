# 简单版 L2 编译器构建脚本
$ErrorActionPreference = "Stop"

$PROJECT_ROOT = $PSScriptRoot
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "target\l2_compiler"

# 创建输出目录
if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building L2 Compiler" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$XY_MODULES = @(
    "runtime.xy",
    "lexer.xy",
    "parser.xy",
    "sema.xy",
    "codegen.xy",
    "main.xy"
)

Write-Host "[Step 1] Compiling modules to IR" -ForegroundColor Yellow
$irFiles = @()

foreach ($module in $XY_MODULES) {
    $sourcePath = Join-Path $SRC_DIR $module
    $irPath = Join-Path $OUTPUT_DIR "$module.ll"
    
    Write-Host "Compiling: $module"
    
    # 编译模块
    $output = & cargo run --release -- $sourcePath --ir-pure 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Failed to compile $module" -ForegroundColor Red
        Write-Host $output
        exit 1
    }
    
    # 保存 IR
    $output | Out-File -FilePath $irPath -Encoding utf8
    $irFiles += $irPath
    Write-Host "  OK: $irPath" -ForegroundColor Green
}

Write-Host ""
Write-Host "[Step 2] Compiling IR to object files" -ForegroundColor Yellow
$objFiles = @()

foreach ($irFile in $irFiles) {
    $objFile = "$irFile.o"
    Write-Host "Compiling: $(Split-Path $irFile -Leaf)"
    
    & llc $irFile -filetype=obj -o $objFile
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: LLC failed for $irFile" -ForegroundColor Red
        exit 1
    }
    
    $objFiles += $objFile
    Write-Host "  OK: $objFile" -ForegroundColor Green
}

Write-Host ""
Write-Host "[Step 3] Linking executable" -ForegroundColor Yellow
$xycExe = Join-Path $OUTPUT_DIR "xyc.exe"
$runtimePath = Join-Path $PROJECT_ROOT "runtime\runtime.c"

& clang $runtimePath $objFiles -o $xycExe
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Linking failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  L2 Compiler built successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Executable: $xycExe" -ForegroundColor Cyan
Write-Host ""

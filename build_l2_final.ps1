# 最终版 L2 编译器构建脚本 - 参考测试脚本
$ErrorActionPreference = "Continue"

$PROJECT_ROOT = $PSScriptRoot
$SRC_DIR = "$PROJECT_ROOT\src\compiler_v2"
$OUTPUT_DIR = "$PROJECT_ROOT\target\l2_compiler"

# 清理输出目录
if (Test-Path $OUTPUT_DIR) {
    Remove-Item -Path $OUTPUT_DIR -Recurse -Force
}
New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Building L2 Compiler" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$modules = @("runtime.xy", "lexer.xy", "parser.xy", "sema.xy", "codegen.xy", "utils.xy", "main.xy")
$irFiles = @()
$objFiles = @()

Write-Host "`nStep 1: Compiling modules to IR" -ForegroundColor Yellow
foreach ($module in $modules) {
    $src = "$SRC_DIR\$module"
    $ir = "$OUTPUT_DIR\$module.ll"
    
    Write-Host "  Compiling $module..."
    
    # 使用 --ir 参数（不是 --ir-pure）
    $output = & cargo run --release -- $src --ir 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ERROR: Failed to compile $module" -ForegroundColor Red
        Write-Host $output
        exit 1
    }
    
    # 不过滤，直接保存所有输出，让 LLC 自己处理
    $output | Out-File -FilePath $ir -Encoding UTF8
    
    $irFiles += $ir
    Write-Host "    OK: $ir" -ForegroundColor Green
}

Write-Host "`nStep 2: Compiling IR to object files" -ForegroundColor Yellow
foreach ($ir in $irFiles) {
    $obj = "$ir.o"
    Write-Host "  Compiling $(Split-Path $ir -Leaf)..."
    
    & llc $ir -filetype=obj -o $obj
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ERROR: LLC failed for $ir" -ForegroundColor Red
        exit 1
    }
    
    $objFiles += $obj
    Write-Host "    OK: $obj" -ForegroundColor Green
}

Write-Host "`nStep 3: Linking" -ForegroundColor Yellow
$xyc = "$OUTPUT_DIR\xyc.exe"
$runtime = "$PROJECT_ROOT\runtime\runtime.c"

Write-Host "  Linking with clang..."
& clang $runtime $objFiles -o $xyc

if ($LASTEXITCODE -ne 0) {
    Write-Host "    ERROR: Linking failed" -ForegroundColor Red
    exit 1
}

Write-Host "    OK: $xyc" -ForegroundColor Green
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  L2 Compiler Build Success!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Executable: $xyc" -ForegroundColor Cyan

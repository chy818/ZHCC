# Simple L2 Verification Script
# 简化版 L2 验证脚本
# 目标：验证 Rust 编译器可以完整编译并运行自展编译器的核心功能

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  简化版 L2 验证" -ForegroundColor Cyan
Write-Host "  XY 编译器自举能力测试" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$PROJECT_ROOT = $PSScriptRoot | Split-Path
$XY_COMPILER = Join-Path $PROJECT_ROOT "target\debug\xy.exe"
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "target\l2_verification"

# 创建输出目录
if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null
}

$XY_MODULES = @(
    "runtime.xy",
    "lexer.xy",
    "parser.xy",
    "sema.xy",
    "codegen.xy",
    "main.xy"
)

$TOTAL_TESTS = 0
$PASSED_TESTS = 0
$FAILED_TESTS = 0

function Test-Compile-Module {
    param (
        [string]$ModuleName,
        [string]$ModulePath
    )
    
    $script:TOTAL_TESTS++
    
    Write-Host "----------------------------------------"
    Write-Host "测试 $TOTAL_TESTS : 编译 $ModuleName"
    Write-Host "----------------------------------------"
    
    if (-not (Test-Path $ModulePath)) {
        Write-Host "[FAIL] 文件不存在: $ModulePath" -ForegroundColor Red
        $script:FAILED_TESTS++
        return $false
    }
    
    $output = & $XY_COMPILER $ModulePath --ir 2>&1
    $exitCode = $LASTEXITCODE
    
    $hasError = $output -match "错误:|error:|Error:|FAIL|fail:"
    $isSuccess = $exitCode -eq 0 -and (-not $hasError)
    
    if ($isSuccess) {
        Write-Host "[PASS] $ModuleName 编译成功" -ForegroundColor Green
        $script:PASSED_TESTS++
        
        # 保存 IR
        $irFileName = [System.IO.Path]::GetFileName($ModulePath) + ".ll"
        $irFilePath = Join-Path $OUTPUT_DIR $irFileName
        $output | Out-File -FilePath $irFilePath -Encoding utf8
        Write-Host "  IR 已保存: $irFilePath"
        
        return $true
    } else {
        Write-Host "[FAIL] $ModuleName 编译失败 (退出码: $exitCode)" -ForegroundColor Red
        if ($output) {
            Write-Host $output
        }
        $script:FAILED_TESTS++
        return $false
    }
    Write-Host ""
}

function Test-Build-And-Run {
    param (
        [string]$TestName,
        [string]$SourceFile
    )
    
    $script:TOTAL_TESTS++
    
    Write-Host "----------------------------------------"
    Write-Host "测试 $TOTAL_TESTS : $TestName"
    Write-Host "----------------------------------------"
    
    if (-not (Test-Path $SourceFile)) {
        Write-Host "[FAIL] 文件不存在: $SourceFile" -ForegroundColor Red
        $script:FAILED_TESTS++
        return $false
    }
    
    $output = & $XY_COMPILER $SourceFile --run 2>&1
    $exitCode = $LASTEXITCODE
    
    $hasError = $output -match "错误:|error:|Error:|FAIL|fail:"
    $isSuccess = $exitCode -eq 0 -and (-not $hasError) -and ($output -match "编译成功" -or $output -match "运行结果")
    
    if ($isSuccess) {
        Write-Host "[PASS] $TestName 成功" -ForegroundColor Green
        $script:PASSED_TESTS++
        Write-Host "  输出:"
        Write-Host $output
        return $true
    } else {
        Write-Host "[FAIL] $TestName 失败 (退出码: $exitCode)" -ForegroundColor Red
        if ($output) {
            Write-Host $output
        }
        $script:FAILED_TESTS++
        return $false
    }
    Write-Host ""
}

Write-Host "Phase 1: Checking Rust compiler"
if (-not (Test-Path $XY_COMPILER)) {
    Write-Host "[错误] 找不到编译器: $XY_COMPILER" -ForegroundColor Red
    Write-Host "请先运行: cargo build"
    exit 1
}
Write-Host "[OK] 编译器存在: $XY_COMPILER" -ForegroundColor Green
Write-Host ""

Write-Host "[阶段 2: 编译所有自展编译器模块]"
Write-Host "========================================"
Write-Host ""

foreach ($module in $XY_MODULES) {
    $fullPath = Join-Path $SRC_DIR $module
    Test-Compile-Module $module $fullPath
}

Write-Host ""
Write-Host "[阶段 3: 测试完整编译和运行]"
Write-Host "========================================"
Write-Host ""

$helloPath = Join-Path $PROJECT_ROOT "examples\hello.xy"
Test-Build-And-Run "Hello World 完整编译" $helloPath

Write-Host ""
Write-Host "========================================"
Write-Host "  L2 验证结果总结"
Write-Host "========================================"
Write-Host "  总测试数: $TOTAL_TESTS"
Write-Host "  通过:     $PASSED_TESTS"
Write-Host "  失败:     $FAILED_TESTS"
Write-Host "========================================"
Write-Host ""

if ($FAILED_TESTS -eq 0) {
    Write-Host "🎉 L2 验证全部通过！" -ForegroundColor Green
    Write-Host ""
    Write-Host "✅ Rust 编译器可以完整编译所有自展模块"
    Write-Host "✅ 可以完整编译和运行示例程序"
    Write-Host ""
    Write-Host "下一步: 准备 L3 自展验证"
    exit 0
} else {
    Write-Host "❌ L2 验证有 $FAILED_TESTS 个测试失败" -ForegroundColor Red
    exit 1
}

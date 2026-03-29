# L3 Bootstrap Verification Framework
# L3 自展验证框架
# 完整的 L1 + L2 + L3 验证流程

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  L3 自展验证框架" -ForegroundColor Cyan
Write-Host "  玄语编译器完整自举验证" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$PROJECT_ROOT = $PSScriptRoot | Split-Path
$TESTS_DIR = $PSScriptRoot
$L1_SNAPSHOT_DIR = Join-Path $PROJECT_ROOT "target\l1_snapshot"
$L2_DIR = Join-Path $PROJECT_ROOT "target\l2_compiler"
$L3_OUTPUT_DIR = Join-Path $PROJECT_ROOT "target\l3_output"

$XY_MODULES = @(
    "runtime.xy",
    "lexer.xy",
    "parser.xy",
    "sema.xy",
    "codegen.xy",
    "main.xy"
)

Write-Host "[配置]"
Write-Host "  项目根目录: $PROJECT_ROOT"
Write-Host "  L1 快照目录: $L1_SNAPSHOT_DIR"
Write-Host "  L2 编译器目录: $L2_DIR"
Write-Host "  L3 输出目录: $L3_OUTPUT_DIR"
Write-Host ""

function Step-1-Take-L1-Snapshot {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  步骤 1/4: 创建 L1 基准快照" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    
    & (Join-Path $TESTS_DIR "l1_take_snapshot.ps1")
    $exitCode = $LASTEXITCODE
    
    if ($exitCode -ne 0) {
        Write-Host "[错误] L1 快照创建失败" -ForegroundColor Red
        exit $exitCode
    }
    
    Write-Host "[OK] L1 基准快照创建成功" -ForegroundColor Green
}

function Step-2-Verify-L2-Compiler {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  步骤 2/4: 验证 L2 编译器" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "[注意] L2 编译器正在开发中" -ForegroundColor Yellow
    Write-Host "[跳过] 等待 L2 编译器完善后执行" -ForegroundColor Yellow
    
    return $true
}

function Step-3-Compile-With-L2 {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  步骤 3/4: 用 L2 编译器编译模块" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "[注意] 需要先完成 L2 编译器" -ForegroundColor Yellow
    Write-Host "[跳过] 等待 L2 编译器就绪" -ForegroundColor Yellow
    
    return $true
}

function Step-4-Compare-L1-L3 {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host "  步骤 4/4: 比较 L1 和 L3 结果" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    
    Write-Host "[注意] 需要先完成步骤 1-3" -ForegroundColor Yellow
    Write-Host "[跳过] 等待 L2 和 L3 输出就绪" -ForegroundColor Yellow
    
    return $true
}

function Show-Summary {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  L3 验证框架已就绪" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "可用的工具:"
    Write-Host "  1. l1_take_snapshot.ps1  - 创建 L1 基准快照"
    Write-Host "  2. compare_ir.ps1       - 比较两个 IR 文件"
    Write-Host "  3. l3_bootstrap_verification.ps1 - 完整验证流程（本脚本）"
    Write-Host ""
    Write-Host "当前状态:"
    Write-Host "  ✅ L1: 可用（Rust 编译器）"
    Write-Host "  ⏸️ L2: 开发中（模块导入功能已验证）"
    Write-Host "  ⏸️ L3: 等待 L2 完成"
    Write-Host ""
    Write-Host "下一步:"
    Write-Host "  1. 先运行: .\tests\l1_take_snapshot.ps1"
    Write-Host "  2. 继续完善 L2 编译器"
    Write-Host "  3. 等 L2 完成后运行完整验证"
    Write-Host ""
}

# 主流程
Step-1-Take-L1-Snapshot
Step-2-Verify-L2-Compiler
Step-3-Compile-With-L2
Step-4-Compare-L1-L3
Show-Summary

Write-Host ""
Write-Host "🎉 L3 验证框架设置完成！" -ForegroundColor Green
exit 0

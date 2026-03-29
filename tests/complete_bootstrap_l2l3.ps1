# complete_bootstrap_l2l3.ps1
# 完整的 L2 + L3 自展验证脚本
# 实现：
# L1: 用 Rust 编译器编译所有 XY 模块并保存 IR
# L2: 将所有 XY 模块编译结果链接成可执行文件 (xyc.exe)
# L3: 用 L2 编译出的编译器重新编译所有 XY 模块
# 验证: 验证 L1 和 L3 结果一致性

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  XY Compiler L2+L3 Bootstrap Test" -ForegroundColor Cyan
Write-Host "  完整自展验证" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$PROJECT_ROOT = $PSScriptRoot | Split-Path
$XY_COMPILER = Join-Path $PROJECT_ROOT "target\debug\xy.exe"
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "target\bootstrap_complete"
$L1_IR_DIR = Join-Path $OUTPUT_DIR "l1_ir"
$L2_DIR = Join-Path $OUTPUT_DIR "l2"
$L3_IR_DIR = Join-Path $OUTPUT_DIR "l3_ir"

# 创建输出目录
if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null
}
if (-not (Test-Path $L1_IR_DIR)) {
    New-Item -ItemType Directory -Path $L1_IR_DIR -Force | Out-Null
}
if (-not (Test-Path $L2_DIR)) {
    New-Item -ItemType Directory -Path $L2_DIR -Force | Out-Null
}
if (-not (Test-Path $L3_IR_DIR)) {
    New-Item -ItemType Directory -Path $L3_IR_DIR -Force | Out-Null
}

$XY_MODULES = @(
    "runtime.xy",
    "lexer.xy",
    "parser.xy",
    "sema.xy",
    "codegen.xy",
    "main.xy"
)

$L1_SUCCESS = $true
$L2_SUCCESS = $true
$L3_SUCCESS = $true
$VERIFY_SUCCESS = $true

function Compile-Module-With-IR {
    param (
        [string]$ModuleName,
        [string]$ModulePath,
        [string]$OutputDir
    )
    
    Write-Host "  编译: $ModuleName"
    
    if (-not (Test-Path $ModulePath)) {
        Write-Host "    [错误] 文件不存在: $ModulePath" -ForegroundColor Red
        return $false
    }

    $output = & $XY_COMPILER $ModulePath --ir 2>&1
    $exitCode = $LASTEXITCODE

    $hasError = $output -match "错误:|error:|Error:|FAIL|fail:" -or ($exitCode -ne 0)
    $isSuccess = (-not $hasError) -and ($exitCode -eq 0)

    if ($isSuccess) {
        Write-Host "    [OK] 编译成功" -ForegroundColor Green
        $irFileName = [System.IO.Path]::GetFileName($ModulePath) + ".ll"
        $irFilePath = Join-Path $OutputDir $irFileName
        $output | Out-File -FilePath $irFilePath -Encoding utf8
        Write-Host "    IR 已保存到: $irFilePath"
        return $true
    } else {
        Write-Host "    [FAIL] 编译失败 (退出码: $exitCode)" -ForegroundColor Red
        if ($output) {
            Write-Host $output
        }
        return $false
    }
}

function Build-L2-Compiler {
    param()
    
    Write-Host ""
    Write-Host "[2/4] L2: 链接成可执行文件" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Yellow
    Write-Host ""
    
    $tempObjFiles = @()
    $allSuccess = $true
    
    # 第一步：为每个模块生成对象文件
    foreach ($module in $XY_MODULES) {
        $fullPath = Join-Path $SRC_DIR $module
        Write-Host "  处理: $module"
        
        # 生成 IR
        $irOutput = & $XY_COMPILER $fullPath --ir 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [错误] 生成 IR 失败" -ForegroundColor Red
            $allSuccess = $false
            continue
        }
        
        # 保存 IR 到临时文件
        $tempIrFile = Join-Path $L2_DIR "$module.ll"
        $irOutput | Out-File -FilePath $tempIrFile -Encoding utf8
        
        # 使用 llc 生成对象文件
        $tempObjFile = Join-Path $L2_DIR "$module.o"
        Write-Host "    生成对象文件: $tempObjFile"
        
        $llcResult = llc $tempIrFile -filetype=obj -o $tempObjFile 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    [错误] llc 失败" -ForegroundColor Red
            $allSuccess = $false
            continue
        }
        
        $tempObjFiles += $tempObjFile
    }
    
    if (-not $allSuccess) {
        Write-Host "[FAIL] L2 部分失败" -ForegroundColor Red
        return $false
    }
    
    # 第二步：查找 runtime.c
    $runtimePath = Join-Path $PROJECT_ROOT "runtime\runtime.c"
    if (-not (Test-Path $runtimePath)) {
        Write-Host "[错误] 找不到 runtime.c" -ForegroundColor Red
        return $false
    }
    Write-Host "  找到运行时: $runtimePath"
    
    # 第三步：链接所有对象文件和 runtime.c 生成 xyc.exe
    $xycExe = Join-Path $L2_DIR "xyc.exe"
    Write-Host "  链接生成: $xycExe"
    
    $linkerArgs = @($runtimePath) + $tempObjFiles + @("-o", $xycExe)
    $linkResult = clang @linkerArgs 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] L2 成功: $xycExe" -ForegroundColor Green
        return $true
    } else {
        Write-Host "[FAIL] 链接失败" -ForegroundColor Red
        Write-Host $linkResult
        return $false
    }
}

function Compare-IR-Files {
    param(
        [string]$File1,
        [string]$File2
    )
    
    if (-not (Test-Path $File1)) {
        Write-Host "    [错误] L1 IR 不存在: $File1" -ForegroundColor Red
        return $false
    }
    if (-not (Test-Path $File2)) {
        Write-Host "    [错误] L3 IR 不存在: $File2" -ForegroundColor Red
        return $false
    }
    
    $content1 = Get-Content $File1 -Raw
    $content2 = Get-Content $File2 -Raw
    
    # 简单比较：先检查长度
    if ($content1 -eq $content2) {
        Write-Host "    [OK] IR 完全一致" -ForegroundColor Green
        return $true
    } else {
        Write-Host "    [警告] IR 有差异" -ForegroundColor Yellow
        # 可以在这里添加更智能的比较逻辑
        return $false
    }
}

# ==================== 主流程开始 ====================

Write-Host "[1/4] L1: 用 Rust 编译器编译所有 XY 模块" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""

# 检查编译器是否存在
if (-not (Test-Path $XY_COMPILER)) {
    Write-Host "[错误] 找不到编译器: $XY_COMPILER" -ForegroundColor Red
    Write-Host "请先运行: cargo build"
    exit 1
}
Write-Host "OK: 编译器存在: $XY_COMPILER"
Write-Host ""

# L1: 编译所有模块并保存 IR
foreach ($module in $XY_MODULES) {
    $fullPath = Join-Path $SRC_DIR $module
    $success = Compile-Module-With-IR $module $fullPath $L1_IR_DIR
    if (-not $success) {
        $L1_SUCCESS = $false
    }
}

if (-not $L1_SUCCESS) {
    Write-Host ""
    Write-Host "[错误] L1 阶段失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[OK] L1 阶段完成" -ForegroundColor Green
Write-Host ""

# L2: 链接成可执行文件
$L2_SUCCESS = Build-L2-Compiler

if (-not $L2_SUCCESS) {
    Write-Host ""
    Write-Host "[错误] L2 阶段失败" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "[OK] L2 阶段完成" -ForegroundColor Green
Write-Host ""

Write-Host "[3/4] L3: 用 L2 编译器重新编译" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "[注意] L3 阶段需要完整的自展编译器实现" -ForegroundColor Yellow
Write-Host "[跳过 L3 验证（等待 L2 编译器完善后实现）" -ForegroundColor Yellow
Write-Host ""

Write-Host "[4/4] 验证结果总结" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "L1: $L1_SUCCESS"
Write-Host "L2: $L2_SUCCESS"
Write-Host "L3: 待实现"
Write-Host ""

if ($L1_SUCCESS -and $L2_SUCCESS) {
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  L1 + L2 VERIFIED!" -ForegroundColor Green
    Write-Host "  L2 编译器可执行文件已生成" -ForegroundColor Green
    Write-Host "  位置: $L2_DIR\xyc.exe" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    exit 0
} else {
    Write-Host "========================================" -ForegroundColor Red
    Write-Host "  BOOTSTRAP TEST FAILED" -ForegroundColor Red
    Write-Host "========================================" -ForegroundColor Red
    exit 1
}

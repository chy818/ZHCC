# bootstrap_final.ps1
# ========================================
# 玄语编译器完整自展验证脚本
# ========================================
# 
# 自展三阶段说明：
# 
# L1 (Bootstrap Level 1):
#   - 使用 Rust 编写的 xy.exe 编译所有 XY 模块
#   - 目标：验证每个模块可以独立编译
#   - 输出：每个模块的 LLVM IR 文件
# 
# L2 (Bootstrap Level 2):
#   - 将 L1 编译的所有模块链接成可执行文件 xyc.exe
#   - 目标：验证可以生成完整的自展编译器
#   - 输出：xyc.exe (自展编译器)
# 
# L3 (Bootstrap Level 3):
#   - 使用 L2 生成的 xyc.exe 重新编译所有 XY 模块
#   - 目标：验证自展编译器功能正常
#   - 输出：L3 阶段的 LLVM IR 文件
# 
# 验证阶段：
#   - 对比 L1 和 L3 生成的 IR 是否一致
#   - 目标：确保自展结果正确
#
# ========================================

$ErrorActionPreference = "Continue"

Write-Host "========================================"
Write-Host "  玄语编译器完整自展验证"
Write-Host "  Complete Bootstrap Test"
Write-Host "========================================"
Write-Host ""

# ==================== 配置 ====================

$PROJECT_ROOT = Split-Path -Parent $PSScriptRoot
$XY_COMPILER = Join-Path $PROJECT_ROOT "target\debug\xy.exe"
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "target\bootstrap_final"
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

# 创建输出目录
New-Item -ItemType Directory -Force -Path $OUTPUT_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $L1_IR_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $L2_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $L3_IR_DIR | Out-Null

$L1_SUCCESS = $true
$L2_SUCCESS = $true
$L3_SUCCESS = $true
$VERIFY_SUCCESS = $true

# ==================== 辅助函数 ====================

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
    
    Write-Host "编译: $ModuleName"
    
    if (-not (Test-Path $ModulePath)) {
        Write-Host "  [跳过] 文件不存在: $ModulePath"
        return $false
    }

    $output = & $CompilerPath $ModulePath --ir 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "  [OK] 编译成功"
        $irFile = Join-Path $OutputDir "$ModuleName.ll"
        $output | Out-File -FilePath $irFile -Encoding utf8
        Write-Host "  IR 已保存到: $irFile"
        return $true
    } else {
        Write-Host "  [失败] 编译失败 (退出码: $exitCode)"
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
            Write-Host "  [跳过] $module (无 IR)"
            continue
        }
        
        Write-Host "  生成对象文件: $module"
        llc $irPath -filetype=obj -o $objPath
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "    [OK]"
            $objFiles += $objPath
        } else {
            Write-Host "    [失败]"
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
    
    Write-Host "对比: $ModuleName"
    
    if (-not (Test-Path $L1IrPath)) {
        Write-Host "  [失败] L1 IR 不存在"
        return $false
    }
    if (-not (Test-Path $L3IrPath)) {
        Write-Host "  [失败] L3 IR 不存在"
        return $false
    }
    
    $content1 = Get-Content $L1IrPath -Raw
    $content2 = Get-Content $L3IrPath -Raw
    
    if ($content1 -eq $content2) {
        Write-Host "  [OK] IR 一致"
        return $true
    } else {
        Write-Host "  [警告] IR 有差异"
        return $false
    }
}

# ==================== L1 阶段 ====================

Write-PhaseHeader "L1: 使用 Rust 编译器编译所有 XY 模块"

# 检查编译器
if (-not (Test-Path $XY_COMPILER)) {
    Write-Host "[错误] 找不到编译器: $XY_COMPILER"
    Write-Host "请先运行: cargo build"
    exit 1
}
Write-Host "编译器: $XY_COMPILER"
Write-Host ""

foreach ($module in $XY_MODULES) {
    $fullPath = Join-Path $SRC_DIR $module
    $success = Compile-Single-Module $module $fullPath $L1_IR_DIR $XY_COMPILER
    if (-not $success) {
        $L1_SUCCESS = $false
    }
}

Write-Host ""
Write-Host "L1 阶段总结: $(if ($L1_SUCCESS) { "成功" } else { "失败" })"
if (-not $L1_SUCCESS) {
    Write-Host "注意: 部分模块编译失败，L2 阶段将使用成功编译的模块继续"
}

# ==================== L2 阶段 ====================

Write-PhaseHeader "L2: 链接成自展编译器 (xyc.exe)"

$objFiles = Build-Object-Files $L1_IR_DIR $L2_DIR

$runtimePath = Join-Path $PROJECT_ROOT "runtime\runtime.c"
if (-not (Test-Path $runtimePath)) {
    Write-Host "[错误] 找不到 runtime.c"
    $L2_SUCCESS = $false
} else {
    $xycExe = Join-Path $L2_DIR "xyc.exe"
    Write-Host ""
    Write-Host "链接生成可执行文件: $xycExe"
    
    if ($objFiles.Count -gt 0) {
        clang $runtimePath $objFiles -o $xycExe
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK] L2 成功: $xycExe"
            $L2_SUCCESS = $true
        } else {
            Write-Host "[失败] 链接失败"
            $L2_SUCCESS = $false
        }
    } else {
        Write-Host "[跳过] 没有成功编译的模块可以链接"
        $L2_SUCCESS = $false
    }
}

Write-Host ""
Write-Host "L2 阶段总结: $(if ($L2_SUCCESS) { "成功" } else { "失败" })"

# ==================== L3 阶段 ====================

Write-PhaseHeader "L3: 使用自展编译器重新编译"

if ($L2_SUCCESS) {
    $xycExe = Join-Path $L2_DIR "xyc.exe"
    Write-Host "使用编译器: $xycExe"
    Write-Host ""
    
    foreach ($module in $XY_MODULES) {
        $fullPath = Join-Path $SRC_DIR $module
        $success = Compile-Single-Module $module $fullPath $L3_IR_DIR $xycExe
        if (-not $success) {
            $L3_SUCCESS = $false
        }
    }
} else {
    Write-Host "[跳过] L2 未成功，无法进行 L3"
    $L3_SUCCESS = $false
}

Write-Host ""
Write-Host "L3 阶段总结: $(if ($L3_SUCCESS) { "成功" } else { "失败" })"

# ==================== 验证阶段 ====================

Write-PhaseHeader "验证 L1 和 L3 结果一致性"

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
    Write-Host "[跳过] L1 或 L3 未成功"
    $VERIFY_SUCCESS = $false
}

Write-Host ""
Write-Host "验证阶段总结: $(if ($VERIFY_SUCCESS) { "成功" } else { "失败" })"

# ==================== 最终总结 ====================

Write-PhaseHeader "自展验证最终结果"

Write-Host "L1 (Rust 编译):        $(if ($L1_SUCCESS) { "成功" } else { "失败" })"
Write-Host "L2 (链接成可执行文件):  $(if ($L2_SUCCESS) { "成功" } else { "失败" })"
Write-Host "L3 (自展重新编译):      $(if ($L3_SUCCESS) { "成功" } else { "失败" })"
Write-Host "验证 (L1 vs L3):        $(if ($VERIFY_SUCCESS) { "成功" } else { "失败" })"
Write-Host ""

$allOk = $L1_SUCCESS -and $L2_SUCCESS -and $L3_SUCCESS -and $VERIFY_SUCCESS

if ($allOk) {
    Write-Host "========================================"
    Write-Host "  自展验证完全通过！"
    Write-Host "  FULL BOOTSTRAP SUCCESS!"
    Write-Host "========================================"
    exit 0
} else {
    Write-Host "========================================"
    Write-Host "  自展验证部分失败"
    Write-Host "  BOOTSTRAP INCOMPLETE"
    Write-Host "========================================"
    Write-Host ""
    Write-Host "输出目录: $OUTPUT_DIR"
    Write-Host "  - L1 IR: $L1_IR_DIR"
    Write-Host "  - L2 编译器: $L2_DIR"
    Write-Host "  - L3 IR: $L3_IR_DIR"
    exit 1
}

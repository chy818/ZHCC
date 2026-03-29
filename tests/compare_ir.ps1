# IR Compare Tool
# IR 比较工具
# 比较两个 LLVM IR 文件，忽略不重要的差异

param(
    [string]$File1,
    [string]$File2,
    [switch]$Verbose
)

$ErrorActionPreference = "Continue"

function Normalize-IR {
    param([string]$IR)
    
    $lines = $IR -split "`n"
    $normalized = @()
    
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        
        if ($trimmed -eq "" -or $trimmed.StartsWith(";")) {
            continue
        }
        
        # 忽略局部变量名（%tmp_123, %v_456 等）
        $processed = $trimmed
        
        # 替换临时变量名
        $processed = $processed -replace '%tmp_\d+', '%TMP_VAR'
        $processed = $processed -replace '%v_\d+', '%V_VAR'
        $processed = $processed -replace '%alloca_\d+', '%ALLOCA_VAR'
        $processed = $processed -replace '%lit_\d+', '%LIT_VAR'
        $processed = $processed -replace '%id_\d+', '%ID_VAR'
        $processed = $processed -replace '%binop_\d+', '%BINOP_VAR'
        $processed = $processed -replace '%call_\d+', '%CALL_VAR'
        $processed = $processed -replace '%cond_bool_\d+', '%COND_VAR'
        
        # 替换标签名
        $processed = $processed -replace 'entry_\d+', 'ENTRY_BLOCK'
        $processed = $processed -replace 'then_\d+', 'THEN_BLOCK'
        $processed = $processed -replace 'else_\d+', 'ELSE_BLOCK'
        $processed = $processed -replace 'ifend_\d+', 'IFEND_BLOCK'
        $processed = $processed -replace 'loop_start_\d+', 'LOOP_START'
        $processed = $processed -replace 'loop_body_\d+', 'LOOP_BODY'
        $processed = $processed -replace 'loop_end_\d+', 'LOOP_END'
        
        # 替换字符串常量名
        $processed = $processed -replace '@str_\d+', '@STR_CONST'
        
        # 替换全局变量名
        $processed = $processed -replace '@global_\d+', '@GLOBAL_VAR'
        
        $normalized += $processed
    }
    
    return ($normalized -join "`n")
}

function Get-IR-Signature {
    param([string]$IR)
    
    $lines = $IR -split "`n"
    $sig = @()
    
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        
        if ($trimmed -match "^define ") {
            $sig += $trimmed
        } elseif ($trimmed -match "^declare ") {
            $sig += $trimmed
        }
    }
    
    return ($sig -join "`n")
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  IR 比较工具" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if (-not $File1 -or -not $File2) {
    Write-Host "用法: .\compare_ir.ps1 -File1 <文件1> -File2 <文件2> [-Verbose]"
    Write-Host ""
    Write-Host "示例:"
    Write-Host "  .\compare_ir.ps1 -File1 l1.ll -File2 l3.ll"
    Write-Host "  .\compare_ir.ps1 -File1 l1.ll -File2 l3.ll -Verbose"
    exit 1
}

if (-not (Test-Path $File1)) {
    Write-Host "[错误] 文件不存在: $File1" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $File2)) {
    Write-Host "[错误] 文件不存在: $File2" -ForegroundColor Red
    exit 1
}

Write-Host "文件 1: $File1"
Write-Host "文件 2: $File2"
Write-Host ""

$ir1 = Get-Content $File1 -Raw
$ir2 = Get-Content $File2 -Raw

$size1 = $ir1.Length
$size2 = $ir2.Length

Write-Host "原始大小:"
Write-Host "  文件 1: $size1 字节"
Write-Host "  文件 2: $size2 字节"
Write-Host ""

# 比较函数签名
$sig1 = Get-IR-Signature $ir1
$sig2 = Get-IR-Signature $ir2

if ($sig1 -eq $sig2) {
    Write-Host "[OK] 函数签名一致" -ForegroundColor Green
} else {
    Write-Host "[FAIL] 函数签名不一致" -ForegroundColor Red
    if ($Verbose) {
        Write-Host ""
        Write-Host "--- 文件 1 签名 ---"
        Write-Host $sig1
        Write-Host ""
        Write-Host "--- 文件 2 签名 ---"
        Write-Host $sig2
    }
}
Write-Host ""

# 标准化后比较
$norm1 = Normalize-IR $ir1
$norm2 = Normalize-IR $ir2

if ($norm1 -eq $norm2) {
    Write-Host "[OK] IR 标准化后一致" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎉 两个 IR 文件功能等价！" -ForegroundColor Green
    exit 0
} else {
    Write-Host "[FAIL] IR 标准化后有差异" -ForegroundColor Red
    
    if ($Verbose) {
        Write-Host ""
        Write-Host "--- 详细比较 ---"
        
        $lines1 = $norm1 -split "`n"
        $lines2 = $norm2 -split "`n"
        
        $maxLines = [Math]::Max($lines1.Count, $lines2.Count)
        
        for ($i = 0; $i -lt $maxLines; $i++) {
            $l1 = if ($i -lt $lines1.Count) { $lines1[$i] } else { "" }
            $l2 = if ($i -lt $lines2.Count) { $lines2[$i] } else { "" }
            
            if ($l1 -ne $l2) {
                Write-Host "行 $($i+1):" -ForegroundColor Yellow
                Write-Host "  < $l1" -ForegroundColor Red
                Write-Host "  > $l2" -ForegroundColor Green
            }
        }
    }
    
    exit 1
}

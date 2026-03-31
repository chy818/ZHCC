# L2 编译器链接脚本 - 简化版
# 使用 L1 编译器编译 L2 的各个模块，然后链接成 xyc.exe
param(
    [switch]$Clean
)

$ErrorActionPreference = "Stop"

$PROJECT_ROOT = $PSScriptRoot
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "target\l2_compiler"

# 创建输出目录
if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null
}

# 清理选项
if ($Clean) {
    Write-Host "清理输出目录..." -ForegroundColor Yellow
    Remove-Item "$OUTPUT_DIR\*" -Force -Recurse -ErrorAction SilentlyContinue
    Write-Host "清理完成" -ForegroundColor Green
    exit 0
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  L2 编译器链接脚本" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# L2 模块列表（按依赖顺序）
$XY_MODULES = @(
    "runtime.xy",
    "lexer.xy",
    "parser.xy",
    "sema.xy",
    "codegen.xy",
    "utils.xy",
    "main.xy"
)

Write-Host "[步骤 1] 编译 L2 模块到 LLVM IR" -ForegroundColor Yellow
$irFiles = @()

foreach ($module in $XY_MODULES) {
    $sourcePath = Join-Path $SRC_DIR $module
    $irPath = Join-Path $OUTPUT_DIR "$module.ll"
    $tempOutput = Join-Path $OUTPUT_DIR "temp_$module.ll"

    Write-Host "  编译: $module" -NoNewline

    # 使用 L1 编译器编译模块
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "cargo"
    $psi.Arguments = "run --release -- `"$sourcePath`" --ir-pure"
    $psi.WorkingDirectory = $PROJECT_ROOT
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        Write-Host " [失败]" -ForegroundColor Red
        Write-Host "错误: 模块 $module 编译失败" -ForegroundColor Red
        Write-Host $stderr -ForegroundColor Red
        exit 1
    }

    # 保存 IR 到临时文件
    $stdout | Set-Content -Path $tempOutput -Encoding UTF8

    # 读取并清理内容
    $content = Get-Content $tempOutput -Raw -Encoding UTF8
    Remove-Item $tempOutput -Force

    # 移除 BOM
    if ($content.Length -gt 0 -and [int]$content[0] -eq 0xFEFF) {
        $content = $content.Substring(1)
    }

    # 清理内容：去除开头的空行
    $content = $content.TrimStart()

    # 保存清理后的内容
    $content | Set-Content -Path $irPath -Encoding UTF8 -NoNewline

    $irFiles += $irPath
    Write-Host " [成功]" -ForegroundColor Green
}

Write-Host ""
Write-Host "[步骤 2] 使用 LLC 编译 IR 到对象文件" -ForegroundColor Yellow
$objFiles = @()

foreach ($irFile in $irFiles) {
    $objFile = "$irFile.o"
    $moduleName = Split-Path $irFile -Leaf
    Write-Host "  编译: $moduleName" -NoNewline

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "llc"
    $psi.Arguments = "`"$irFile`" -filetype=obj -o `"$objFile`""
    $psi.WorkingDirectory = $PROJECT_ROOT
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($psi)
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        Write-Host " [失败]" -ForegroundColor Red
        Write-Host "LLC 错误: $stderr" -ForegroundColor Red
        exit 1
    }

    $objFiles += $objFile
    Write-Host " [成功]" -ForegroundColor Green
}

Write-Host ""
Write-Host "[步骤 3] 使用 clang 链接成可执行文件" -ForegroundColor Yellow
$xycExe = Join-Path $OUTPUT_DIR "xyc.exe"
$runtimePath = Join-Path $PROJECT_ROOT "runtime\runtime.c"

Write-Host "  链接所有对象文件..." -NoNewline

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "clang"
$psi.Arguments = "`"$runtimePath`" $objFiles -o `"$xycExe`" -target x86_64-pc-windows-msvc"
$psi.WorkingDirectory = $PROJECT_ROOT
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$process = [System.Diagnostics.Process]::Start($psi)
$stderr = $process.StandardError.ReadToEnd()
$process.WaitForExit()

if ($process.ExitCode -ne 0) {
    Write-Host " [失败]" -ForegroundColor Red
    Write-Host "Clang 错误: $stderr" -ForegroundColor Red
    exit 1
}

Write-Host " [成功]" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  L2 编译器链接成功！" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "可执行文件: $xycExe" -ForegroundColor Cyan
Write-Host ""

# 测试运行
if (Test-Path $xycExe) {
    Write-Host "正在测试运行..." -ForegroundColor Yellow
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $xycExe
    $psi.Arguments = "--version"
    $psi.WorkingDirectory = $PROJECT_ROOT
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($psi)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -eq 0) {
        Write-Host "测试输出: $stdout" -ForegroundColor Green
    } else {
        Write-Host "测试运行返回: $LASTEXITCODE" -ForegroundColor Yellow
        if ($stdout) { Write-Host "输出: $stdout" -ForegroundColor Yellow }
        if ($stderr) { Write-Host "错误: $stderr" -ForegroundColor Red }
    }
}

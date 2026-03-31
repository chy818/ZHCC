# L2 编译器最终链接脚本
# 正确过滤 IR 内容，只保留纯 LLVM IR
$ErrorActionPreference = "Stop"

$PROJECT_ROOT = $PSScriptRoot
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "target\l2_compiler"

# 清理并创建输出目录
if (Test-Path $OUTPUT_DIR) {
    Remove-Item -Path $OUTPUT_DIR -Recurse -Force
}
New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  L2 Compiler Final Linking" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$XY_MODULES = @(
    "runtime.xy",
    "lexer.xy",
    "parser.xy",
    "sema.xy",
    "codegen.xy",
    "utils.xy",
    "main.xy"
)

# Step 1: Compile all modules to IR with proper filtering
Write-Host "[Step 1] Compiling modules to IR" -ForegroundColor Yellow
$irFiles = @()

foreach ($module in $XY_MODULES) {
    $sourcePath = Join-Path $SRC_DIR $module
    $irPath = Join-Path $OUTPUT_DIR "$module.ll"
    
    Write-Host "Compiling: $module"
    
    # 使用 ProcessStartInfo 来正确捕获输出
    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "cargo"
    $pinfo.Arguments = "run --release -- `"$sourcePath`" --ir-pure"
    $pinfo.WorkingDirectory = $PROJECT_ROOT
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($pinfo)
    $stdout = $process.StandardOutput.ReadToEnd()
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        Write-Host "ERROR: Failed to compile $module" -ForegroundColor Red
        Write-Host "stderr: $stderr"
        exit 1
    }
    
    # 过滤 IR 内容，只保留真正的 LLVM IR
    $lines = $stdout -split "`n"
    $irContent = @()
    $inIR = $false
    
    foreach ($line in $lines) {
        # 跳过 cargo 的警告和错误信息
        if ($line -match "^cargo|^warning|^error|^   -->|^\s*\||^Finished|^Compiling|^note:") {
            continue
        }
        # 检测 IR 开始
        if ($line -match "^declare\s+|^define\s+|^@|^!|^source_filename|^dso_local|^target\s+|^attributes|^%" -or $line.Trim() -eq "") {
            $inIR = $true
        }
        if ($inIR) {
            $irContent += $line
        }
    }
    
    # 清理开头和结尾的空行
    while ($irContent.Count -gt 0 -and $irContent[0].Trim() -eq "") {
        $irContent = $irContent[1..($irContent.Count-1)]
    }
    while ($irContent.Count -gt 0 -and $irContent[-1].Trim() -eq "") {
        $irContent = $irContent[0..($irContent.Count-2)]
    }
    
    ($irContent -join "`n") | Set-Content -Path $irPath -Encoding UTF8
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

# 使用 MSVC link.exe
$linkExe = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\link.exe"

Write-Host "Linking with MSVC link.exe..."

$objFilesStr = $objFiles -join " "
$linkArgs = "/SUBSYSTEM:CONSOLE /ENTRY:main /OUT:`"$xycExe`" `"$runtimePath`" $objFilesStr"

$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = $linkExe
$pinfo.Arguments = $linkArgs
$pinfo.WorkingDirectory = $PROJECT_ROOT
$pinfo.RedirectStandardOutput = $true
$pinfo.RedirectStandardError = $true
$pinfo.UseShellExecute = $false
$pinfo.CreateNoWindow = $true

$process = [System.Diagnostics.Process]::Start($pinfo)
$stdout = $process.StandardOutput.ReadToEnd()
$stderr = $process.StandardError.ReadToEnd()
$process.WaitForExit()

if ($process.ExitCode -ne 0) {
    Write-Host "ERROR: Linking failed" -ForegroundColor Red
    Write-Host "stdout: $stdout"
    Write-Host "stderr: $stderr"
    exit 1
}

Write-Host "  OK: $xycExe" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  L2 Compiler Linking Success!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Executable: $xycExe" -ForegroundColor Cyan
Write-Host ""

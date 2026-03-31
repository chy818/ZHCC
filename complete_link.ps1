# 完整版 L2 编译器链接脚本 - 解决编码问题
$ErrorActionPreference = "Stop"

$PROJECT_ROOT = $PSScriptRoot
$SRC_DIR = "$PROJECT_ROOT\src\compiler_v2"
$OUTPUT_DIR = "$PROJECT_ROOT\target\l2_compiler"

# 清理输出目录
if (Test-Path $OUTPUT_DIR) {
    Remove-Item -Path $OUTPUT_DIR -Recurse -Force
}
New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  L2 Compiler Complete Linking" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$modules = @("runtime.xy", "lexer.xy", "parser.xy", "sema.xy", "codegen.xy", "utils.xy", "main.xy")
$irFiles = @()
$objFiles = @()

# Step 1: 编译每个模块到 IR - 正确处理编码
Write-Host "[Step 1] Compiling modules to IR..." -ForegroundColor Yellow
foreach ($module in $modules) {
    $src = "$SRC_DIR\$module"
    $ir = "$OUTPUT_DIR\$module.ll"
    
    Write-Host "  Compiling $module..."
    
    # 使用临时文件捕获输出
    $tempFile = "$OUTPUT_DIR\temp_$module.txt"
    & cargo run --release -- $src --ir-pure > $tempFile 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ERROR: Failed to compile $module" -ForegroundColor Red
        Get-Content $tempFile
        exit 1
    }
    
    # 过滤 IR 内容
    $filtered = @()
    foreach ($line in Get-Content $tempFile) {
        if ($line -match "^(declare|define|@|!|source_filename|dso_local|target|attributes|%)" -or $line.Trim() -eq "") {
            $filtered += $line
        }
    }
    
    # 清理开头和结尾的空行
    $start = 0
    while ($start -lt $filtered.Count -and $filtered[$start].Trim() -eq "") {
        $start++
    }
    $end = $filtered.Count - 1
    while ($end -ge $start -and $filtered[$end].Trim() -eq "") {
        $end--
    }
    
    if ($start -le $end) {
        $result = $filtered[$start..$end]
        # 保存为 UTF-8 无 BOM
        $content = $result -join "`n"
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($ir, $content, $utf8NoBom)
    }
    
    $irFiles += $ir
    Write-Host "    OK: $ir" -ForegroundColor Green
    
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}

# Step 2: 编译 IR 到对象文件
Write-Host ""
Write-Host "[Step 2] Compiling IR to object files..." -ForegroundColor Yellow
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

# Step 3: 链接
Write-Host ""
Write-Host "[Step 3] Linking..." -ForegroundColor Yellow
$xyc = "$OUTPUT_DIR\xyc.exe"
$runtime = "$PROJECT_ROOT\runtime\runtime.c"
$linkExe = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\link.exe"
$clExe = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\cl.exe"

# 先编译 runtime.c 到对象文件
$runtimeObj = "$OUTPUT_DIR\runtime.c.obj"
Write-Host "  Compiling runtime.c..."
& $clExe /c /nologo /Fo"$runtimeObj" "$runtime"
if ($LASTEXITCODE -ne 0) {
    Write-Host "    ERROR: Failed to compile runtime.c" -ForegroundColor Red
    exit 1
}

# 链接所有对象文件
$allObjs = @($runtimeObj) + $objFiles
$args = "/SUBSYSTEM:CONSOLE /ENTRY:main /OUT:`"$xyc`" " + ($allObjs -join " ")

Write-Host "  Linking executable..."
& $linkExe $args.Split(" ")

if ($LASTEXITCODE -ne 0) {
    Write-Host "    ERROR: Linking failed" -ForegroundColor Red
    exit 1
}

Write-Host "    OK: $xyc" -ForegroundColor Green
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  L2 Compiler Linking Success!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Executable: $xyc" -ForegroundColor Cyan

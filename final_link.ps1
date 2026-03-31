# 最终版 L2 编译器链接脚本
$ErrorActionPreference = "Stop"

$PROJECT_ROOT = $PSScriptRoot
$SRC_DIR = "$PROJECT_ROOT\src\compiler_v2"
$OUTPUT_DIR = "$PROJECT_ROOT\target\l2_compiler"

# 清理输出目录
if (Test-Path $OUTPUT_DIR) {
    Remove-Item -Path $OUTPUT_DIR -Recurse -Force
}
New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null

Write-Host "Building L2 Compiler..." -ForegroundColor Cyan

$modules = @("runtime.xy", "lexer.xy", "parser.xy", "sema.xy", "codegen.xy", "utils.xy", "main.xy")
$irFiles = @()
$objFiles = @()

# Step 1: 编译每个模块到 IR
Write-Host "Step 1: Compiling modules to IR..." -ForegroundColor Yellow
foreach ($module in $modules) {
    $src = "$SRC_DIR\$module"
    $ir = "$OUTPUT_DIR\$module.ll"
    
    Write-Host "  Compiling $module..."
    
    # 使用临时文件捕获输出
    $tempFile = "$OUTPUT_DIR\temp.txt"
    & cargo run --release -- $src --ir-pure > $tempFile 2>&1
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ERROR: Failed to compile $module" -ForegroundColor Red
        Get-Content $tempFile
        exit 1
    }
    
    # 过滤 IR 内容，只保留以 declare、define、@、!、target、% 开头的行或空行
    $filtered = @()
    foreach ($line in Get-Content $tempFile) {
        if ($line -match "^(declare|define|@|!|source_filename|dso_local|target|attributes|%)" -or $line.Trim() -eq "") {
            $filtered += $line
        }
    }
    
    # 清理开头和结尾的空行
    $startIdx = 0
    while ($startIdx -lt $filtered.Count -and $filtered[$startIdx].Trim() -eq "") {
        $startIdx++
    }
    $endIdx = $filtered.Count - 1
    while ($endIdx -ge $startIdx -and $filtered[$endIdx].Trim() -eq "") {
        $endIdx--
    }
    if ($startIdx -le $endIdx) {
        $filtered = $filtered[$startIdx..$endIdx]
    } else {
        $filtered = @()
    }
    
    # 保存过滤后的 IR
    $filtered | Set-Content -Path $ir -Encoding UTF8
    $irFiles += $ir
    
    Write-Host "    OK: $ir" -ForegroundColor Green
    
    Remove-Item $tempFile -ErrorAction SilentlyContinue
}

# Step 2: 编译 IR 到对象文件
Write-Host "Step 2: Compiling IR to object files..." -ForegroundColor Yellow
foreach ($ir in $irFiles) {
    $obj = "$ir.o"
    Write-Host "  Compiling $(Split-Path $ir -Leaf)..."
    
    & llc $ir -filetype=obj -o $obj
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ERROR: LLC failed for $ir" -ForegroundColor Red
        Write-Host "    IR file content (first 20 lines):"
        Get-Content $ir | Select-Object -First 20
        exit 1
    }
    
    $objFiles += $obj
    Write-Host "    OK: $obj" -ForegroundColor Green
}

# Step 3: 链接
Write-Host "Step 3: Linking..." -ForegroundColor Yellow
$xyc = "$OUTPUT_DIR\xyc.exe"
$runtime = "$PROJECT_ROOT\runtime\runtime.c"
$linkExe = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\link.exe"

# 先编译 runtime.c 到对象文件
$runtimeObj = "$OUTPUT_DIR\runtime.c.obj"
Write-Host "  Compiling runtime.c..."
$clExe = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\cl.exe"
& $clExe /c /nologo /Fo"$runtimeObj" "$runtime"
if ($LASTEXITCODE -ne 0) {
    Write-Host "    ERROR: Failed to compile runtime.c" -ForegroundColor Red
    exit 1
}

# 链接所有对象文件
$allObjs = @($runtimeObj) + $objFiles
$args = "/SUBSYSTEM:CONSOLE /ENTRY:main /OUT:`"$xyc`" " + ($allObjs -join " ")

Write-Host "  Linking..."
& $linkExe $args.Split(" ")

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

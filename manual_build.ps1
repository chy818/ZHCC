# 手动构建脚本 - 分步执行
$ErrorActionPreference = "Continue"

$PROJECT_ROOT = $PSScriptRoot
$SRC_DIR = "$PROJECT_ROOT\src\compiler_v2"
$OUTPUT_DIR = "$PROJECT_ROOT\target\l2_compiler"

# 清理输出目录
if (Test-Path $OUTPUT_DIR) {
    Remove-Item -Path $OUTPUT_DIR -Recurse -Force
}
New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null

Write-Host "Building L2 Compiler - Manual Steps" -ForegroundColor Cyan

$modules = @("runtime.xy", "lexer.xy", "parser.xy", "sema.xy", "codegen.xy", "utils.xy", "main.xy")
$irFiles = @()
$objFiles = @()

Write-Host "`nStep 1: Compiling modules to IR" -ForegroundColor Yellow
foreach ($module in $modules) {
    $src = "$SRC_DIR\$module"
    $ir = "$OUTPUT_DIR\$module.ll"
    $temp = "$OUTPUT_DIR\temp_$module.txt"
    
    Write-Host "  Compiling $module..."
    
    # 运行 cargo，忽略警告
    $process = Start-Process -FilePath "cargo" -ArgumentList "run","--release","--","`"$src`"","--ir-pure" `
        -WorkingDirectory $PROJECT_ROOT `
        -RedirectStandardOutput $temp `
        -NoNewWindow -Wait -PassThru
    
    if ($process.ExitCode -ne 0) {
        Write-Host "    ERROR: Failed to compile $module" -ForegroundColor Red
        Get-Content $temp
        exit 1
    }
    
    # 过滤 IR
    $filtered = @()
    foreach ($line in Get-Content $temp) {
        if ($line -match "^(declare|define|@|!|source_filename|dso_local|target|attributes|%)" -or $line.Trim() -eq "") {
            $filtered += $line
        }
    }
    
    # 清理空行
    $start = 0
    while ($start -lt $filtered.Count -and $filtered[$start].Trim() -eq "") { $start++ }
    $end = $filtered.Count - 1
    while ($end -ge $start -and $filtered[$end].Trim() -eq "") { $end-- }
    
    if ($start -le $end) {
        $result = $filtered[$start..$end]
        $content = $result -join "`n"
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($ir, $content, $utf8NoBom)
    }
    
    $irFiles += $ir
    Write-Host "    OK: $ir" -ForegroundColor Green
    Remove-Item $temp -ErrorAction SilentlyContinue
}

Write-Host "`nStep 2: Compiling IR to object files" -ForegroundColor Yellow
foreach ($ir in $irFiles) {
    $obj = "$ir.o"
    Write-Host "  Compiling $(Split-Path $ir -Leaf)..."
    
    & llc $ir -filetype=obj -o $obj
    if ($LASTEXITCODE -ne 0) {
        Write-Host "    ERROR: LLC failed" -ForegroundColor Red
        exit 1
    }
    
    $objFiles += $obj
    Write-Host "    OK: $obj" -ForegroundColor Green
}

Write-Host "`nStep 3: Compiling runtime.c" -ForegroundColor Yellow
$runtimeObj = "$OUTPUT_DIR\runtime.c.obj"
$clExe = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\cl.exe"
& $clExe /c /nologo /Fo"$runtimeObj" "$PROJECT_ROOT\runtime\runtime.c"
if ($LASTEXITCODE -ne 0) {
    Write-Host "    ERROR: cl.exe failed" -ForegroundColor Red
    exit 1
}
Write-Host "    OK: $runtimeObj" -ForegroundColor Green

Write-Host "`nStep 4: Linking" -ForegroundColor Yellow
$xyc = "$OUTPUT_DIR\xyc.exe"
$linkExe = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\link.exe"
$allObjs = @($runtimeObj) + $objFiles
$args = "/SUBSYSTEM:CONSOLE /ENTRY:main /OUT:`"$xyc`" " + ($allObjs -join " ")

& $linkExe $args.Split(" ")
if ($LASTEXITCODE -ne 0) {
    Write-Host "    ERROR: Link failed" -ForegroundColor Red
    exit 1
}

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  L2 Compiler Build Success!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Executable: $xyc" -ForegroundColor Cyan

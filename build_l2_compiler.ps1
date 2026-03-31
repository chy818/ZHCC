# L2 编译器链接脚本
# 用于将编译好的 L2 模块链接成可执行文件

$ErrorActionPreference = "Stop"

$PROJECT_ROOT = $PSScriptRoot
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "target\l2_compiler"

# 创建输出目录
if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  L2 Compiler Linking Stage" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$XY_MODULES = @(
    "runtime.xy",
    "lexer.xy",
    "parser.xy",
    "sema.xy",
    "codegen.xy",
    "main.xy"
)

# Stage 1: Compile all modules to LLVM IR
Write-Host "[Stage 1] Compiling all modules to LLVM IR" -ForegroundColor Yellow
Write-Host "----------------------------------------"

$irFiles = @()

foreach ($module in $XY_MODULES) {
    $sourcePath = Join-Path $SRC_DIR $module
    $irPath = Join-Path $OUTPUT_DIR "$module.ll"

    Write-Host "Compiling: $module -> $module.ll"

    if (-not (Test-Path $sourcePath)) {
        Write-Host "  [SKIP] File not found: $sourcePath" -ForegroundColor Red
        continue
    }

    # Use --ir-pure mode to only output IR
    $output = & cargo run -- $sourcePath --ir-pure 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        # Filter out warnings, keep only IR lines
        $irLines = @()
        foreach ($line in $output) {
            if ($line -match "^@" -or $line -match "^define" -or $line -match "^declare" -or $line -match "^;" -or $line -match "^%" -or $line -match "^\s+$") {
                $irLines += $line
            }
        }
        $irLines | Out-File -FilePath $irPath -Encoding utf8
        Write-Host "  [OK] IR saved: $irPath" -ForegroundColor Green
        $irFiles += $irPath
    } else {
        Write-Host "  [FAIL] Compilation failed (exit code: $exitCode)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "[Stage 1 Complete] Generated $($irFiles.Count) IR files" -ForegroundColor Green
Write-Host ""

# Stage 2: Compile IR to object files
Write-Host "[Stage 2] Compiling LLVM IR to object files" -ForegroundColor Yellow
Write-Host "----------------------------------------"

$objFiles = @()

foreach ($irFile in $irFiles) {
    $moduleName = [System.IO.Path]::GetFileName($irFile)
    $objFile = Join-Path $OUTPUT_DIR "$moduleName.o"

    Write-Host "Compiling object: $moduleName"

    $llcOutput = & llc $irFile -filetype=obj -o $objFile 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "  [OK] Object file: $moduleName.o" -ForegroundColor Green
        $objFiles += $objFile
    } else {
        Write-Host "  [FAIL] LLC compilation failed" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "[Stage 2 Complete] Generated $($objFiles.Count) object files" -ForegroundColor Green
Write-Host ""

# Stage 3: Link to create executable
Write-Host "[Stage 3] Linking to create xyc.exe" -ForegroundColor Yellow
Write-Host "----------------------------------------"

$xycExe = Join-Path $OUTPUT_DIR "xyc.exe"
$runtimePath = Join-Path $PROJECT_ROOT "runtime\runtime.c"

if (-not (Test-Path $runtimePath)) {
    Write-Host "[ERROR] Cannot find runtime.c: $runtimePath" -ForegroundColor Red
    exit 1
}

if ($objFiles.Count -gt 0) {
    Write-Host "Linking files:"
    foreach ($obj in $objFiles) {
        Write-Host "  - $obj"
    }
    Write-Host ""

    $linkOutput = & clang $runtimePath $objFiles -o $xycExe 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "[OK] L2 Compiler generated: $xycExe" -ForegroundColor Green
    } else {
        Write-Host "[FAIL] Linking failed" -ForegroundColor Red
        Write-Host $linkOutput
        exit 1
    }
} else {
    Write-Host "[ERROR] No object files to link" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  L2 Compiler Linking Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "L2 Compiler location: $xycExe"
Write-Host ""
Write-Host "Done!" -ForegroundColor Cyan
# L2 Compiler Linking Script
$ErrorActionPreference = "Stop"

$PROJECT_ROOT = $PSScriptRoot
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "target\l2_compiler"

if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null
}

Write-Host "L2 Compiler Linking Script" -ForegroundColor Cyan

# L2 module list
$XY_MODULES = @(
    "runtime.xy",
    "lexer.xy",
    "parser.xy",
    "sema.xy",
    "codegen.xy",
    "utils.xy",
    "main.xy"
)

# Step 1: Compile all modules to IR
Write-Host "[1] Compiling modules to IR..." -ForegroundColor Yellow

foreach ($module in $XY_MODULES) {
    $sourcePath = Join-Path $SRC_DIR $module
    $irPath = Join-Path $OUTPUT_DIR "$module.ll"

    Write-Host "  Compiling $module..." -NoNewline

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
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "stderr: $stderr"
        exit 1
    }

    # Filter and save IR
    $lines = $stdout -split "`n" | Where-Object {
        $_ -match "^\s*$" -or
        $_ -match "^declare\s+" -or
        $_ -match "^\s*@\w+" -or
        $_ -match "^\s*define\s+" -or
        $_ -match "^\s*!`"" -or
        $_ -match "^\s*source_filename" -or
        $_ -match "^\s*dso_local" -or
        $_ -match "^\s*target\s+" -or
        $_ -match "^\s*attributes"
    }

    $irContent = ($lines | Where-Object { $_ -notmatch "^\s*$" }) -join "`n"
    $irContent | Set-Content -Path $irPath -Encoding UTF8

    Write-Host " [OK]" -ForegroundColor Green
}

# Step 2: Use LLC to compile to object files
Write-Host "[2] Using LLC to compile to object files..." -ForegroundColor Yellow
$allObjFiles = @()

foreach ($module in $XY_MODULES) {
    $irPath = Join-Path $OUTPUT_DIR "$module.ll"
    $oPath = "$irPath.o"

    Write-Host "  Compiling $module.ll..." -NoNewline

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "llc"
    $pinfo.Arguments = "`"$irPath`" -filetype=obj -o `"$oPath`""
    $pinfo.WorkingDirectory = $PROJECT_ROOT
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true

    $process = [System.Diagnostics.Process]::Start($pinfo)
    $stderr = $process.StandardError.ReadToEnd()
    $process.WaitForExit()

    if ($process.ExitCode -ne 0) {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "stderr: $stderr"
        exit 1
    }

    $allObjFiles += $oPath
    Write-Host " [OK]" -ForegroundColor Green
}

# Step 3: Link
Write-Host "[3] Linking to executable..." -ForegroundColor Yellow
$xycExe = Join-Path $OUTPUT_DIR "xyc.exe"
$runtimePath = Join-Path $PROJECT_ROOT "runtime\runtime.c"

Write-Host "  Generating $xycExe..." -NoNewline

# Use lld-link directly
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = "lld-link"
$pinfo.Arguments = "`"$runtimePath`" $allObjFiles -o `"$xycExe`" -entry:main -subsystem:console"
$pinfo.WorkingDirectory = $PROJECT_ROOT
$pinfo.RedirectStandardOutput = $true
$pinfo.RedirectStandardError = $true
$pinfo.UseShellExecute = $false
$pinfo.CreateNoWindow = $true

$process = [System.Diagnostics.Process]::Start($pinfo)
$stderr = $process.StandardError.ReadToEnd()
$process.WaitForExit()

if ($process.ExitCode -ne 0) {
    Write-Host " [FAILED]" -ForegroundColor Red
    Write-Host "stderr: $stderr"
    exit 1
}

Write-Host " [OK]" -ForegroundColor Green

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  L2 Compiler Linking Success!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Executable: $xycExe" -ForegroundColor Cyan

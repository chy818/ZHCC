# Simple L2 Compiler Linking Script
$ErrorActionPreference = "Stop"

$PROJECT_ROOT = $PSScriptRoot
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "target\l2_compiler"

# Module list
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
Write-Host "=== Step 1: Compiling modules to IR ===" -ForegroundColor Cyan
$irFiles = @()

foreach ($module in $XY_MODULES) {
    $sourcePath = Join-Path $SRC_DIR $module
    $irPath = Join-Path $OUTPUT_DIR "$module.ll"
    
    Write-Host "Compiling $module..." -NoNewline

    # Use ProcessStartInfo to capture output
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

    # Filter IR content - skip cargo warnings
    $lines = $stdout -split "`n"
    $irContent = @()
    $inIR = $false

    foreach ($line in $lines) {
        if ($line -match "^Finished|^Compiling|^warning:|^error:|^   -->|^\s*\|") {
            continue
        }
        if ($line -match "^declare\s+|^define\s+|^@|^!|^source_filename|^dso_local|^target\s+|^attributes") {
            $inIR = $true
        }
        if ($inIR -and $line.Trim() -ne "") {
            $irContent += $line
        }
    }

    ($irContent -join "`n") | Set-Content -Path $irPath -Encoding UTF8
    $irFiles += $irPath
    Write-Host " [OK]" -ForegroundColor Green
}

# Step 2: Compile to object files with LLC
Write-Host "`n=== Step 2: Compiling IR to object files ===" -ForegroundColor Cyan
$objFiles = @()

foreach ($irFile in $irFiles) {
    $oPath = "$irFile.o"
    Write-Host "Compiling $(Split-Path $irFile -Leaf)..." -NoNewline

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = "llc"
    $pinfo.Arguments = "`"$irFile`" -filetype=obj -o `"$oPath`""
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

    $objFiles += $oPath
    Write-Host " [OK]" -ForegroundColor Green
}

# Step 3: Link with MSVC link.exe
Write-Host "`n=== Step 3: Linking ===" -ForegroundColor Cyan
$xycExe = Join-Path $OUTPUT_DIR "xyc.exe"
$runtimePath = Join-Path $PROJECT_ROOT "runtime\runtime.c"
$linkExe = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\link.exe"

Write-Host "Generating $xycExe..." -NoNewline

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
    Write-Host " [FAILED]" -ForegroundColor Red
    Write-Host "stdout: $stdout"
    Write-Host "stderr: $stderr"
    exit 1
}

Write-Host " [OK]" -ForegroundColor Green

Write-Host "`n========================================" -ForegroundColor Green
Write-Host "  L2 Compiler Linking Success!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Executable: $xycExe" -ForegroundColor Cyan

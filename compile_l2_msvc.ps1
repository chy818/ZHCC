# L2 Compiler Linking Script using MSVC - Fixed Encoding
$ErrorActionPreference = "Stop"

$PROJECT_ROOT = $PSScriptRoot
$SRC_DIR = Join-Path $PROJECT_ROOT "src\compiler_v2"
$OUTPUT_DIR = Join-Path $PROJECT_ROOT "target\l2_compiler"

# Find MSVC link.exe
$MSVC_PATH = "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64"
$LINK_EXE = Join-Path $MSVC_PATH "link.exe"

if (-not (Test-Path $LINK_EXE)) {
    Write-Host "ERROR: link.exe not found at $LINK_EXE" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $OUTPUT_DIR)) {
    New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null
}

Write-Host "L2 Compiler Linking Script (using MSVC)" -ForegroundColor Cyan
Write-Host "Using link.exe: $LINK_EXE" -ForegroundColor Gray
Write-Host ""

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

# Helper function to run cargo and capture output
function Run-Cargo {
    param($sourcePath)

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
        throw "Cargo failed: $stderr"
    }

    return $stdout
}

# Helper function to filter IR from cargo output
function Filter-IR {
    param($content)

    # Split into lines
    $lines = $content -split "`n"

    # Filter to keep only IR lines
    $irLines = @()
    $inIR = $false

    foreach ($line in $lines) {
        # Skip cargo warnings and errors
        if ($line -match "^warning:|^error:|^   -->") {
            continue
        }
        if ($line -match "^\s*$") {
            continue
        }
        if ($line -match "^\|") {
            continue
        }
        if ($line -match "^=+$") {
            continue
        }

        # Keep IR content
        $irLines += $line
    }

    return ($irLines -join "`n").Trim()
}

# Step 1: Compile all modules to IR
Write-Host "[1] Compiling modules to IR..." -ForegroundColor Yellow

foreach ($module in $XY_MODULES) {
    $sourcePath = Join-Path $SRC_DIR $module
    $irPath = Join-Path $OUTPUT_DIR "$module.ll"

    Write-Host "  Compiling $module..." -NoNewline

    try {
        $stdout = Run-Cargo -sourcePath $sourcePath
        $irContent = Filter-IR -content $stdout
        $irContent | Set-Content -Path $irPath -Encoding UTF8
        Write-Host " [OK]" -ForegroundColor Green
    } catch {
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host $_.Exception.Message
        exit 1
    }
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

# Step 3: Link using MSVC link.exe
Write-Host "[3] Linking using MSVC link.exe..." -ForegroundColor Yellow
$xycExe = Join-Path $OUTPUT_DIR "xyc.exe"
$runtimePath = Join-Path $PROJECT_ROOT "runtime\runtime.c"

Write-Host "  Generating $xycExe..." -NoNewline

# Build the object files list
$objFilesStr = $allObjFiles -join " "

# MSVC link.exe syntax: link [options] [files]
# /SUBSYSTEM:CONSOLE - console application
# /ENTRY:main - entry point function
# /OUT:filename - output file
$linkArgs = "/SUBSYSTEM:CONSOLE /ENTRY:main /OUT:`"$xycExe`" `"$runtimePath`" $objFilesStr"

$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = $LINK_EXE
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

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  L2 Compiler Linking Success!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Executable: $xycExe" -ForegroundColor Cyan

@echo off
chcp 65001 > nul
echo Building L2 Compiler...

set PROJECT_ROOT=%~dp0
set SRC_DIR=%PROJECT_ROOT%src\compiler_v2
set OUTPUT_DIR=%PROJECT_ROOT%target\l2_compiler

if exist "%OUTPUT_DIR%" rmdir /s /q "%OUTPUT_DIR%"
mkdir "%OUTPUT_DIR%"

set IR_FILES=
set OBJ_FILES=

echo Step 1: Compiling modules to IR...

for %%m in (runtime.xy lexer.xy parser.xy sema.xy codegen.xy utils.xy main.xy) do (
    echo   Compiling %%m...
    cargo run --release -- "%SRC_DIR%\%%m" --ir-pure > "%OUTPUT_DIR%\%%m.ll" 2>&1
    set IR_FILES=%IR_FILES% "%OUTPUT_DIR%\%%m.ll"
    echo     OK: %%m.ll
)

echo Step 2: Compiling IR to object files...

for %%f in (%IR_FILES%) do (
    echo   Compiling %%~nxf...
    llc %%f -filetype=obj -o %%f.o
    set OBJ_FILES=%OBJ_FILES% %%f.o
    echo     OK: %%~nxf.o
)

echo Step 3: Compiling runtime.c...
set CL_EXE=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\cl.exe
"%CL_EXE%" /c /nologo /Fo"%OUTPUT_DIR%\runtime.c.obj" "%PROJECT_ROOT%runtime\runtime.c"
set RUNTIME_OBJ=%OUTPUT_DIR%\runtime.c.obj

echo Step 4: Linking...
set LINK_EXE=C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.44.35207\bin\Hostx64\x64\link.exe
"%LINK_EXE%" /SUBSYSTEM:CONSOLE /ENTRY:main /OUT:"%OUTPUT_DIR%\xyc.exe" "%RUNTIME_OBJ%" %OBJ_FILES%

echo.
echo ========================================
echo   L2 Compiler Build Success!
echo ========================================
echo Executable: %OUTPUT_DIR%\xyc.exe
echo.

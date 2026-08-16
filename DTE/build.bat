@echo off
setlocal
cd /d "%~dp0"

rem Build DTE 3.0 with 32-bit MASM and Crinkler.
rem Run this from an x86 Native Tools Command Prompt.

set "NAME=dte"
set "ASM=%NAME%.asm"
set "OBJ=%NAME%.obj"
set "EXE=%NAME%.exe"

if not exist "%ASM%" (
    echo ERROR: %ASM% was not found beside this batch file.
    exit /b 1
)

where ml.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: ml.exe was not found.
    echo Run this from an x86 Native Tools Command Prompt.
    exit /b 1
)

if exist "%~dp0Crinkler.exe" (
    set "CRINKLER=%~dp0Crinkler.exe"
) else (
    where Crinkler.exe >nul 2>&1
    if errorlevel 1 (
        echo ERROR: Crinkler.exe was not found.
        echo Put Crinkler.exe beside this batch file or add it to PATH.
        exit /b 1
    )
    set "CRINKLER=Crinkler.exe"
)

echo Assembling %ASM%...
ml.exe /nologo /c /coff /Fo"%OBJ%" "%ASM%"
if errorlevel 1 (
    echo ERROR: MASM assembly failed.
    exit /b 1
)

echo Linking and compressing %EXE%...
"%CRINKLER%" ^
    /OUT:"%EXE%" ^
    /ENTRY:WinX86Entry ^
    /SUBSYSTEM:WINDOWS ^
    /NODEFAULTLIB ^
    /TINYIMPORT ^
    /UNALIGNCODE ^
    /NOINITIALIZERS ^
    /ORDERTRIES:2000 ^
    "%OBJ%" kernel32.lib user32.lib gdi32.lib

if errorlevel 1 (
    echo ERROR: Crinkler build failed.
    exit /b 1
)

for %%F in ("%EXE%") do echo Built %%~nxF - %%~zF bytes
del *.obj
exit /b 0

cls
@echo off

ml /nologo /c /coff /Cp dte30.asm
if errorlevel 1 exit /b 1

crinkler dte30.obj kernel32.lib user32.lib gdi32.lib ^
 /OUT:dte30.exe ^
 /ENTRY:WinX86Entry ^
 /SUBSYSTEM:WINDOWS ^
 /NODEFAULTLIB ^
 /NOINITIALIZERS ^
 /TINYIMPORT ^
 /HASHSIZE:9
if errorlevel 1 exit /b 1

del dte30.obj 2>nul

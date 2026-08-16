cls
@echo off

ml /nologo /c /coff /Cp winx86.asm
if errorlevel 1 exit /b 1

crinkler winx86.obj kernel32.lib user32.lib ^
 /OUT:winx86.exe ^
 /ENTRY:WinX86Entry ^
 /SUBSYSTEM:WINDOWS ^
 /NODEFAULTLIB ^
 /NOINITIALIZERS ^
 /TINYIMPORT ^
 /HASHSIZE:2
 if errorlevel 1 exit /b 1

del winx86.obj 2>nul

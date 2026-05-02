# Daves-Tiny-Editor (DTE)
A Windows text editor in 890 bytes.

Compiles with: MASM and Crinkler

This is an extension of tiny.asm Hello Windows by Dave Plummer https://github.com/davepl. The idea is to make a working windowed text editor in the sub 1kb category. It uses Crinkler https://github.com/runestubbe/Crinkler compression at build time.

DTE is basically a wrapper around the EDIT control from the WinAPI. It does not set a custom font. It uses the native default font supplied by the Windows EDIT control - probably MS Sans Serif on most systems. It's a proportional font, so good for writing letters, not so much for coding.

Important: Programs using Crinkler can be flagged as a false-positive by antivirus, including Windows Defender. You need to make an antivirus exception folder to build this, or Windows will likely delete your exe as soon as the build completes. Therefore, try this out AT YOUR OWN RISK - NO WARRANTIES / NO GUARANTEES. You can do this with Powershell, but I am not going to tell you how. Sorry. You're on your own when messing with antivirus.

You need to have Crinkler installed in a directory that has been added to PATH. Example: C:\utils\Crinkler.exe
Build the exe in a folder that has been excluded from antivirus check. Example: C:\assem_test\
MASM version used: Microsoft (R) Macro Assembler Version 14.44.35224.0


# Dave's Tiny Editor (DTE) v1.17
A Windows text editor in 890 bytes.

Compiles with: MASM and Crinkler.

DTE is an extension of `tiny.asm` Hello Windows by Dave Plummer https://github.com/davepl. The idea is to make a working windowed text editor in the sub-1KB category. It uses Crinkler https://github.com/runestubbe/Crinkler compression at build time.

DTE is basically a wrapper around the EDIT control from the WinAPI. It does not set a custom font. It uses the native default font supplied by the EDIT control - probably MS Sans Serif on most systems. It's a proportional font, so good for writing letters, but not so much for coding.

**Important:** Programs using Crinkler can be flagged as a false positive by antivirus, including Windows Defender. You need to make an antivirus exception folder to build this, or Windows may delete the EXE as soon as the build completes. Therefore, try this out AT YOUR OWN RISK - NO WARRANTIES / NO GUARANTEES. You can do this with Powershell, but I am not going to tell you how. Sorry. You're on your own when messing with antivirus.

- MASM version used: Microsoft (R) Macro Assembler Version 14.44.35224.0 <br>
- You need to have Crinkler installed in a directory that has been added to PATH.<br>
Example: C:\utils\Crinkler.exe<br>
- Build the EXE in a folder that has been excluded from antivirus check.<br>
Example: C:\assem_test\

Contents: <br>
| Folder | Description |
|--------|-------------|
| `ALT BUILD` | Builds without Crinkler for everyday use. |
| `BACKUPS` | The history of building up DTE from Hello Windows. |
| `ORIGINAL` | The original from davepl's GitHub. |

| File | Description |
|------|-------------|
| `build.bat` | Builds DTE from command line. |
| `DRAG ME ONTO DTE.txt` | How to use DTE. |
| `DTE ABOUT.txt` | Explains some design decisions. |
| `dte.asm` | The program. |
| `LICENSE` | Usage permissions. |





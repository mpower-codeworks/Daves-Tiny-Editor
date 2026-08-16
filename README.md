# Dave's Tiny Editor (DTE) v3.3.1
### A Windows Text Editor in 990 Bytes. File Search, Print, Create New, More...<br>
<table border="0">
  <tr>
    <td>
      <img src="images/dte-size-properties.jpg"
           alt="DTE executable properties showing 794 bytes"
           width="300">
    </td>
    <td rowspan="2">
      <img src="images/DT.jpg"
           alt="D.T. Mascot"
           width="300">
    </td>
  </tr>
  <tr>
    <td>
      <img src="images/dte-virus-scan.jpg"
           alt="DTE executable virus scan clean"
           width="300">
    </td>
  </tr>
</table>

## We're Not in Kansas Any More

DTE has officially entered new territory. Still sitting in the sub-1kb<br>
category (990 bytes), it now has the following capabilities added:

- new file creation from the GUI (default file named "f")
- highlight any text and search with F2 and F3
- search wraps after beginning/end of file
- quick-save with F9
- GUI "X" icon disabled on unsaved file
- X! added to system menu "throw out changes"
- F12 send file to the active printer

## How DTE Works:

### Opening an existing file:

Drag and drop it onto DTE.

### Creating a new file:

Double-click DTE to run it. A new file "f" will be automatically<br>
created. If f already exists, then DTE simply opens that. Edit the<br>
new file and Save. Quit DTE and rename f to whatever you want.

### Saving a file:

Press F9 or click system menu->Save.<br>
There is no "save-as".

### Closing DTE

DTE now has unsaved-file protection. If the file is unsaved<br>
(* appended to the name in the title bar), The GUI "X" and<br>
the system menu "Close" or Alt-F4 do nothing. They are only<br>
enabled if a file is unchanged since last save.

X! (X bang) in the system menu overrides the unsaved<br>
protection and allows the user to "throw away changes".

### Searching the file

Highlight any text in the file and press F3 to search forwards
or F2 to search backwards. DTE will highlight each next found
instance for every F2 or F3 keypress. End of file and beginning
of file both silently wrap to the other end.

### Printing a file

F12 immediately prints to the active (default) printer. If the
active printer is PDF, a dialog will open to choose a file name
to save as. This is a trick. DTE is actually calling Notepad
with the /P flag. Windows does all the work, and the user never
actually sees Notepad.

## General Information

DTE 3.0 is a complete rewrite from a blank file up through to the
full-featured editor presented here with version 3.4.1. It's
features include all of the above-listed plus: 

Fewer imports, persistent file handle, static class window, no
includes, file I/O via RICHEDIT20W, and by special appearance:

### A fake file dirty marker!

There is no flag to set, a * is simply appended to the title on file
change and removed on save.

Version 3.0 is the main distribution. 2.0 is a more standard,
optimized tiny exe. 1.0 is limited by EDIT, and more experimental.

(Old) New! June 2026: DTE (2.0) has in collaboration with Dave Plummer been
expanded into TinyRetroPad, a full-featured Notepad work-alike editor
in 2.62 kb! You can find TRPad [here](https://github.com/PlummersSoftwareLLC/TinyRetroPad)
and a video about it [here](https://www.youtube.com/watch?v=OG91c7xsNMc).

<img src="images/sve_exmpl.jpg" align="left" alt="System Menu"> You can find the
Save button in the window's system menu.

Compiles with: MASM and Crinkler.

DTE 1.0 and 2.0 are extensions of `tiny.asm` HelloAssembly by [Dave Plummer](https://github.com/davepl).
DTE 3.0 is a complete rewrite. All versions use [Crinkler](https://github.com/runestubbe/Crinkler) compression
at build time.

DTE is basically a wrapper around the RICHEDIT20W control from the WinAPI.

Versions in 1.0 use the EDIT control with Crinkler cranked and were built-up
from tiny.asm then worked down to 890 bytes with Win Defender quite unhappy. NOTE:
This has been stabilized at 926 bytes with no A/V issues.

Versions in 2.0 have Crinkler backed-off a bit and use RICHEDIT to gain cheaper
access to Courier font and much larger files. 2.0 was then worked down from
995 to 967 bytes.

Versions in 3.0 are a complete rewrite, yielding a functional editor in 908
bytes (already beating 2.0) and then worked down to 794 bytes.

### A Very Special Note About File I/O

Version 3.0 intentionally lets a user open DTE without a file. There is currently
no way to save that file, but I have some ideas for future revisions. If no file name:

1. Save as the first few chars of the file as a name
2. Save as a fixed file name such as "d" or "sav"
3. Or just block opening if no file like 1.0 and 2.0

I will have to spend some time to figure out how to handle it. I'd really like
to keep 3.0 under 800 bytes. There's just something about "being in the sevens."

## Contents: <br>
| Folder | Description |
|--------|-------------|
| `1_0` | Version 1.0 non-mono font 926 bytes build with full history|
| `2_0_BACKUPS` | Version 2.0 more features, 967 bytes build from RICHEDIT to release|
| `3_0` | Version 3.0 complete rewrite, 794 bytes build from blank to release|

| File | Description |
|------|-------------|
| `build.bat` | Builds DTE from command line |
| `DRAG ME ONTO DTE.txt` | How to use DTE |
| `DTE ABOUT.txt` | Explains some design decisions |
| `dte.asm` | The program. Version 3.3.1 |
| `LICENSE` | Usage permissions |

## DTE in use: <br>
<img src="images/dte-in-action.jpg" alt="DTE in action" width="500">

### Compiling, and if You're New to Crinkler

**Important:** Programs using Crinkler can be flagged as a false positive by antivirus, including Windows Defender. You may need to make an antivirus exception folder to build this (especially for 1.0), or Windows may delete the EXE as soon as the build completes. Therefore, try this out AT YOUR OWN RISK - NO WARRANTIES / NO GUARANTEES. You can accomplish this with PowerShell, but I am not going to tell you how. Sorry. You're on your own when messing with antivirus.

- MASM version used: Microsoft (R) Macro Assembler Version 14.44.35224.0 <br>

- MASM can vary depending on version. If you experience:
```
C:\masm32\include\winextra.inc(11052) : error A2026:constant expected
C:\masm32\include\winextra.inc(11053) : error A2026:constant expected
```
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;In masm32\include\winextra.inc change:<br>
```
    STD_ALERT struct<br>
        alrt_timestamp dd ?<br>
        alrt_eventname WCHAR  [EVLEN + 1] dup(?)
        alrt_servicename WCHAR [SNLEN + 1] dup(?)
    STD_ALERT ends
```
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;to:<br>
```
    STD_ALERT struct<br>
        alrt_timestamp dd ?<br>
        alrt_eventname WCHAR  (EVLEN + 1) dup(?)
        alrt_servicename WCHAR (SNLEN + 1) dup(?)
    STD_ALERT ends<br>
```
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;The brackets on lines 13,14 were changed to parens.<br>
- Build.bat contains: /LIBPATH:"C:\Program Files (x86)\\Windows Kits\\10\\Lib\\10.0.20348.0\\um\\x86"<br>
You may need to change to fit your system: /LIBPATH:"....\\Windows Kits\\10\\Lib\\(your version)\\um\\x86"
- You need to have Crinkler installed in a directory that has been added to PATH.<br>
Example: C:\utils\Crinkler.exe<br>




;     / / / / / / / /
;   / / DTE 2.0 / /
; / / / / / / / /

;----------------------------------;
; Dave's Tiny Editor 2.0           ;
; Based on Dave Plummer's tiny app ;
;----------------------------------;

; Compiler directives and includes:
 
.386                       ; Full 80386 instruction set and mode
.model flat, stdcall       ; All 32-bit and later apps are flat. Used to include "tiny, etc"
option casemap:none        ; Preserve the case of system identifiers but not our own, more or less

; Include files - headers and libs that we need for
; calling the system dlls like user32, kernel32, etc
include windows.inc        ; Main windows header file (akin to Windows.h in C)
include user32.inc         ; Windows, controls, etc
include kernel32.inc       ; Handles, modules, paths, etc
;include gdi32.inc         ; Removed because no GDI used for editor
                           ; Rich Edit font is set without GDI
                           ; using EM_SETCHARFORMAT

WindowWidth      equ 800        ; window startup size
WindowHeight     equ 640
IDC_EDIT         equ 1001       ; good ole EDIT control from WinAPI
EM_EXLIMITTEXT  equ WM_USER+53  ; Rich Edit: raise user editing text limit
EM_SETCHARFORMAT equ WM_USER+68 ; Rich Edit: set text format
EM_SETEVENTMASK  equ WM_USER+69 ; Rich Edit: choose which notifications parent gets
SCF_ALL          equ 00000004h  ; Rich Edit: apply format to all text
ENM_CHANGE       equ 00000001h  ; Rich Edit: send EN_CHANGE notifications
CFM_FACE         equ 20000000h  ; Rich Edit: use font face name
MAX_CMD_PATH     equ 128        ; holds startup file path from dropped file
MAX_TITLE        equ 128        ; holds window title text (file name and if dirty * )
IDM_SAVE         equ 0E100h     ; Save menu ID (WM_SYSCOMMAND)

.DATA

EXTERN _imp__CreateWindowExA@48    :PTR ; create main window / EDIT control
EXTERN _imp__GetModuleHandleA@4    :PTR ; get HINSTANCE
EXTERN _imp__LoadLibraryA@4        :PTR ; load modern Rich Edit DLL
EXTERN _imp__RegisterClassA@4      :PTR ; rgstr wndw class (was RegisterClassExA@4)
EXTERN _imp__GetMessageA@16        :PTR ; message loop get
EXTERN _imp__TranslateMessage@4    :PTR ; translate keys
EXTERN _imp__DispatchMessageA@4    :PTR ; dispatch to WndProc
EXTERN _imp__PostQuitMessage@4     :PTR ; exit message loop
EXTERN _imp__DefWindowProcA@16     :PTR ; default window handling
EXTERN _imp__SetWindowPos@28       :PTR ; resize EDIT control
EXTERN _imp__GetCommandLineA@0     :PTR ; get startup file path
EXTERN _imp__CreateFileA@28        :PTR ; open file (read/write)
EXTERN _imp__GetFileSize@8         :PTR ; get file size
EXTERN _imp__GlobalAlloc@8         :PTR ; allocate buffer
EXTERN _imp__GlobalFree@4          :PTR ; free buffer
EXTERN _imp__ReadFile@20           :PTR ; read file into EDIT
EXTERN _imp__WriteFile@20          :PTR ; save EDIT to file
EXTERN _imp__CloseHandle@4         :PTR ; close file handle
EXTERN _imp__SetWindowTextA@8      :PTR ; set title / EDIT text
EXTERN _imp__GetSystemMenu@8       :PTR ; get system menu
EXTERN _imp__AppendMenuA@16        :PTR ; add Save menu item
EXTERN _imp__SendMessageA@16       :PTR ; talk to EDIT control
EXTERN _imp__ExitProcess@4         :PTR ; terminate process cleanly

ClassName   db ".",0                ; save bytes here (seems to work)
RichDll     db "Msftedit",0         ; Rich Edit DLL (no ext saves those bytes)
EditClass   db "RICHEDIT50W",0      ; modern Rich Edit control from WinAPI
SaveText    db "Save",0             ; button added to system menu

hMain       dd 0                    ; main window handle
hEdit       dd 0                    ; EDIT control handle
CmdFile     db MAX_CMD_PATH dup (0) ; startup file path buffer
TitleBuf    db MAX_TITLE dup    (0) ; window title buffer
BytesRead   dd 0                    ; bytes read from file
fDirty      dd 0                    ; EDIT modified flag

; Rich Edit default font face: Courier only
RichFont    dd 92                   ; CHARFORMATW size
            dd CFM_FACE             ; only set face name
            dd 0                    ; no effects
            dd 0                    ; no font size change
            dd 0                    ; no offset change
            dd 0                    ; no color change
            db 0                    ; default charset
            db 0                    ; default pitch/family
            dw 'C','o','u','r','i','e','r',0
            dw 24 dup (0)
            dw 0                    ; CHARFORMATW padding


;----------------------------------------------;
.CODE ; Here is where the program itself lives ;
;----------------------------------------------;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; title bar caption from startup file name ;
; add "*" if the buffer has been modified  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
BuildTitle proc NEAR    
    lea     edi, TitleBuf
    mov     esi, OFFSET CmdFile
    mov     ebx, esi

    ; strip the full path down to just the filename
    FindTail:
        mov     al, [esi]
        test    al, al
        je      GotTail
	
        cmp     al, '\'
        je      MarkTail
	
	;; surprised me disabling this works
        ;cmp     al, '/'
        ;je      MarkTail
        ;cmp     al, ':'
        ;je      MarkTail
	
        inc     esi
        jmp     FindTail

    ; record start of next path segment (looking for file name)
    MarkTail:
        mov     ebx, esi
        inc     ebx
        inc     esi
        jmp     FindTail


    ; point to filename (tail of path)
    GotTail:
        mov     esi, ebx

    ; copy the filename into the title buffer
    CopyBase:
    CopyLoop:
        mov     al, [esi]
        test    al, al
        je      CopyEnd
        mov     [edi], al
        inc     edi
        inc     esi
        jmp     CopyLoop

    ; if dirty, append *
    CopyEnd:
        cmp     fDirty, 0
        je      TitleDone
        mov     byte ptr [edi], '*'
        inc     edi

    ; null-terminate title and return
    TitleDone:
        mov     byte ptr [edi], 0
        ret
BuildTitle endp ; end BuildTitle proc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; build title and set title bar caption ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ApplyTitle proc NEAR
    call    BuildTitle
    push    OFFSET TitleBuf
    mov     eax, hMain
    push    eax
    call    [_imp__SetWindowTextA@8]
    ret
ApplyTitle endp ;end ApplyTitle proc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; parse command line for the startup file or  ;
; if user drops a file on the app to launch   ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ParseStartupFile proc NEAR
    call    [_imp__GetCommandLineA@0]
    mov     esi, eax
    test    esi, esi
    je      NoArg
    cmp     byte ptr [esi], '"'
    jne     SkipExeBare
    inc     esi
 
    ; skip quoted exe path so esi points to first argument
    SkipExeQuoted:
        mov     al, [esi]
        test    al, al
        je      NoArg
        inc     esi
        cmp     al, '"'
        jne     SkipExeQuoted
        jmp     SkipWs

    ; skip unquoted exe path to reach first argument
    SkipExeBare:
        mov     al, [esi]
        test    al, al
        je      NoArg
        cmp     al, ' '
        je      SkipWs
        cmp     al, 9
        je      SkipWs
        inc     esi
        jmp     SkipExeBare

    ; skip spaces/tabs before argument (white spaces)
    SkipWs:
        mov     al, [esi]
        cmp     al, ' '
        je      SkipWsStep
        cmp     al, 9
        je      SkipWsStep
        jmp     ArgStart

    ; advance past whitespace
    SkipWsStep:
        inc     esi
        jmp     SkipWs

    ; start copying first argument (file path), handle quoted
    ArgStart:
        cmp     byte ptr [esi], 0
        je      NoArg

        lea     edi, CmdFile
        mov     ecx, MAX_CMD_PATH-1

        cmp     byte ptr [esi], '"'
        jne     CopyBare
        inc     esi

    ; copy quoted file path into CmdFile (strip quotes)
    CopyQuoted:
        mov     al, [esi]
        test    al, al
        je      CopyDone
        cmp     al, '"'
        je      CopyDone
        mov     [edi], al
        inc     edi
        inc     esi
        dec     ecx
        jz      CopyDone
        jmp     CopyQuoted

    ; copy unquoted file path into CmdFile
    CopyBare:
        mov     al, [esi]
        test    al, al
        je      CopyDone
        cmp     al, ' '
        je      CopyDone
        cmp     al, 9
        je      CopyDone
        mov     [edi], al
        inc     edi
        inc     esi
        dec     ecx
        jz      CopyDone
        jmp     CopyBare

    ; null-terminate CmdFile and return
    CopyDone:
        mov     byte ptr [edi], 0
        ret

    ; no arg: clear CmdFile (no startup file)
    NoArg:
        mov     byte ptr [CmdFile], 0
        ret
ParseStartupFile endp ; end ParseStartupFile proc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; read startup file and populate EDIT control ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LoadStartupFile proc NEAR
    LOCAL hFile:     DWORD
    LOCAL hMem:      DWORD
    LOCAL dwSize:    DWORD

    ; open CmdFile for reading
    push    NULL
    push    FILE_ATTRIBUTE_NORMAL
    push    OPEN_EXISTING
    push    NULL
    push    FILE_SHARE_READ
    push    GENERIC_READ
    push    OFFSET CmdFile
    call    [_imp__CreateFileA@28]

    ; if opened ok save handle / else skip load
    cmp     eax, INVALID_HANDLE_VALUE
    je      LoadDone
    mov     hFile, eax

    ; get file size (bytes)
    push    NULL
    push    eax
    call    [_imp__GetFileSize@8]
    
    ; INVALID_HANDLE_VALUE file open failed
    cmp     eax, 0FFFFFFFFh 
    je      CloseOnly
    mov     dwSize, eax
    
    ; alloc buffer for file (+1 for null)
    inc     eax
    push    eax
    push    GMEM_FIXED
    call    [_imp__GlobalAlloc@8]
    
    ; if alloc ok, save ptr; else close file
    test    eax, eax
    je      CloseOnly
    mov     hMem, eax
    

    ; read file into buffer
    push    NULL
    lea     eax, BytesRead
    push    eax
    mov     eax, dwSize
    push    eax
    mov     eax, hMem
    push    eax
    mov     eax, hFile
    push    eax
    call    [_imp__ReadFile@20]

    ; if read failed, cleanup and abort
    test    eax, eax
    je      FreeLoadBuffer

    ; null-terminate loaded file data
    mov     eax, hMem
    mov     ecx, BytesRead
    mov     byte ptr [eax+ecx], 0

    ; set EDIT text from buffer
    push    eax
    mov     eax, hEdit
    push    eax
    call    [_imp__SetWindowTextA@8]

    ; set Rich Edit font on loaded text
    push    OFFSET RichFont
    push    SCF_ALL
    push    EM_SETCHARFORMAT
    mov     eax, hEdit
    push    eax
    call    [_imp__SendMessageA@16]

    ; free loaded file buffer
    FreeLoadBuffer:
        mov     eax, hMem
        push    eax
        call    [_imp__GlobalFree@4]

    ; close file handle only (if no buffer to free)
    CloseOnly:
        mov     eax, hFile
        push    eax
        call    [_imp__CloseHandle@4]

    LoadDone:
        ret
LoadStartupFile endp ; end LoadStartupFile proc

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; save EDIT contents back to CmdFile ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
SaveFile proc    NEAR
    LOCAL hFile: DWORD
    LOCAL hMem:  DWORD
    LOCAL dwSize:DWORD

    ; get EDIT text length
    mov     eax, hEdit
    push    0
    push    0
    push    WM_GETTEXTLENGTH
    push    eax
    call    [_imp__SendMessageA@16]

    ; save size and alloc buffer (+1)
    mov     dwSize, eax
    inc     eax
    push    eax
    push    GMEM_FIXED
    call    [_imp__GlobalAlloc@8]

    ; if alloc ok, save ptr / else abort save
    test    eax, eax
    je      SaveDone
    mov     hMem, eax

    ; get EDIT text into buffer
    mov     edx, dwSize
    inc     edx
    push    eax
    push    edx
    push    WM_GETTEXT
    mov     eax, hEdit
    push    eax
    call    [_imp__SendMessageA@16]

    ; open CmdFile for write (overwrite)
    push    NULL
    push    FILE_ATTRIBUTE_NORMAL
    push    CREATE_ALWAYS
    push    NULL
    push    0
    push    GENERIC_WRITE
    push    OFFSET CmdFile
    call    [_imp__CreateFileA@28]

    ; if open ok, save handle; else free buffer
    cmp     eax, INVALID_HANDLE_VALUE
    je      SaveFree
    mov     hFile, eax

    ; write buffer to file
    push    NULL
    lea     eax, BytesRead
    push    eax
    mov     eax, dwSize
    push    eax
    mov     eax, hMem
    push    eax
    mov     eax, hFile
    push    eax
    call    [_imp__WriteFile@20]

    ; close file
    mov     eax, hFile
    push    eax
    call    [_imp__CloseHandle@4]

    ; clear dirty flag and update title
    xor     eax, eax
    mov     fDirty, eax
    call    ApplyTitle

    ; cleanup - free save buffer
    SaveFree:
        mov     eax, hMem
        push    eax
        call    [_imp__GlobalFree@4]

    SaveDone:
        ret
SaveFile endp ;end SaveFile proc

;;;;;;;;;;;;;;;;;;;;;;;
; program entry point ;
;;;;;;;;;;;;;;;;;;;;;;;
MainEntry proc NEAR

    LOCAL   hInstance: HINSTANCE
    LOCAL   wc:        WNDCLASS
    LOCAL   msg:       MSG

    ; get program HINSTANCE
    push    NULL
    call    [_imp__GetModuleHandleA@4]
    mov     hInstance, eax

    ; load modern Rich Edit control library
    push    OFFSET RichDll
    call    [_imp__LoadLibraryA@4]


    push    10
    pop     ecx
    xor     eax, eax
    lea     edi, wc
    rep stosd

    ; initialize WNDCLASSEX
    ;mov     wc.cbSize, SIZEOF WNDCLASSEX
    
    mov     wc.lpfnWndProc, OFFSET WndProc
    mov     eax, hInstance
    mov     wc.hInstance, eax
    mov     wc.lpszClassName, OFFSET ClassName

    ; register window class
    lea     eax, wc
    push    eax
    call    [_imp__RegisterClassA@4]

    ; parse command line for startup file
    call    ParseStartupFile
    
    ; exit program if no startup file
    cmp     byte ptr [CmdFile], 0
    je      MainRet

    ; create main application window
    push    NULL
    push    hInstance
    push    NULL
    push    NULL
    push    WindowHeight
    push    WindowWidth
    push    CW_USEDEFAULT
    push    CW_USEDEFAULT
    push    WS_OVERLAPPEDWINDOW or WS_VISIBLE
    push    OFFSET ClassName
    push    OFFSET ClassName
    push    0
    call    [_imp__CreateWindowExA@48]

    ; if create window ok, save hwnd / else exit
    test    eax, eax
    je      MainRet
    
    mov     hMain, eax

    ; load file and set title
    call    LoadStartupFile
    xor     eax, eax
    mov     fDirty, eax
    call    ApplyTitle

    MessageLoop:

        ; get next message
        push    0
        push    0
        push    NULL
        lea     eax, msg
        push    eax
        call    [_imp__GetMessageA@16]

        ; message WM_QUIT: exit loop
        test    eax, eax
        je      DoneMessages

        ; translate key input
        lea     eax, msg
        push    eax
        call    [_imp__TranslateMessage@4]

        ; dispatch message to WndProc
        lea     eax, msg
        push    eax
        call    [_imp__DispatchMessageA@4]

        ; loop for next message
        jmp     MessageLoop

    ; get exit code from WM_QUIT
    DoneMessages:
        mov     eax, msg.wParam

    ; final exit point of the program
    MainRet:
        push    eax
        call    [_imp__ExitProcess@4]

MainEntry endp


WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM

    ; check for WM_CREATE
    cmp     uMsg, WM_CREATE
    jne     NotWMCreate

    ; EDIT control (class "RICHEDIT50W")
    mov     eax, WS_CHILD or WS_VISIBLE or WS_BORDER or ES_LEFT \
                 or ES_MULTILINE or ES_AUTOVSCROLL or WS_VSCROLL

    ; create EDIT control
    EditStyleReady:
        push    NULL     ; lpParam
        push    NULL     ; no hInstance needed for EDIT control
        
	;push    IDC_EDIT ; hMenu / child ID
	push    NULL
	
        push    hWnd ; parent
        push    0    ; height -- we can get away with setting
        push    0    ; width     these to 0 because REDIT will
        push    0    ; y         auto resize anyway
        push    0    ; x
        push    eax
        push    NULL
        push    OFFSET EditClass ; "RICHEDIT50W"
        push    0
        call    [_imp__CreateWindowExA@48]

        ; add save command to system menu
        mov     hEdit, eax ; save EDIT HWND

        ; Rich Edit needs an event mask for EN_CHANGE notifications
        push    ENM_CHANGE
        push    0
        push    EM_SETEVENTMASK
        push    eax
        call    [_imp__SendMessageA@16]

        ; raise Rich Edit user editing limit
        push    07FFFFFFEh
        push    0
        push    EM_EXLIMITTEXT
        mov     eax, hEdit
        push    eax
        call    [_imp__SendMessageA@16]

        ;; we call this elsewhere anyway ;;
	; set default Rich Edit font
        ;push    OFFSET RichFont
        ;push    0
        ;push    EM_SETCHARFORMAT
        ;mov     eax, hEdit
        ;push    eax
        ;call    [_imp__SendMessageA@16]
	
        push    FALSE
        push    hWnd
        call    [_imp__GetSystemMenu@8]
        push    OFFSET SaveText
        push    IDM_SAVE
        push    MF_STRING
        push    eax
        call    [_imp__AppendMenuA@16]
        xor     eax, eax
        ret

    ; handle system menu Save
    NotWMCreate:
        cmp     uMsg, WM_SYSCOMMAND
        jne     NotWMSysCommand
        mov     eax, wParam
        cmp     eax, IDM_SAVE
        jne     NotWMSysCommand
        call    SaveFile
        xor     eax, eax
        ret
    
    ;if not the save command
    NotWMSysCommand:
        cmp     uMsg, WM_COMMAND
        jne     NotWMCommand

        ; check for EN_CHANGE from EDIT
	cmp     word ptr [wParam+2], EN_CHANGE
	
        jne     CommandDone

        ; already dirty: ignore
        cmp     fDirty, 0
        jne     CommandDone

        ; mark dirty and update title
        push    1
        pop     eax
        mov     fDirty, eax
        call    ApplyTitle

    ; message handled, return 0
    CommandDone:
        xor     eax, eax
        ret

    ; check for a resize message
    NotWMCommand:
        cmp     uMsg, WM_SIZE
        jne     NotWMSize

        ; resize EDIT - doesn't check if
	; EDIT exists, it just does it
        mov     eax, hEdit  ; EDIT HWND

        ; unpack width/height from WM_SIZE lParam
        mov     edx, lParam ; packed w/h
        movzx   ecx, dx     ; width
        shr     edx, 16     ; height

        ; resize EDIT to fill window area
        push    SWP_NOZORDER
        push    edx
        push    ecx
        push    0
        push    0
        push    NULL
	
	; Using EAX here avoids an extra
	; load and saves a few bytes
        ; EAX already holds hEdit
        push    eax
	
        call    [_imp__SetWindowPos@28]

    ; resize handled, return 0
    SizeDone:
        xor     eax, eax
        ret

    ; check for WM_DESTROY
    NotWMSize:
        cmp     uMsg, WM_DESTROY
        jne     NotWMDestroy

        ; post quit message and exit
        push    0
        call    [_imp__PostQuitMessage@4]
        xor     eax, eax
        ret

    ; default message handling
    NotWMDestroy:
        push    lParam
        push    wParam
        push    uMsg
        push    hWnd
        call    [_imp__DefWindowProcA@16]
        ret

WndProc endp ; end WndProc

END MainEntry

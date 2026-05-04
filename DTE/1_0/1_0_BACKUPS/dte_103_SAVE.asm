;-------------------------------------------------------------------------------------------------------------------
; Tiny window + classic EDIT control
; Based on Dave Plummer's tiny app
;-------------------------------------------------------------------------------------------------------------------

.386
.model flat, stdcall
option casemap:none
 
include windows.inc
include user32.inc
include kernel32.inc

WindowWidth     equ 640
WindowHeight    equ 480
IDC_EDIT        equ 1001
MAX_CMD_PATH    equ 260
MAX_TITLE       equ 320
IDM_SAVE        equ 0E100h

.DATA

EXTERN _imp__CreateWindowExA@48    :PTR
EXTERN _imp__GetModuleHandleA@4    :PTR
EXTERN _imp__RegisterClassExA@4    :PTR
EXTERN _imp__UpdateWindow@4        :PTR
EXTERN _imp__GetMessageA@16        :PTR
EXTERN _imp__TranslateMessage@4    :PTR
EXTERN _imp__DispatchMessageA@4    :PTR
EXTERN _imp__PostQuitMessage@4     :PTR
EXTERN _imp__DefWindowProcA@16     :PTR
EXTERN _imp__SetWindowPos@28       :PTR
EXTERN _imp__GetCommandLineA@0     :PTR
EXTERN _imp__CreateFileA@28        :PTR
EXTERN _imp__GetFileSize@8         :PTR
EXTERN _imp__GlobalAlloc@8         :PTR
EXTERN _imp__GlobalFree@4          :PTR
EXTERN _imp__ReadFile@20           :PTR
EXTERN _imp__WriteFile@20          :PTR
EXTERN _imp__CloseHandle@4         :PTR
EXTERN _imp__SetWindowTextA@8      :PTR
EXTERN _imp__GetSystemMenu@8       :PTR
EXTERN _imp__AppendMenuA@16        :PTR
EXTERN _imp__SendMessageA@16       :PTR

ClassName   db ".",0
AppName     db ".",0
EditClass   db "EDIT",0
DirtyMark   db "*",0
SaveText    db "Save",0

hMain       dd 0
hEdit       dd 0
CmdFile     db MAX_CMD_PATH dup (0)
TitleBuf    db MAX_TITLE dup (0)
BytesRead   dd 0
fLoading    dd 0
fDirty      dd 0

.CODE

BuildTitle proc NEAR
    ; build caption from startup file name
    ; add " *" if the buffer has been modified

    lea     edi, TitleBuf
    mov     esi, OFFSET AppName

    cmp     byte ptr [CmdFile], 0
    je      CopyBase

    mov     esi, OFFSET CmdFile
    mov     ebx, esi

FindTail:
    mov     al, [esi]
    test    al, al
    je      GotTail
    cmp     al, '\'
    je      MarkTail
    cmp     al, '/'
    je      MarkTail
    cmp     al, ':'
    je      MarkTailNext
    inc     esi
    jmp     FindTail

MarkTail:
    mov     ebx, esi
    inc     ebx
    inc     esi
    jmp     FindTail

MarkTailNext:
    mov     ebx, esi
    inc     ebx
    inc     esi
    jmp     FindTail

GotTail:
    mov     esi, ebx

CopyBase:
CopyLoop:
    mov     al, [esi]
    test    al, al
    je      CopyEnd
    mov     [edi], al
    inc     edi
    inc     esi
    jmp     CopyLoop

CopyEnd:
    cmp     fDirty, 0
    je      TitleDone

    mov     esi, OFFSET DirtyMark
DirtyLoop:
    mov     al, [esi]
    test    al, al
    je      TitleDone
    mov     [edi], al
    inc     edi
    inc     esi
    jmp     DirtyLoop

TitleDone:
    mov     byte ptr [edi], 0
    ret
BuildTitle endp

ApplyTitle proc NEAR
    call    BuildTitle
    push    OFFSET TitleBuf
    mov     eax, hMain
    push    eax
    call    [_imp__SetWindowTextA@8]
    ret
ApplyTitle endp

ParseStartupFile proc NEAR
    ; parse command line for one startup file
    ; this is for dropping a file on tiny.exe at launch only

    call    [_imp__GetCommandLineA@0]
    mov     esi, eax

    test    esi, esi
    je      NoArg

    cmp     byte ptr [esi], '"'
    jne     SkipExeBare

    inc     esi
SkipExeQuoted:
    mov     al, [esi]
    test    al, al
    je      NoArg
    inc     esi
    cmp     al, '"'
    jne     SkipExeQuoted
    jmp     SkipWs

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

SkipWs:
    mov     al, [esi]
    cmp     al, ' '
    je      SkipWsStep
    cmp     al, 9
    je      SkipWsStep
    jmp     ArgStart
SkipWsStep:
    inc     esi
    jmp     SkipWs

ArgStart:
    cmp     byte ptr [esi], 0
    je      NoArg

    lea     edi, CmdFile
    mov     ecx, MAX_CMD_PATH-1

    cmp     byte ptr [esi], '"'
    jne     CopyBare
    inc     esi

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

CopyDone:
    mov     byte ptr [edi], 0
    ret

NoArg:
    mov     byte ptr [CmdFile], 0
    ret
ParseStartupFile endp

LoadStartupFile proc NEAR
    LOCAL hFile:DWORD
    LOCAL hMem:DWORD
    LOCAL dwSize:DWORD

    cmp     byte ptr [CmdFile], 0
    je      LoadDone

    push    NULL
    push    FILE_ATTRIBUTE_NORMAL
    push    OPEN_EXISTING
    push    NULL
    push    FILE_SHARE_READ
    push    GENERIC_READ
    push    OFFSET CmdFile
    call    [_imp__CreateFileA@28]

    cmp     eax, INVALID_HANDLE_VALUE
    je      LoadDone
    mov     hFile, eax

    push    NULL
    push    eax
    call    [_imp__GetFileSize@8]

    cmp     eax, 0FFFFFFFFh
    je      CloseOnly
    mov     dwSize, eax

    inc     eax
    push    eax
    push    GMEM_FIXED
    call    [_imp__GlobalAlloc@8]

    test    eax, eax
    je      CloseOnly
    mov     hMem, eax

    push    1
    pop     eax
    mov     fLoading, eax

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

    test    eax, eax
    je      ClearLoadAndFree

    mov     eax, hMem
    mov     ecx, BytesRead
    mov     byte ptr [eax+ecx], 0

    push    eax
    mov     eax, hEdit
    push    eax
    call    [_imp__SetWindowTextA@8]

ClearLoadAndFree:
    xor     eax, eax
    mov     fLoading, eax

    mov     eax, hMem
    push    eax
    call    [_imp__GlobalFree@4]

CloseOnly:
    mov     eax, hFile
    push    eax
    call    [_imp__CloseHandle@4]

LoadDone:
    ret
LoadStartupFile endp

SaveFile proc NEAR
    LOCAL hFile:DWORD
    LOCAL hMem:DWORD
    LOCAL dwSize:DWORD

    cmp     byte ptr [CmdFile], 0
    je      SaveDone

    mov     eax, hEdit
    push    0
    push    0
    push    WM_GETTEXTLENGTH
    push    eax
    call    [_imp__SendMessageA@16]
    mov     dwSize, eax
    inc     eax
    push    eax
    push    GMEM_FIXED
    call    [_imp__GlobalAlloc@8]
    test    eax, eax
    je      SaveDone
    mov     hMem, eax

    mov     edx, dwSize
    inc     edx
    push    eax
    push    edx
    push    WM_GETTEXT
    mov     eax, hEdit
    push    eax
    call    [_imp__SendMessageA@16]

    push    NULL
    push    FILE_ATTRIBUTE_NORMAL
    push    CREATE_ALWAYS
    push    NULL
    push    0
    push    GENERIC_WRITE
    push    OFFSET CmdFile
    call    [_imp__CreateFileA@28]
    cmp     eax, INVALID_HANDLE_VALUE
    je      SaveFree
    mov     hFile, eax

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

    mov     eax, hFile
    push    eax
    call    [_imp__CloseHandle@4]

    xor     eax, eax
    mov     fDirty, eax
    call    ApplyTitle

SaveFree:
    mov     eax, hMem
    push    eax
    call    [_imp__GlobalFree@4]

SaveDone:
    ret
SaveFile endp

MainEntry proc NEAR

    LOCAL   hInstance:HINSTANCE
    LOCAL   wc:WNDCLASSEX
    LOCAL   msg:MSG
    LOCAL   hwnd:HWND

    push    NULL
    call    [_imp__GetModuleHandleA@4]
    mov     hInstance, eax

    ; memset(&wc, 0, sizeof(wc))
    push    12
    pop     ecx
    xor     eax, eax
    lea     edi, wc
    rep stosd

    mov     wc.cbSize, SIZEOF WNDCLASSEX
    mov     wc.style, CS_HREDRAW or CS_VREDRAW
    mov     wc.lpfnWndProc, OFFSET WndProc
    mov     eax, hInstance
    mov     wc.hInstance, eax
    mov     wc.hbrBackground, COLOR_3DFACE+1
    mov     wc.lpszClassName, OFFSET ClassName

    lea     eax, wc
    push    eax
    call    [_imp__RegisterClassExA@4]

    push    NULL
    push    hInstance
    push    NULL
    push    NULL
    push    WindowHeight
    push    WindowWidth
    push    CW_USEDEFAULT
    push    CW_USEDEFAULT
    push    WS_OVERLAPPEDWINDOW or WS_VISIBLE
    push    OFFSET AppName
    push    OFFSET ClassName
    push    0
    call    [_imp__CreateWindowExA@48]

    test    eax, eax
    je      MainRet
    mov     hwnd, eax
    mov     hMain, eax

    call    ParseStartupFile
    call    LoadStartupFile
    call    ApplyTitle

    mov     eax, hwnd
    push    eax
    call    [_imp__UpdateWindow@4]

MessageLoop:

    push    0
    push    0
    push    NULL
    lea     eax, msg
    push    eax
    call    [_imp__GetMessageA@16]

    test    eax, eax
    je      DoneMessages

    lea     eax, msg
    push    eax
    call    [_imp__TranslateMessage@4]

    lea     eax, msg
    push    eax
    call    [_imp__DispatchMessageA@4]

    jmp     MessageLoop

DoneMessages:
    mov     eax, msg.wParam

MainRet:
    ret

MainEntry endp


WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM

    cmp     uMsg, WM_CREATE
    jne     NotWMCreate

    ; EDIT control (class "EDIT")
    push    NULL                            ; lpParam
    push    NULL                            ; hInstance (OK for standard control)
    push    IDC_EDIT                        ; hMenu / child ID
    push    hWnd                            ; parent
    push    430                             ; height
    push    600                             ; width
    push    10                              ; y
    push    10                              ; x
    push    WS_CHILD or WS_VISIBLE or WS_BORDER or \
            ES_LEFT or ES_MULTILINE or ES_AUTOVSCROLL or \
            WS_VSCROLL
    push    NULL
    push    OFFSET EditClass            ; "EDIT"
    push    0
    call    [_imp__CreateWindowExA@48]

    mov     hEdit, eax                  ; save EDIT HWND
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

NotWMCreate:

    cmp     uMsg, WM_SYSCOMMAND
    jne     NotWMSysCommand
    mov     eax, wParam
    cmp     eax, IDM_SAVE
    jne     NotWMSysCommand
    call    SaveFile
    xor     eax, eax
    ret

NotWMSysCommand:

    cmp     uMsg, WM_COMMAND
    jne     NotWMCommand

    mov     eax, lParam
    cmp     eax, hEdit
    jne     CommandDone

    mov     eax, wParam
    shr     eax, 16
    cmp     eax, EN_CHANGE
    jne     CommandDone

    cmp     fLoading, 0
    jne     CommandDone

    cmp     fDirty, 0
    jne     CommandDone

    push    1
    pop     eax
    mov     fDirty, eax
    call    ApplyTitle

CommandDone:
    xor     eax, eax
    ret

NotWMCommand:

    cmp     uMsg, WM_SIZE
    jne     NotWMSize

    ; resize path.
    mov     eax, hEdit                  ; EDIT HWND
    test    eax, eax
    je      SizeDone

    mov     edx, lParam                 ; packed w/h
    movzx   ecx, dx                     ; width
    shr     edx, 16                     ; height

    push    SWP_NOZORDER
    push    edx
    push    ecx
    push    0
    push    0
    push    NULL
    push    eax
    call    [_imp__SetWindowPos@28]

SizeDone:
    xor     eax, eax
    ret

NotWMSize:

    cmp     uMsg, WM_DESTROY
    jne     NotWMDestroy

    push    0
    call    [_imp__PostQuitMessage@4]
    xor     eax, eax
    ret

NotWMDestroy:

    push    lParam
    push    wParam
    push    uMsg
    push    hWnd
    call    [_imp__DefWindowProcA@16]
    ret

WndProc endp

END MainEntry

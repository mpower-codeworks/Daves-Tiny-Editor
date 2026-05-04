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

ClassName   db "DaveTinyClass",0
AppName     db "Dave's Tiny App + EDIT",0
EditClass   db "EDIT",0
EditText    db "The EDIT control",13,10,\
               "been in there",13,10,\
               "since NT 5.0",0

hEdit       dd 0

.CODE

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
    push    OFFSET EditText
    push    OFFSET EditClass            ; "EDIT"
    push    0
    call    [_imp__CreateWindowExA@48]

    mov     hEdit, eax                  ; save EDIT HWND
    xor     eax, eax
    ret

NotWMCreate:

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
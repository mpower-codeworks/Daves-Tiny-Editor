;;;;;;;;;;;;;;;;;
;;   DTE  3.0  ;;
;;;;;;;;;;;;;;;;;
;;    --*--    ;;
;; mpower 2026 ;;
;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; crinkler experimentation is ;;
;; part of this project design ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; build history with exe size result ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; 000 init amd clear thread   - 372 bytes exe
; 001 create first API window - 404 bytes
; 002 enable quit             - 434 bytes
; 003 enable X to quit        - 445 bytes
; 004 enable min and max      - 472 bytes
; 005 enable mouse resize     - 459 bytes
; 006 true mouse resize       - 451 bytes
; 007 start size 800x600      - 455 bytes
; 008 add RichEdit20W         - 491 bytes
; 009
; 010

;;;;;;;;;;;;;;;;;;;
;; initial setup ;;
;;;;;;;;;;;;;;;;;;;
.386                 ; enable 80386 instrctns and 32-bit rgistrs
.model flat          ; use the 32-bit flat memory model
option casemap:none  ; preserve symbol case exactly as written

;;;;;;;;;;;;;;;;
;; API import ;;
;;;;;;;;;;;;;;;;
EXTERN __imp__CreateWindowExA@48:DWORD ; create predefined API window
EXTERN __imp__GetMessageA@16    :DWORD ; wait for one queued window msg
EXTERN __imp__DispatchMessageA@4:DWORD ; send msg to built-in wnd proc
EXTERN __imp__DefWindowProcA@16 :DWORD ; use default top-level wnd proc
EXTERN __imp__SetWindowLongA@12 :DWORD ; replace Static window proc
EXTERN __imp__LoadLibraryA@4    :DWORD ; load Rich Edit class DLL

.code                                  ; begin executable machine-code section

;;;;;;;;;;;;;;;;;
;; WinX86Entry ;;
;;;;;;;;;;;;;;;;;
WinX86Entry:
    xor     eax, eax           ; hold zero for empty window arguments

    push    eax                ; lpParam      = no creation data
    push    eax                ; hInstance    = USER32 class is global
    push    eax                ; hMenu        = no menu
    push    eax                ; hWndParent   = make top-level window
;; unused ;; push    7Fh       ; nHeight      = 127 px short immediate
;; unused ;; push    7Fh       ; nWidth       = 127 px short immediate
    push    258h               ; nHeight      = 600 px
    push    320h               ; nWidth       = 800 px
    push    eax                ; Y            = zero
    push    eax                ; X            = zero
    push    10CF0000h          ; style        = visible overlapped window
    push    eax                ; lpWindowName = no title
    push    OFFSET StaticClass ; lpClassName  = USER32 Static
    push    eax                ; dwExStyle    = none

    call    [__imp__CreateWindowExA@48] ; create first HWND

    xchg    ebx, eax                    ; keep HWND in callee-saved EBX

;;;;;;;;;;;;;;;;;;;;
;; DefaultWndProc ;;
;;;;;;;;;;;;;;;;;;;;
    push    dword ptr [__imp__DefWindowProcA@16] ; new window proc
    push    -4                                   ; nIndex = GWL_WNDPROC
    push    ebx                                  ; hWnd   = created window

    call    [__imp__SetWindowLongA@12]           ; replace Static procedure

    sub     esp, 1Ch                             ; reserve one 28-byte MSG structure
    mov     esi, esp                             ; keep MSG address in callee-saved ESI
    xor     edi, edi                             ; keep zero in callee-saved EDI

;;;;;;;;;;;;;;;;;;
;; LoadRichEdit ;;
;;;;;;;;;;;;;;;;;;
    push    OFFSET RichDll            ; lpLibFileName = Riched20.dll
    call    [__imp__LoadLibraryA@4]   ; register RichEdit20W class

;;;;;;;;;;;;;;;;;;
;; RichEdit20W  ;;
;;;;;;;;;;;;;;;;;;
    push    edi                 ; lpParam      = no creation data
    push    edi                 ; hInstance    = no local class instance
    push    edi                 ; hMenu        = no child ID
    push    ebx                 ; hWndParent   = main window
    push    7Fh                 ; nHeight      = 127 px short immediate
    push    7Fh                 ; nWidth       = 127 px short immediate
    push    edi                 ; Y            = zero
    push    edi                 ; X            = zero
    push    50000004h           ; style        = child visible multiline
    push    edi                 ; lpWindowName = no initial text
    push    OFFSET RichClass    ; lpClassName  = RichEdit20W
    push    edi                 ; dwExStyle    = none

    call    [__imp__CreateWindowExA@48] ; create first Rich Edit control

;;;;;;;;;;;;;;;;;
;; MessageLoop ;;
;;;;;;;;;;;;;;;;;
MessageLoop:
    push    edi                     ; wMsgFilterMax = zero
    push    edi                     ; wMsgFilterMin = zero
    push    ebx                     ; hWnd          = created window only
    push    esi                     ; lpMsg         = stack MSG structure

    call    [__imp__GetMessageA@16] ; wait for next window message

    test    eax, eax                ; zero  = quit; minus one = dead HWND
    jle     MessageExit             ; leave when window no longer exists

;;;;;;;;;;;;;;;;;;;;;;;
;; CloseButton Old   ;;
;;;;;;;;;;;;;;;;;;;;;;;
;; unused ;; cmp     byte ptr [esi+4], 0A1h ; WM_NCLBUTTONDOWN?
;; unused ;; jne     DispatchQueued         ; use built-in wnd proc
;; unused ;; cmp     byte ptr [esi+8], 14h  ; wParam = HTCLOSE?
;; unused ;; je      MessageExit            ; return directly to NT

;;;;;;;;;;;;;;;;;;;;;;;;
;; CaptionButtons Old ;;
;;;;;;;;;;;;;;;;;;;;;;;;
;; unused ;; cmp     byte ptr [esi+4], 0A1h ; WM_NCLBUTTONDOWN?
;; unused ;; jne     DispatchQueued         ; use built-in Static proc
;; unused ;; mov     eax, [esi+8]           ; EAX = hit-test value
;; unused ;; sub     al, 8                  ; min=0 max=1 close=12
;; unused ;; cmp     al, 1                  ; min or max button?
;; unused ;; jbe     DefaultCaption         ; let DefWindowProc act
;; unused ;; cmp     al, 0Ch                ; close button?
;; unused ;; jne     DispatchQueued         ; normal Static dispatch

;;;;;;;;;;;;;;;;;;;;;;;;
;; NonClientMouse Old ;;
;;;;;;;;;;;;;;;;;;;;;;;;
;; unused ;; cmp     byte ptr [esi+4], 0A1h ; WM_NCLBUTTONDOWN?
;; unused ;; jne     DispatchQueued         ; use built-in Static proc
;; unused ;;                                ; fall into DefWindowProc

;;;;;;;;;;;;;;;;;;;;;;;;
;; DefaultCaption Old ;;
;;;;;;;;;;;;;;;;;;;;;;;;
;; unused ;; DefaultCaption:
;; unused ;; push    dword ptr [esi+0Ch] ; lParam = screen point
;; unused ;; push    dword ptr [esi+8]   ; wParam = original hit test
;; unused ;; push    dword ptr [esi+4]   ; Msg    = WM_NCLBUTTONDOWN
;; unused ;; push    ebx                 ; hWnd   = created window
;; unused ;; call    [__imp__DefWindowProcA@16]
;; unused ;; jmp     MessageLoop         ; wait for next message

;;;;;;;;;;;;;;;;;;;;
;; DispatchQueued ;;
;;;;;;;;;;;;;;;;;;;;
DispatchQueued:
    push    esi                         ; lpMsg = retrieved message
    call    [__imp__DispatchMessageA@4] ; call default window proc

    jmp     MessageLoop                 ; wait for next message

;;;;;;;;;;;;;;;;;
;; MessageExit ;;
;;;;;;;;;;;;;;;;;
MessageExit:
    add     esp, 1Ch   ; release stack MSG structure
;;  inc     eax        ; unused - only fixed minus one result
    xor     eax, eax   ; return zero for every exit path
    ret                ; return to NT and end process

;;;;;;;;;;;;;;;;;
;; StaticClass ;;
;;;;;;;;;;;;;;;;;
StaticClass db "Static",0   ; ANSI saves bytes and needs no registration

;;;;;;;;;;;;;
;; RichDll ;;
;;;;;;;;;;;;;
RichDll db "Riched20",0     ; loader appends default .DLL extension

;;;;;;;;;;;;;;;
;; RichClass ;;
;;;;;;;;;;;;;;;
RichClass db "RichEdit20W",0 ; Unicode Rich Edit 2 or 3 class

END WinX86Entry

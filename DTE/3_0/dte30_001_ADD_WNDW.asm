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
; 002 
; 003
; 004

;;;;;;;;;;;;;;;;;;;
;; initial setup ;;
;;;;;;;;;;;;;;;;;;;
.386                 ; enable 80386 instrctns and 32-bit rgistrs
.model flat          ; use the 32-bit flat memory model
option casemap:none  ; preserve symbol case exactly as written

;;;;;;;;;;;;;;;;;
;; API import  ;;
;;;;;;;;;;;;;;;;;
EXTERN __imp__CreateWindowExA@48:DWORD ; real CreateWindow API export

.code                                  ; begin executable machine-code section

;;;;;;;;;;;;;;;;;
;; WinX86Entry ;;
;;;;;;;;;;;;;;;;;
WinX86Entry:
    xor     eax, eax           ; hold zero for all empty window arguments

    push    eax                ; lpParam      = no creation data
    push    eax                ; hInstance    = USER32 class is global
    push    eax                ; hMenu        = no menu
    push    eax                ; hWndParent   = make top-level window
    push    7Fh                ; nHeight      = 127 px using short immediate
    push    7Fh                ; nWidth       = 127 px using short immediate
    push    eax                ; Y            = zero
    push    eax                ; X            = zero
    push    10CF0000h          ; style        = visible overlapped window
    push    eax                ; lpWindowName = no title
    push    OFFSET StaticClass ; lpClassName  = USER32 Static
    push    eax                ; dwExStyle    = none

    call    [__imp__CreateWindowExA@48] ; create the first HWND

;;;;;;;;;;;;;;;;;
;; HoldWindow  ;;
;;;;;;;;;;;;;;;;;
HoldWindow:
    jmp     HoldWindow         ; keep window alive; no msg pump yet

;;;;;;;;;;;;;;;;;
;; StaticClass ;;
;;;;;;;;;;;;;;;;;
StaticClass db "Static",0      ; ANSI saves bytes and needs no registration

END WinX86Entry

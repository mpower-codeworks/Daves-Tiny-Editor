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
; 000 init amd clear thread    - 372 bytes exe
; 001 create first API window  - 404 bytes
; 002 enable quit              - 434 bytes
; 003 enable X to quit         - 445 bytes
; 004 enable min and max       - 472 bytes
; 005 enable mouse resize      - 459 bytes
; 006 true mouse resize        - 451 bytes
; 007 start size 800x600       - 455 bytes
; 008 add RichEdit20W          - 491 bytes
; 009 resize RichEdit20W       - 533 bytes
; 010 add keys/mouse handlers  - 536 bytes
; 011 add Courier font         - 566 bytes
; 012 Courier 14 point         - 568 bytes
; 013 fix runaway process      - 575 bytes
; 014 enable vertical scroll   - 576 bytes
; 015 auto vertical scroll     - 587 bytes
; 016 drop file onto EXE       - 709 bytes
; 017 leaf filename title      - 725 bytes
; 018 dirty title marker       - 791 bytes
; 019 system menu save         - 908 bytes
; 020 rmv REDIT initial fit    - 901 bytes
; 021 merge path loops         - 895 bytes
; 022 share title update       - 895 bytes
; 023 reorg dispatch and exit  - 880 bytes
; 024 dispatch exit reorganize - 875 bytes
; 025 
; 026 

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
EXTERN __imp__MoveWindow@24     :DWORD ; fit Rich Edit to client
EXTERN __imp__TranslateMessage@4:DWORD ; convert keys into characters
EXTERN __imp__SendMessageA@16   :DWORD ; send font to Rich Edit
EXTERN __imp__CreateFontA@56    :DWORD ; create Courier font
EXTERN __imp__ExitProcess@4     :DWORD ; terminate entire process
EXTERN __imp__GetClientRect@8   :DWORD ; read initial client size
EXTERN __imp__GetCommandLineA@0 :DWORD ; obtain dropped file path
EXTERN __imp__CreateFileA@28    :DWORD ; open dropped text file
EXTERN __imp__GetFileSize@8     :DWORD ; measure dropped text file
EXTERN __imp__GlobalAlloc@8     :DWORD ; allocate zeroed text buffer
EXTERN __imp__ReadFile@20       :DWORD ; read dropped text file
EXTERN __imp__GetSystemMenu@8   :DWORD ; obtain main System Menu
EXTERN __imp__AppendMenuA@16    :DWORD ; append Save menu command
EXTERN __imp__SetFilePointer@16 :DWORD ; rewind file before saving
EXTERN __imp__WriteFile@20      :DWORD ; write current editor text
EXTERN __imp__SetEndOfFile@4    :DWORD ; truncate old file remainder

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

;;;;;;;;;;;;;;;;;;;;;;;;
;; DefaultWndProc Old ;;
;;;;;;;;;;;;;;;;;;;;;;;;
;; push dword ptr [__imp__DefWindowProcA@16] ; new proc
;; push -4                                   ; GWL_WNDPROC
;; push ebx                                  ; main HWND
;; call [__imp__SetWindowLongA@12]           ; replace proc

    sub     esp, 1Ch                 ; reserve one 28-byte MSG structure
    mov     esi, esp                 ; keep MSG address in callee-saved ESI
    xor     edi, edi                 ; keep zero in callee-saved EDI

;;;;;;;;;;;;;;;;;;
;; SystemMenu   ;;
;;;;;;;;;;;;;;;;;;
    push    edi                     ; bRevert = false
    push    ebx                     ; hWnd    = main window

    call    [__imp__GetSystemMenu@8] ; obtain existing System Menu

    push    OFFSET SaveText         ; lpNewItem = plain Save text
    push    1000h                   ; uIDNewItem = custom Save command
    push    edi                     ; uFlags     = MF_STRING
    push    eax                     ; hMenu      = System Menu

    call    [__imp__AppendMenuA@16] ; append Save at menu bottom

;;;;;;;;;;;;;;;;;;
;; LoadRichEdit ;;
;;;;;;;;;;;;;;;;;;
    push    OFFSET RichDll           ; lpLibFileName = Riched20.dll
    call    [__imp__LoadLibraryA@4]  ; register RichEdit20W class

;;;;;;;;;;;;;;;;;
;; RichEdit20W ;;
;;;;;;;;;;;;;;;;;    
    ;; Move GetClientRect before RichEdit
    push    esi                         ; lpRect = reuse MSG storage
    push    ebx                         ; hWnd   = main window
    call    [__imp__GetClientRect@8]    ; obtain exact client dimensions
    
    push    edi                 ; lpParam      = no creation data
    push    edi                 ; hInstance    = no local class instance
    push    edi                 ; hMenu        = no child ID
    push    ebx                 ; hWndParent   = main window
;; unused ;; push    7Fh        ; nHeight      = 127 px short immediate
;; unused ;; push    7Fh        ; nWidth       = 127 px short immediate
;; brought back b/c we need it ;;
;; removed again
;;  push    258h                ; nHeight      = initial clipped fill
;;  push    320h                ; nWidth       = initial clipped fill
;; use these instead
    push    dword ptr [esi+0Ch] ; nHeight = client bottom
    push    dword ptr [esi+8]   ; nWidth  = client right
    
    push    edi                 ; Y            = zero
    push    edi                 ; X            = zero
;; unused ;; push    50000004h  ; child visible multiline
;; unused ;; push    50202044h  ; kept disabled bar when text fit
    push    50200044h           ; show bar only when text overflows
    push    edi                 ; lpWindowName = no initial text
    push    OFFSET RichClass    ; lpClassName  = RichEdit20W
    push    edi                 ; dwExStyle    = none

    call    [__imp__CreateWindowExA@48] ; create first Rich Edit control

    mov     RichHwnd, eax       ; save child HWND in writable storage


;;;;;;;;;;;;;;;;
;; InitialFit ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; not using this anymore ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;InitialFit:
;;    push    esi                 ; lpRect = reuse MSG storage as RECT
;;    push    ebx                 ; hWnd   = main window
;;
;;    call    [__imp__GetClientRect@8] ; read exact initial client size
;;
;;    push    eax                 ; bRepaint = nonzero result means yes
;;    push    dword ptr [esi+0Ch] ; nHeight  = client bottom
;;    push    dword ptr [esi+8]   ; nWidth   = client right
;;    push    edi                 ; Y        = zero
;;    push    edi                 ; X        = zero
;;    push    RichHwnd            ; hWnd     = Rich Edit child
;;
;;    call    [__imp__MoveWindow@24] ; expose exact right client border

;;;;;;;;;;;;;;
;; Courier  ;;
;;;;;;;;;;;;;;
    push    OFFSET CourierFace  ; lpszFace = Courier
;; unused ;; push    0Dh        ; thirteen zero font arguments
    push    0Ch                 ; twelve remaining zero arguments
    pop     ecx                 ; ECX = compact zero-push counter

CourierZeros:
    push    edi                 ; push one zero CreateFont argument
    loop    CourierZeros        ; repeat for twelve zero arguments

    push    -19                 ; nHeight = 14 points at normal 96 DPI
    call    [__imp__CreateFontA@56] ; create 14-point Courier HFONT

    push    edi                 ; lParam = no immediate redraw needed
    push    eax                 ; wParam = new Courier HFONT
    push    30h                 ; Msg    = WM_SETFONT
    push    RichHwnd            ; hWnd   = Rich Edit child

    call    [__imp__SendMessageA@16] ; apply Courier to Rich Edit

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DropOpen new parser saved 7 bytes ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
DropOpen:
    call    [__imp__GetCommandLineA@0] ; full process command line
    xchg    ebp, eax                   ; EBP = command-line cursor

    mov     cl, 20h                    ; plain argument ends at space
    cmp     byte ptr [ebp], 22h        ; quoted executable path?
    jne     DropExeScan                ; no = scan for separating space

    inc     ebp                        ; skip opening executable quote
    mov     cl, 22h                    ; quoted argument ends at quote

DropExeScan:
    inc     ebp                        ; inspect next executable byte
    mov     al, byte ptr [ebp]         ; AL = current command-line byte
    test    al, al                     ; command line ended?
    je      ResizeProc                 ; yes = no dropped file
    cmp     al, cl                     ; executable delimiter found?
    jne     DropExeScan                ; no = continue scanning

DropSkip:
    inc     ebp                        ; move beyond quote or space
    cmp     byte ptr [ebp], 20h        ; another separating space?
    je      DropSkip                   ; yes = skip it
    cmp     byte ptr [ebp], 0          ; file argument present?
    je      ResizeProc                 ; no = open empty editor

    mov     cl, 20h                    ; plain file ends at space
    cmp     byte ptr [ebp], 22h        ; quoted dropped path?
    jne     DropEndStart               ; no = EBP already starts path

    inc     ebp                        ; skip opening file quote
    mov     cl, 22h                    ; quoted file ends at quote

DropEndStart:
    mov     eax, ebp                   ; EAX = path scanner
    mov     edx, ebp                   ; EDX = leaf until slash found

DropEnd:
    cmp     byte ptr [eax], 0          ; command line ended?
    je      DropFile                   ; yes = path already terminated
    cmp     byte ptr [eax], cl         ; argument delimiter found?
    je      DropCut                    ; yes = terminate path there
    cmp     byte ptr [eax], 5Ch        ; Windows path separator?
    jne     DropNext                   ; no = continue path scan

    lea     edx, [eax+1]               ; EDX = byte after last backslash

DropNext:
    inc     eax                        ; inspect next path byte
    jmp     DropEnd                    ; continue scanning

DropCut:
    mov     byte ptr [eax], 0          ; terminate file path

DropFile:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; old command-line parser ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; ;;;;;;;;;;;;;;
;; ;; DropOpen ;;
;; ;;;;;;;;;;;;;;
;; DropOpen:
;;     call    [__imp__GetCommandLineA@0]  ; full process command line
;;     mov     ebp, eax                    ; EBP = command-line cursor
;;     cmp     byte ptr [ebp], 22h         ; quoted executable path?
;;     jne     DropExePlain                ; no = find first space
;;
;; DropExeQuote:  
;;     inc     ebp                         ; scan quoted executable path
;;     cmp     byte ptr [ebp], 22h         ; closing quote found?
;;     jne     DropExeQuote                ; no = keep scanning
;;     jmp     DropSkip                    ; yes = move to file argument
;;
;; DropExePlain:
;;     cmp     byte ptr [ebp], 0           ; no second argument?
;;     je      ResizeProc                  ; yes = open empty editor
;;     inc     ebp                         ; scan plain executable path
;;     cmp     byte ptr [ebp], 20h         ; first separating space?
;;     jne     DropExePlain                ; no = keep scanning
;;
;; DropSkip:
;;     inc     ebp                         ; move beyond quote or space
;;     cmp     byte ptr [ebp], 20h         ; another separating space?
;;     je      DropSkip                    ; yes = skip it
;;     cmp     byte ptr [ebp], 0           ; file argument present?
;;     je      ResizeProc                  ; no = open empty editor
;;     cmp     byte ptr [ebp], 22h         ; quoted dropped path?
;;     jne     DropPlainEnd                ; no = terminate at next space
;;
;;     inc     ebp                         ; EBP = first quoted path byte
;;     mov     eax, ebp                    ; EAX = end scanner
;;
;; DropQuoteEnd:
;;     cmp     byte ptr [eax], 0           ; malformed missing quote?
;;     je      DropFile                    ; yes = use remaining string
;;     cmp     byte ptr [eax], 22h         ; closing file quote?
;;     je      DropCut                     ; yes = terminate path there
;;     inc     eax                         ; inspect next path byte
;;     jmp     DropQuoteEnd                ; continue quoted path scan
;;
;; DropPlainEnd:
;;     mov     eax, ebp                    ; EAX = end scanner
;;
;; DropPlainScan:
;;     cmp     byte ptr [eax], 0           ; command line ended?
;;     je      DropFile                    ; yes = path already terminated
;;     cmp     byte ptr [eax], 20h         ; another argument begins?
;;     je      DropCut                     ; yes = terminate first path
;;     inc     eax                         ; inspect next path byte
;;     jmp     DropPlainScan               ; continue plain path scan
;;
;; DropCut:
;;     mov     byte ptr [eax], 0           ; replace delimiter with terminator
;;
;; DropFile:
;;     mov     edx, eax                    ; EDX = terminating zero after path
;;
;; DropLeaf:
;;     cmp     edx, ebp                    ; reached beginning of path?
;;     je      DropTitle                   ; yes = entire path is the leaf
;;     dec     edx                         ; inspect previous path character
;;     cmp     byte ptr [edx], 5Ch         ; Windows path separator?
;;     jne     DropLeaf                    ; no = keep scanning backward
;;     inc     edx                         ; EDX = first byte of leaf filename  


DropTitle:
    mov     eax, OFFSET TitleText       ; EAX = writable title destination

TitleCopy:
    mov     cl, byte ptr [edx]          ; copy one leaf filename byte
    mov     byte ptr [eax], cl          ; store it in writable title buffer
    inc     edx                         ; advance source
    inc     eax                         ; advance destination
    test    cl, cl                      ; copied terminating zero?
    jne     TitleCopy                   ; no = continue copying leaf

    dec     eax                         ; EAX = clean title terminator
    mov     TitleEnd, eax               ; save append/remove position

    push    OFFSET TitleText            ; lParam = writable filename leaf
    push    edi                         ; wParam = unused
    push    0Ch                         ; Msg    = WM_SETTEXT
    push    ebx                         ; hWnd   = main window

    call    [__imp__SendMessageA@16]    ; show leaf in title bar

    push    edi                         ; hTemplateFile = none
    push    edi                         ; flags         = default
    push    3                           ; creation      = OPEN_EXISTING
    push    edi                         ; security      = none
    push    7                           ; share read write and delete
;; unused ;; push    80000000h          ; access = GENERIC_READ only
    push    0C0000000h                  ; access = GENERIC_READ or WRITE
    push    ebp                         ; lpFileName = dropped path

    call    [__imp__CreateFileA@28]     ; open dropped text file

    inc     eax                         ; INVALID_HANDLE_VALUE becomes zero
    jz      ResizeProc                  ; open failed = leave editor empty
    dec     eax                         ; restore valid file handle
    mov     FileHnd, eax                ; retain handle for System Menu Save
    xchg    ebp, eax                    ; EBP = open file handle

    push    edi                         ; lpFileSizeHigh = none
    push    ebp                         ; hFile          = dropped file
    call    [__imp__GetFileSize@8]      ; EAX = byte count

    inc     eax                         ; error value becomes zero
    jz      ResizeProc                  ; size failed = leave editor empty
    dec     eax                         ; restore original byte count
    push    ebp                         ; preserve file handle
    push    eax                         ; preserve file byte count
    inc     eax                         ; include trailing zero byte
    push    eax                         ; dwBytes = file size plus one
    push    40h                         ; uFlags  = GPTR zeroed fixed memory

    call    [__imp__GlobalAlloc@8]      ; allocate text buffer

    mov     ebp, eax                    ; EBP = zero-terminated text buffer
    pop     ecx                         ; ECX = original file byte count
    pop     edx                         ; EDX = preserved file handle
    test    ebp, ebp                    ; allocation succeeded?
    jz      ResizeProc                  ; no = leave editor empty

    push    edi                         ; lpOverlapped          = none
    push    esi                         ; lpNumberOfBytesRead   = MSG scratch
    push    ecx                         ; nNumberOfBytesToRead  = file size
    push    ebp                         ; lpBuffer              = text memory
    push    edx                         ; hFile                 = dropped file

    call    [__imp__ReadFile@20]        ; read entire text file

    push    dword ptr [esi]             ; lParam = actual bytes read
    push    edi                         ; wParam = reserved zero
    push    435h                        ; Msg    = EM_EXLIMITTEXT
    push    RichHwnd                    ; hWnd   = Rich Edit child

    call    [__imp__SendMessageA@16]    ; permit full dropped-file length

    push    ebp                         ; lParam = loaded ANSI text
    push    edi                         ; wParam = unused
    push    0Ch                         ; Msg    = WM_SETTEXT
    push    RichHwnd                    ; hWnd   = Rich Edit child

    call    [__imp__SendMessageA@16]    ; display dropped file in editor

;;;;;;;;;;;;;;;;
;; ResizeProc ;;
;;;;;;;;;;;;;;;;
ResizeProc:
;; brought back b/c we need it ;;
    push    OFFSET WindowProc   ; new parent window procedure
    push    -4                  ; nIndex = GWL_WNDPROC
    push    ebx                 ; hWnd   = main window

    call    [__imp__SetWindowLongA@12] ; install after child exists

;;;;;;;;;;;;;;;;;
;; DirtyNotify ;;
;;;;;;;;;;;;;;;;;
    push    1                          ; lParam = ENM_CHANGE
    push    edi                        ; wParam = unused
    push    445h                       ; Msg    = EM_SETEVENTMASK
    push    RichHwnd                   ; hWnd   = Rich Edit child

    call    [__imp__SendMessageA@16]   ; request text-change notifications

;;;;;;;;;;;;;;;;;
;; MessageLoop ;;
;;;;;;;;;;;;;;;;;
MessageLoop:
    push    edi                     ; wMsgFilterMax = zero
    push    edi                     ; wMsgFilterMin = zero
    push    ebx                     ; hWnd          = created window only
    push    esi                     ; lpMsg         = stack MSG structure

    call    [__imp__GetMessageA@16] ; wait for next window message

;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Message Exit Old     ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;
;;    test    eax, eax                ; zero  = quit; minus one = dead HWND
;;    jle     MessageExit             ; leave when window no longer exists

    dec     eax                     ; zero or minus one becomes negative
    jns     DispatchQueued          ; positive result = dispatch message

;;;;;;;;;;;;;;;;;
;; ProcessExit ;;
;;;;;;;;;;;;;;;;;
ProcessExit:
    push    edi                     ; dwExitCode = permanent zero register
    jmp     [__imp__ExitProcess@4]  ; terminate process without returning

;;;;;;;;;;;;;;;;;;;;;
;; CloseButton Old ;;
;;;;;;;;;;;;;;;;;;;;;
;; cmp     byte ptr [esi+4], 0A1h ; WM_NCLBUTTONDOWN?
;; jne     DispatchQueued         ; use built-in wnd proc
;; cmp     byte ptr [esi+8], 14h  ; wParam = HTCLOSE?
;; je      MessageExit            ; return directly to NT

;;;;;;;;;;;;;;;;;;;;;;;;
;; CaptionButtons Old ;;
;;;;;;;;;;;;;;;;;;;;;;;;
;; cmp     byte ptr [esi+4], 0A1h ; WM_NCLBUTTONDOWN?
;; jne     DispatchQueued         ; use built-in Static proc
;; mov     eax, [esi+8]           ; EAX = hit-test value
;; sub     al, 8                  ; min=0 max=1 close=12
;; cmp     al, 1                  ; min or max button?
;; jbe     DefaultCaption         ; let DefWindowProc act
;; cmp     al, 0Ch                ; close button?
;; jne     DispatchQueued         ; normal Static dispatch

;;;;;;;;;;;;;;;;;;;;;;;;
;; NonClientMouse Old ;;
;;;;;;;;;;;;;;;;;;;;;;;;
;; cmp     byte ptr [esi+4], 0A1h ; WM_NCLBUTTONDOWN?
;; jne     DispatchQueued         ; use built-in Static proc
                                  ; fall into DefWindowProc

;;;;;;;;;;;;;;;;;;;;;;;;
;; DefaultCaption Old ;;
;;;;;;;;;;;;;;;;;;;;;;;;
;; DefaultCaption:
;; push    dword ptr [esi+0Ch] ; lParam = screen point
;; push    dword ptr [esi+8]   ; wParam = original hit test
;; push    dword ptr [esi+4]   ; Msg    = WM_NCLBUTTONDOWN
;; push    ebx                 ; hWnd   = created window
;; call    [__imp__DefWindowProcA@16]
;; jmp     MessageLoop         ; wait for next message

;;;;;;;;;;;;;;;;;;;;
;; DispatchQueued ;;
;;;;;;;;;;;;;;;;;;;;
DispatchQueued:
    push    esi                         ; lpMsg = retrieved message
    call    [__imp__TranslateMessage@4] ; convert key press to WM_CHAR

;; push esi                             ; duplicate message dispatch
;; call [__imp__DispatchMessageA@4]     ; duplicate dispatch

    push    esi                         ; lpMsg = retrieved message
    call    [__imp__DispatchMessageA@4] ; call target window proc

    jmp     MessageLoop                 ; wait for next message

;;;;;;;;;;;;;;;;;;;;;
;; MessageExit Old ;;
;;;;;;;;;;;;;;;;;;;;;
;;MessageExit:
;;  add     esp, 1Ch    ; release stack MSG structure
;;  inc     eax         ; unused - only fixed minus one result
;;  xor eax, eax        ; returned zero from entry thread
;;  ret                 ; ended only the entry thread
;;  jmp     ProcessExit ; terminate every process thread

;;;;;;;;;;;;;;;;
;; WindowProc ;;
;;;;;;;;;;;;;;;;
WindowProc:
    mov     eax, dword ptr [esp+8]     ; EAX = callback message number
    cmp     eax, 112h                  ; WM_SYSCOMMAND message?
    je      WindowSystem               ; yes = test custom Save command
    cmp     eax, 111h                  ; WM_COMMAND notification?
    je      WindowCommand              ; yes = test Rich Edit change
    cmp     eax, 5                     ; WM_SIZE message?
    je      WindowSize                 ; yes = resize child control

;;;;;;;;;;;;;;;;;;;
;; DefaultWindow ;;
;;;;;;;;;;;;;;;;;;;
DefaultWindow:
    jmp     [__imp__DefWindowProcA@16] ; includes default WM_CLOSE handling

;;;;;;;;;;;;;;;;;
;; WindowSystem ;;
;;;;;;;;;;;;;;;;;
WindowSystem:
    cmp     dword ptr [esp+0Ch], 1000h ; custom Save command?
    je      SaveFile                   ; yes = write current editor text
    jmp     DefaultWindow              ; no = normal System Menu command

;;;;;;;;;;;;;;;;
;; WindowSize ;;
;;;;;;;;;;;;;;;;
WindowSize:
    mov     eax, [esp+10h]             ; packed client width and height
    movzx   edx, ax                    ; EDX = client width
    shr     eax, 10h                   ; EAX = client height

    push    1                          ; bRepaint = yes
    push    eax                        ; nHeight  = client height
    push    edx                        ; nWidth   = client width
    push    0                          ; Y        = top client border
    push    0                          ; X        = left client border
    push    RichHwnd                   ; hWnd     = Rich Edit child

    call    [__imp__MoveWindow@24]     ; match all client borders

;;;;;;;;;;;;;;;;
;; WindowDone ;;
;;;;;;;;;;;;;;;;
WindowDone:
    xor     eax, eax                   ; handled message result = zero
    ret     10h                        ; remove four callback arguments

;;;;;;;;;;;;;;;;;;;
;; WindowCommand ;;
;;;;;;;;;;;;;;;;;;;
WindowCommand:
    cmp     word ptr [esp+0Eh], 300h   ; HIWORD(wParam) = EN_CHANGE?
    jne     DefaultWindow              ; no = normal default behavior

;;;;;;;;;;;;;;;;;;;;
;; Dispatcher Old ;;
;;;;;;;;;;;;;;;;;;;;
;;WindowProcOld:
;;    cmp     dword ptr [esp+8], 10h     ; WM_CLOSE from X or system menu?
;;    je      ProcessExit                ; yes = terminate entire process
;;
;;    cmp     dword ptr [esp+8], 112h    ; WM_SYSCOMMAND message?
;;    jne     WindowCommand              ; no = test control notification
;;    cmp     dword ptr [esp+0Ch], 1000h ; custom Save command?
;;    je      SaveFile                   ; yes = write current editor text
;;    jmp     DefaultWindow              ; no = normal System Menu command
;;
;;WindowCommandOld:
;;    cmp     dword ptr [esp+8], 111h    ; WM_COMMAND notification?
;;    jne     WindowSize                 ; no = test WM_SIZE
;;    cmp     word ptr [esp+0Eh], 300h   ; HIWORD(wParam) = EN_CHANGE?
;;    jne     DefaultWindow              ; no = normal default behavior

    mov     eax, TitleEnd                ; clean title terminator position
    cmp     byte ptr [eax], 0            ; marker already appended?
    jne     WindowDone                   ; yes = remain dirty
    ;; change dword to word
    ;; mov dword ptr [eax], 2A20h        ; append space-star-zero
    mov     word ptr [eax], 2A20h        ; append space and star

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; DirtyTitleUpdate Old  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; push OFFSET TitleText
;; push 0
;; push 0Ch
;; push dword ptr [esp+10h]
;; call [__imp__SendMessageA@16]
;; jmp WindowDone

;;;;;;;;;;;;;;;;;
;; TitleUpdate ;;
;;;;;;;;;;;;;;;;;
TitleUpdate:
    push    OFFSET TitleText           ; lParam = current title text
    push    0                          ; wParam = unused
    push    0Ch                        ; Msg    = WM_SETTEXT
    push    dword ptr [esp+10h]        ; hWnd   = callback parent HWND

    call    [__imp__SendMessageA@16]   ; display dirty or clean title
    jmp     WindowDone                 ; title update handled

;;;;;;;;;;;;;;
;; SaveFile ;;
;;;;;;;;;;;;;;
SaveFile:
    mov     eax, FileHnd               ; EAX = retained dropped-file handle
    test    eax, eax                   ; file available for saving?
    jz      WindowDone                 ; no = ignore Save command

    push    ebp                        ; preserve callback nonvolatile EBP
    push    edi                        ; preserve callback nonvolatile EDI
    xor     edi, edi                   ; hold reliable zero during Save

    push    edi                        ; lParam = unused
    push    0                          ; wParam = unused
    push    0Eh                        ; Msg    = WM_GETTEXTLENGTH
    push    RichHwnd                   ; hWnd   = Rich Edit child

    call    [__imp__SendMessageA@16]   ; obtain current ANSI text length

    push    eax                        ; preserve length across allocation
    inc     eax                        ; include terminating zero
    push    eax                        ; dwBytes = text length plus one
    push    40h                        ; uFlags  = GPTR zeroed fixed memory

    call    [__imp__GlobalAlloc@8]     ; allocate current-text buffer

    mov     ebp, eax                   ; EBP = allocated save buffer
    pop     ecx                        ; ECX = text length without zero
    test    ebp, ebp                   ; allocation succeeded?
    jz      SaveDone                   ; no = keep dirty state

    push    ecx                        ; preserve length across WM_GETTEXT
    inc     ecx                        ; maximum chars includes terminator
    push    ebp                        ; lParam = destination buffer
    push    ecx                        ; wParam = buffer character capacity
    push    0Dh                        ; Msg    = WM_GETTEXT
    push    RichHwnd                   ; hWnd   = Rich Edit child

    call    [__imp__SendMessageA@16]   ; copy current editor text

    pop     ecx                        ; ECX = bytes to write

    push    ecx                        ; preserve length across file rewind
    push    edi                        ; dwMoveMethod = FILE_BEGIN
    push    edi                        ; lpDistanceHigh = none
    push    edi                        ; lDistanceToMove = zero
    push    FileHnd                    ; hFile = retained dropped file

    call    [__imp__SetFilePointer@16] ; rewind file to byte zero

    pop     ecx                        ; ECX = bytes to write

    sub     esp, 4                     ; reserve bytes-written result
    mov     eax, esp                   ; EAX = result DWORD address
    push    edi                        ; lpOverlapped = none
    push    eax                        ; lpNumberOfBytesWritten
    push    ecx                        ; nNumberOfBytesToWrite
    push    ebp                        ; lpBuffer = current editor text
    push    FileHnd                    ; hFile = retained dropped file

    call    [__imp__WriteFile@20]      ; replace file beginning with text

    add     esp, 4                     ; release bytes-written result
    test    eax, eax                   ; write succeeded?
    jz      SaveDone                   ; no = keep dirty state

    push    FileHnd                    ; hFile at new end position
    call    [__imp__SetEndOfFile@4]    ; remove any old trailing bytes

    test    eax, eax                   ; truncation succeeded?
    jz      SaveDone                   ; no = keep dirty state

    mov     eax, TitleEnd              ; EAX = clean title terminator
    mov     byte ptr [eax], 0          ; remove space-star dirty suffix

;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; CleanTitleUpdate Old  ;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; push OFFSET TitleText
;; push edi
;; push 0Ch
;; push dword ptr [esp+18h]
;; call [__imp__SendMessageA@16]

    pop     edi                        ; restore EDI before shared title code
    pop     ebp                        ; restore EBP and callback stack shape
    jmp     TitleUpdate                ; use shared dirty or clean refresh

SaveDone:
    pop     edi                        ; restore callback nonvolatile EDI
    pop     ebp                        ; restore callback nonvolatile EBP
    jmp     WindowDone                 ; Save command handled

;;;;;;;;;;;;;;;;;;;;;;;;;
;; Relocated Tails Old ;;
;;;;;;;;;;;;;;;;;;;;;;;;;
;;WindowSize:
;;    cmp     dword ptr [esp+8], 5       ; WM_SIZE message?
;;    jne     DefaultWindow              ; no = normal default behavior
;;
;;    mov     eax, [esp+10h]             ; packed client width and height
;;    movzx   edx, ax                    ; EDX = client width
;;    shr     eax, 10h                   ; EAX = client height
;;
;;    push    1                          ; bRepaint = yes
;;    push    eax                        ; nHeight  = client height
;;    push    edx                        ; nWidth   = client width
;;    push    0                          ; Y        = top client border
;;    push    0                          ; X        = left client border
;;    push    RichHwnd                   ; hWnd     = Rich Edit child
;;
;;    call    [__imp__MoveWindow@24]     ; match all client borders
;;
;;WindowDone:
;;    xor     eax, eax                   ; handled message result = zero
;;    ret     10h                        ; remove four callback arguments
;;
;;;;;;;;;;;;;;;;;;;;;
;;;; DefaultWindow ;;
;;;;;;;;;;;;;;;;;;;;;
;;DefaultWindow:
;;    jmp     [__imp__DefWindowProcA@16] ; default behavior and RET 16
;;
;;;;;;;;;;;;;;;;;;;
;;;; ProcessExit ;;
;;;;;;;;;;;;;;;;;;;
;;ProcessExit:
;;    xor     eax, eax                   ; dwExitCode = zero
;;    push    eax                        ; process exit code
;;    call    [__imp__ExitProcess@4]     ; terminate process and all threads

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

;;;;;;;;;;;;;;;
;; Courier   ;;
;;;;;;;;;;;;;;;
CourierFace db "Courier",0   ; shortest explicit Courier face name

;;;;;;;;;;;;;
;; SaveText ;;
;;;;;;;;;;;;;
SaveText db "Save",0          ; no ampersand and no keyboard shortcut

;;;;;;;;;;;;;;
;; RichHwnd ;;
;;;;;;;;;;;;;;
.data
RichHwnd dd 0                 ; callback-safe child HWND storage
FileHnd  dd 0                 ; retained dropped-file handle for Save
TitleText db 104h dup(0)      ; writable leaf plus space-star suffix
TitleEnd  dd OFFSET TitleText ; clean title terminator position

END WinX86Entry

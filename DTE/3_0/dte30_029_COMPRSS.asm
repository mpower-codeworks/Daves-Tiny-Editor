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

;; 000 init amd clear thread     - 372 bytes exe
;; 001 create first API window   - 404 bytes
;; 002 enable quit               - 434 bytes
;; 003 enable X to quit          - 445 bytes
;; 004 enable min and max        - 472 bytes
;; 005 enable mouse resize       - 459 bytes
;; 006 true mouse resize         - 451 bytes
;; 007 start size 800x600        - 455 bytes
;; 008 add RichEdit20W           - 491 bytes
;; 009 resize RichEdit20W        - 533 bytes
;; 010 add keys/mouse handlers   - 536 bytes
;; 011 add Courier font          - 566 bytes
;; 012 Courier 14 point          - 568 bytes
;; 013 fix runaway process       - 575 bytes
;; 014 enable vertical scroll    - 576 bytes
;; 015 auto vertical scroll      - 587 bytes
;; 016 drop file onto EXE        - 709 bytes
;; 017 leaf filename title       - 725 bytes
;; 018 dirty title marker        - 791 bytes
;; 019 system menu save          - 908 bytes
;; 020 rmv REDIT initial fit     - 901 bytes
;; 021 merge path loops          - 895 bytes
;; 022 share title update        - 895 bytes
;; 023 reorg dispatch and exit   - 880 bytes
;; 024 dispatch exit reorganize  - 875 bytes
;; 025 review for leaks, errors  - 875 bytes
;; 026 fix REDIT capacity        - 881 bytes
;; 027 direct file streaming     - 838 bytes
;; 028 minor changes             - 838 bytes
;; 029 crinkler-aware rewrite    - 806 bytes

;;;;;;;;;;;;;;;;;;;
;; initial setup ;;
;;;;;;;;;;;;;;;;;;;

.386                                    ; enable 80386 instrctns
                                        ; and 32-bit rgistrs
.model flat                             ; use 32-bit flat memory model
option casemap:none                     ; preserve symbol case
                                        ; exactly as written

;;;;;;;;;;;;;;;;
;; API import ;;
;;;;;;;;;;;;;;;;
EXTERN __imp__CreateWindowExA@48:DWORD  ; create predefined API window
EXTERN __imp__GetMessageA@16    :DWORD  ; wait for one queued window msg
EXTERN __imp__DispatchMessageA@4:DWORD  ; send msg to built-in wnd proc
EXTERN __imp__DefWindowProcA@16 :DWORD  ; use default top-level wnd proc
EXTERN __imp__SetWindowLongA@12 :DWORD  ; replace Static window proc
EXTERN __imp__LoadLibraryA@4    :DWORD  ; load Rich Edit class DLL
EXTERN __imp__MoveWindow@24     :DWORD  ; fit Rich Edit to client
EXTERN __imp__TranslateMessage@4:DWORD  ; convert keys into characters
EXTERN __imp__SendMessageA@16   :DWORD  ; send font to Rich Edit
EXTERN __imp__CreateFontA@56    :DWORD  ; create Courier font
EXTERN __imp__ExitProcess@4     :DWORD  ; terminate entire process
EXTERN __imp__GetCommandLineA@0 :DWORD  ; obtain dropped file path
EXTERN __imp__CreateFileA@28    :DWORD  ; open dropped text file
EXTERN __imp__ReadFile@20       :DWORD  ; read dropped text file
EXTERN __imp__GetSystemMenu@8   :DWORD  ; obtain main System Menu
EXTERN __imp__AppendMenuA@16    :DWORD  ; append Save menu command
EXTERN __imp__SetFilePointer@16 :DWORD  ; rewind file before saving
EXTERN __imp__WriteFile@20      :DWORD  ; write current editor text
EXTERN __imp__SetEndOfFile@4    :DWORD  ; truncate old file remainder

.code                                   ; executable machine-code section

;;;;;;;;;;;;;;;;;
;; WinX86Entry ;;
;;;;;;;;;;;;;;;;;
WinX86Entry:
    call    [__imp__GetCommandLineA@0]  ; full process command line
    xchg    esi, eax                    ; ESI = command-line cursor

    mov     ebp, OFFSET TitleText       ; EBP = writable dropped path
    mov     edi, ebp                    ; EDI = path copy destination
    mov     edx, ebp                    ; EDX = filename leaf in path
    mov     cl,  20h                    ; plain argument ends at space
    lodsb                               ; consume first executable byte
    cmp     al, 22h                     ; quoted executable path?
    jne     DropExeScan                 ; no = scan for separating space
    mov     cl, al                      ; yes = quote becomes delimiter

DropExeScan:
    lodsb                               ; load next executable byte
    test    al, al                      ; command line ended?
    je      DropReady                   ; yes = no dropped file
    cmp     al, cl                      ; executable delimiter found?
    jne     DropExeScan                 ; no = continue scanning

DropSkip:
    lodsb                               ; load byte after delimiter
    cmp     al, 20h                     ; another separating space?
    je      DropSkip                    ; yes = skip it
    test    al, al                      ; file argument present?
    je      DropReady                   ; no = open empty editor

    mov     cl, 20h                     ; plain file ends at space
    cmp     al, 22h                     ; quoted dropped path?
    jne     DropStore                   ; no = retain first path byte
    mov     cl, al                      ; yes = quote becomes delimiter
    jmp     DropEnd                     ; skip opening file quote

DropStore:
    stosb                               ; copy byte into writable path
    cmp     al, 5Ch                     ; Windows path separator?
    jne     DropEnd                     ; no = continue path scan

    mov     edx, edi                    ; EDX = byte after last backslash

DropEnd:
    lodsb                               ; load next path byte
    test    al, al                      ; command line ended?
    je      DropReady                   ; yes = zeroed buffer ends path
    cmp     al, cl                      ; argument delimiter found?
    jne     DropStore                   ; no = copy path byte

DropReady:
    mov     eax, OFFSET FileHnd         ; EAX = callback-safe state
    mov     dword ptr [eax+10h], edx    ; retain filename title pointer
    mov     dword ptr [eax+14h], edi    ; retain clean title terminator
    xor     edi, edi                    ; keep permanent zero in EDI

    push    edi                         ; lpParam      = no creation data
    push    edi                         ; hInstance    = USER32 class is global
    push    edi                         ; hMenu        = no menu
    push    edi                         ; hWndParent   = make top-level window
    push    258h                        ; nHeight      = 600 px
    push    320h                        ; nWidth       = 800 px
    push    edi                         ; Y            = zero
    push    edi                         ; X            = zero
    push    10CF0000h                   ; style        = overlapped wndw
    push    edx                         ; lpWindowName = fname leaf or empty
    push    OFFSET StaticClass          ; lpClassName  = USER32 Static
    push    edi                         ; dwExStyle    = none

    call    [__imp__CreateWindowExA@48] ; create first HWND

    xchg    ebx, eax                    ; keep HWND in callee-saved EBX
    sub     esp, 1Ch                    ; reserve one 28-byte MSG structure
    mov     esi, esp                    ; keep MSG in callee-saved ESI

;;;;;;;;;;;;;;;;;;
;; SystemMenu   ;;
;;;;;;;;;;;;;;;;;;
    push    edi                         ; bRevert = false
    push    ebx                         ; hWnd    = main window
    call    [__imp__GetSystemMenu@8]    ; obtain existing System Menu
    push    OFFSET SaveText             ; lpNewItem = plain Save text
    push    10h                         ; uIDNewItem = custom Save command
    push    edi                         ; uFlags     = MF_STRING
    push    eax                         ; hMenu      = System Menu
    call    [__imp__AppendMenuA@16]     ; append Save at menu bottom

;;;;;;;;;;;;;;;;;;
;; LoadRichEdit ;;
;;;;;;;;;;;;;;;;;;
    push    OFFSET RichDll              ; lpLibFileName = Riched20.dll
    call    [__imp__LoadLibraryA@4]     ; register RichEdit20W class

;;;;;;;;;;;;;;;;;
;; RichEdit20W ;;
;;;;;;;;;;;;;;;;;    
    push    edi                         ; lpParam      = no creation data
    push    edi                         ; hInstance    = no lcal class instnce
    push    edi                         ; hMenu        = no child ID
    push    ebx                         ; hWndParent   = main window
    push    231h                        ; nHeight      = 600px frame clnt area
    push    310h                        ; nWidth       = 800px frame clnt area
    push    edi                         ; Y            = zero
    push    edi                         ; X            = zero
    push    50200044h                   ; show bar only when text overflows
    push    edi                         ; lpWindowName = no initial text
    push    OFFSET RichClass            ; lpClassName  = RichEdit20W
    push    edi                         ; dwExStyle    = none
    call    [__imp__CreateWindowExA@48] ; create first Rich Edit control
    mov     RichHwnd, eax               ; retain callback-safe child HWND
    xchg    ebp, eax                    ; keep Rich Edit HWND in EBP

;;;;;;;;;;;;;
;; Courier ;;
;;;;;;;;;;;;;
    push    OFFSET CourierFace          ; lpszFace = Courier
    push    0Ch                         ; twelve remaining zero arguments
    pop     ecx                         ; ECX = compact zero-push counter

CourierZeros:
    push    edi                         ; push one zero CreateFont argument
    loop    CourierZeros                ; repeat for twelve zero arguments

    push    -19                         ; nHeight = 14 points at normal 96 DPI
    call    [__imp__CreateFontA@56]     ; create 14-point Courier HFONT

    push    edi                         ; lParam = no immediate redraw needed
    push    eax                         ; wParam = new Courier HFONT
    push    30h                         ; Msg    = WM_SETFONT
    push    ebp                         ; hWnd   = Rich Edit child

    call    [__imp__SendMessageA@16]    ; apply Courier to Rich Edit

;;;;;;;;;;;;;;;;;
;; GrowthLimit ;;
;;;;;;;;;;;;;;;;;
    push    -1                          ; lParam = maximum text limit
    push    edi                         ; wParam = reserved zero
    push    435h                        ; Msg    = EM_EXLIMITTEXT
    push    ebp                         ; hWnd   = Rich Edit child

    call    [__imp__SendMessageA@16]    ; remove default 32767-char limit

;;;;;;;;;;;;;;
;; DropOpen ;;
;;;;;;;;;;;;;;
DropOpen:
    push    edi                         ; hTemplateFile = none
    push    edi                         ; flags         = default
    push    3                           ; creation      = OPEN_EXISTING
    push    edi                         ; security      = none
    push    7                           ; share read write and delete
    push    0C0000000h                  ; access = GENERIC_READ or WRITE
    push    OFFSET TitleText            ; lpFileName = writable dropped path

    call    [__imp__CreateFileA@28]     ; open dropped text file

    inc     eax                         ; INVALID_HANDLE_VALUE becomes zero
    jz      ResizeProc                  ; open failed = leave editor empty
    dec     eax                         ; restore valid file handle
    mov     edx, OFFSET FileHnd         ; EDX = EDITSTREAM structure
    mov     dword ptr [edx], eax        ; dwCookie = retained file handle
    mov     dword ptr [edx+8], OFFSET ReadCallback

    push    edx                         ; preserve EDITSTREAM address
    push    edx                         ; lParam = EDITSTREAM structure
    push    1                           ; wParam = SF_TEXT
    push    449h                        ; Msg    = EM_STREAMIN
    push    ebp                         ; hWnd   = Rich Edit child

    call    [__imp__SendMessageA@16]    ; stream file directly into editor

    pop     edx                         ; restore EDITSTREAM address
    add     dword ptr [edx+8], 7        ; select adjacent WriteCallback

;;;;;;;;;;;;;;;;
;; ResizeProc ;;
;;;;;;;;;;;;;;;;
ResizeProc:
    push    OFFSET WindowProc           ; new parent window procedure
    push    -4                          ; nIndex = GWL_WNDPROC
    push    ebx                         ; hWnd   = main window
    call    [__imp__SetWindowLongA@12]  ; install after child exists

;;;;;;;;;;;;;;;;;
;; DirtyNotify ;;
;;;;;;;;;;;;;;;;;
    push    1                           ; lParam = ENM_CHANGE
    push    edi                         ; wParam = unused
    push    445h                        ; Msg    = EM_SETEVENTMASK
    push    ebp                         ; hWnd   = Rich Edit child

    call    [__imp__SendMessageA@16]    ; request text-change notifications

;;;;;;;;;;;;;;;;;
;; MessageLoop ;;
;;;;;;;;;;;;;;;;;
MessageLoop:
    push    edi                         ; wMsgFilterMax = zero
    push    edi                         ; wMsgFilterMin = zero
    push    ebx                         ; hWnd          = created window only
    push    esi                         ; lpMsg         = stack MSG structure

    call    [__imp__GetMessageA@16]     ; wait for next window message
    dec     eax                         ; zero or minus one becomes negative
    jns     DispatchQueued              ; positive result = dispatch message

;;;;;;;;;;;;;;;;;
;; ProcessExit ;;
;;;;;;;;;;;;;;;;;
ProcessExit:
    push    edi                         ; dwExitCode = permanent zero register
    jmp     [__imp__ExitProcess@4]      ; terminate process without returning

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

;;;;;;;;;;;;;;;;
;; WindowProc ;;
;;;;;;;;;;;;;;;;
WindowProc:
    mov     al, byte ptr [esp+8]        ; AL = low callback message byte
    sub     al, 5                       ; WM_SIZE message?
    je      WindowSize                  ; yes = resize child control
    sub     al, 0Ch                     ; WM_COMMAND message?
    je      WindowCommand               ; yes = test Rich Edit change
    dec     al                          ; WM_SYSCOMMAND message?
    je      WindowSystem                ; yes = test custom Save command

;;;;;;;;;;;;;;;;;;;
;; DefaultWindow ;;
;;;;;;;;;;;;;;;;;;;
DefaultWindow:
    jmp     [__imp__DefWindowProcA@16]  ; includes default WM_CLOSE handling

;;;;;;;;;;;;;;;;
;; WindowSize ;;
;;;;;;;;;;;;;;;;
WindowSize:
    movzx   edx, word ptr [esp+10h]     ; EDX = client width
    movzx   eax, word ptr [esp+12h]     ; EAX = client height

    push    1                           ; bRepaint = yes
    push    eax                         ; nHeight  = client height
    push    edx                         ; nWidth   = client width
    push    0                           ; Y        = top client border
    push    0                           ; X        = left client border
    push    RichHwnd                    ; hWnd     = Rich Edit child

    call    [__imp__MoveWindow@24]      ; match all client borders

;;;;;;;;;;;;;;;;
;; WindowDone ;;
;;;;;;;;;;;;;;;;
WindowDone:
    xor     eax, eax                    ; handled message result = zero
    ret     10h                         ; remove four callback arguments

;;;;;;;;;;;;;;;;;;;
;; WindowCommand ;;
;;;;;;;;;;;;;;;;;;;
WindowCommand:
                                        ; Rich Edit is the WM_COMMAND srce
    mov     eax, TitleEnd               ; clean title terminator position
    mov     word ptr [eax], 2A20h       ; append space and star

;;;;;;;;;;;;;;;;;
;; TitleUpdate ;;
;;;;;;;;;;;;;;;;;
TitleUpdate:
    push    TitleStart                  ; lParam = filename leaf title
    push    0                           ; wParam = unused
    push    0Ch                         ; Msg    = WM_SETTEXT
    push    dword ptr [esp+10h]         ; hWnd   = callback parent HWND

    call    [__imp__SendMessageA@16]    ; display dirty or clean title
    jmp     WindowDone                  ; title update handled

;;;;;;;;;;;;;;;;;;
;; WindowSystem ;;
;;;;;;;;;;;;;;;;;;
WindowSystem:
    cmp     dword ptr [esp+0Ch], 10h    ; custom Save command?
    jne     DefaultWindow               ; no = normal System Menu command

;;;;;;;;;;;;;;
;; SaveFile ;;
;;;;;;;;;;;;;;
SaveFile:
    push    esi                         ; preserve callback nonvolatile ESI
    mov     esi, OFFSET FileHnd         ; ESI = EDITSTREAM structure
    mov     eax, dword ptr [esi]        ; EAX = retained dropped-file handle
    test    eax, eax                    ; file available for saving?
    jz      SaveDone                    ; no = ignore Save command

    xor     ecx, ecx                    ; ECX = compact Save zero
    mov     dword ptr [esi+4], ecx      ; dwError = no stream error
    push    ecx                         ; dwMoveMethod = FILE_BEGIN
    push    ecx                         ; lpDistanceHigh = none
    push    ecx                         ; lDistanceToMove = zero
    push    eax                         ; hFile = retained dropped file

    call    [__imp__SetFilePointer@16]  ; rewind file to byte zero

    push    esi                         ; lParam = EDITSTREAM structure
    push    1                           ; wParam = SF_TEXT
    push    44Ah                        ; Msg    = EM_STREAMOUT
    push    dword ptr [esi+0Ch]         ; hWnd   = Rich Edit child

    call    [__imp__SendMessageA@16]    ; stream editor directly into file

    cmp     dword ptr [esi+4], 0        ; stream completed without error?
    jne     SaveDone                    ; no = keep dirty state

    push    dword ptr [esi]             ; hFile at new end position
    call    [__imp__SetEndOfFile@4]     ; remove any old trailing bytes

    mov     eax, dword ptr [esi+14h]    ; EAX = clean title terminator
    mov     byte ptr [eax], 0           ; remove space-star dirty suffix

    pop     esi                         ; restore callback nonvolatile ESI
    jmp     TitleUpdate                 ; use shared dirty or clean refresh

SaveDone:
    pop     esi                         ; restore callback nonvolatile ESI
    jmp     WindowDone                  ; share handled-message return

;;;;;;;;;;;;;;;;;;
;; ReadCallback ;;
;;;;;;;;;;;;;;;;;;
ReadCallback:
    mov     eax, dword ptr [__imp__ReadFile@20]
    jmp     StreamCallback              ; share identical API arguments

;;;;;;;;;;;;;;;;;;;
;; WriteCallback ;;
;;;;;;;;;;;;;;;;;;;
WriteCallback:
    mov     eax, dword ptr [__imp__WriteFile@20]

;;;;;;;;;;;;;;;;;;;;
;; StreamCallback ;;
;;;;;;;;;;;;;;;;;;;;
StreamCallback:
    mov     edx, esp                    ; EDX = callback argument base
    push    0                           ; lpOverlapped = none
    push    dword ptr [edx+10h]         ; lpNumberOfBytesRead or Written
    push    dword ptr [edx+0Ch]         ; nNumberOfBytesToRead or Write
    push    dword ptr [edx+8]           ; lpBuffer
    push    dword ptr [edx+4]           ; hFile = dwCookie

    call    eax                         ; call ReadFile or WriteFile

    dec     eax                         ; TRUE = success zero, FALSE = error
    ret     10h                         ; remove four callback arguments

;;;;;;;;;;;;;;;;;
;; StaticClass ;;
;;;;;;;;;;;;;;;;;
StaticClass db "Static",0               ; ANSI saves bytes and
                                        ; needs no registration

;;;;;;;;;;;;;
;; RichDll ;;
;;;;;;;;;;;;;
RichDll     db "Riched20",0             ; loader appends default
                                        ; .DLL extension

;;;;;;;;;;;;;;;
;; RichClass ;;
;;;;;;;;;;;;;;;
RichClass   db "RichEdit20W",0          ; Unicode Rich Edit
                                        ; 2 or 3 class

;;;;;;;;;;;;;
;; Courier ;;
;;;;;;;;;;;;;
CourierFace db "Courier",0              ; shortest explicit
                                        ; Courier face name

;;;;;;;;;;;;;;
;; SaveText ;;
;;;;;;;;;;;;;;
SaveText    db "Save",0                 ; no ampersand and no
                                        ; keyboard shortcut -
                                        ; maybe add it later
;;;;;;;;;;;
;; State ;;
;;;;;;;;;;;
.data?
FileHnd     dd ?                        ; EDITSTREAM cookie/retained file
StreamError dd ?                        ; EDITSTREAM transfer result
StreamProc  dd ?                        ; EDITSTREAM callback procedure
RichHwnd    dd ?                        ; callback-safe Rich Edit HWND
TitleStart  dd ?                        ; filename leaf title pointer
TitleEnd    dd ?                        ; clean title terminator pointer
TitleText   db 106h dup(?)              ; loader-zeroed pth/title workspace

END WinX86Entry

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
;; 030 fix fdirty on click       - 805 bytes
;; 031 opt prsr, addr, data      - 794 bytes
;; 032 add new file ability      - 797 bytes
;; 033 add search ability        - 859 bytes
;; 034 add search wrap           - 863 bytes
;; 035 fixed clean exit (again!) - 864 bytes
;; 036 fixed client-click crash  - 864 bytes
;; 037 added F9 save command     - 885 bytes
;; 038 add dirty file protection - 908 bytes
;; 039 add print from WINEXEC    - 965 bytes
;; 040 add reverse search        - 994 bytes
;; 041 re-org for better cmprss  - 990 bytes
;; 042 external font patch tail  - 988 bytes
;; 043 and 044 crinkler fold     - 980 bytes
;; 045 15-byte font face slot    - 980 bytes

;;;;;;;;;;;;;;;;;;;
;; initial setup ;;
;;;;;;;;;;;;;;;;;;;

.686                                    ; enable compact CMOV instructions
                                        ; and 32-bit registers
.model flat                             ; use 32-bit flat memory model
option casemap:none                     ; preserve symbol case
                                        ; exactly as written

;;;;;;;;;;;;;;;;;;;;
;; patchable font ;;
;;;;;;;;;;;;;;;;;;;;
FONT_FACE_ADDR   EQU 4003E8h             ; file offset 1000 in mapped image
FONT_HEIGHT_ADDR EQU 4003F7h             ; file offset 1015 signed height
                                         ; font face occupies bytes 1000-1014
                                         ; bytes 1019-1023 remain available

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
EXTERN __imp__CreateFontA@56    :DWORD  ; create configured font
EXTERN __imp__ExitProcess@4     :DWORD  ; terminate entire process
EXTERN __imp__WinExec@8         :DWORD  ; launch Notepad print command
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
    push    edi                         ; copy initial path destination
    pop     edx                         ; EDX = filename leaf in path
    mov     al, 'f'                     ; default unnamed file = f
    stosb                               ; store name and advance title end
    mov     cl,  20h                    ; plain argument ends at space
    lodsb                               ; consume first executable byte
    cmp     al, 22h                     ; quoted executable path?
    cmove   ecx, eax                    ; yes = quote becomes delimiter

DropExeScan:
    lodsb                               ; load next executable byte
    or      al, al                      ; command line ended?
    je      DropReady                   ; yes = no dropped file
    cmp     al, cl                      ; executable delimiter found?
    jne     DropExeScan                 ; no = continue scanning

DropSkip:
    lodsb                               ; load byte after delimiter
    cmp     al, 20h                     ; another separating space?
    je      DropSkip                    ; yes = skip it
    jb      DropReady                   ; control/NUL = open empty editor
    mov     edi, ebp                    ; real path replaces default s

    mov     cl, 20h                     ; plain file ends at space
    cmp     al, 22h                     ; quoted dropped path?
    cmove   ecx, eax                    ; yes = quote becomes delimiter
    je      DropEnd                     ; skip opening file quote

DropStore:
    stosb                               ; copy byte into writable path
    cmp     al, 5Ch                     ; Windows path separator?
    cmove   edx, edi                    ; retain byte after last backslash

DropEnd:
    lodsb                               ; load next path byte
    or      al, al                      ; command line ended?
    je      DropReady                   ; yes = zeroed buffer ends path
    cmp     al, cl                      ; argument delimiter found?
    jne     DropStore                   ; no = copy path byte

DropReady:
    mov     dword ptr [ebp-14h], edx    ; retain filename title pointer
    mov     dword ptr [ebp-10h], edi    ; retain clean title terminator
    xor     edi, edi                    ; keep permanent zero in EDI
    mov     esi, OFFSET __imp__CreateWindowExA@48
                                        ; share compact CreateWindow IAT slot

    push    edi                         ; lpParam      = no creation data
    push    edi                         ; hInstance    = USER32 class is global
    push    edi                         ; hMenu        = no menu
    push    edi                         ; hWndParent   = make top-level window
    push    258h                        ; nHeight      = 600 px
    push    320h                        ; nWidth       = 800 px
    push    edi                         ; Y            = zero
    push    edi                         ; X            = zero
    push    10CF0000h                   ; style        = overlapped wndw
    push    edx                         ; lpWindowName = filename leaf or empty
    push    OFFSET StaticClass          ; lpClassName  = USER32 Static
    push    edi                         ; dwExStyle    = none

    call    dword ptr [esi]             ; create first HWND

    xchg    ebx, eax                    ; keep parent HWND in EBX

;;;;;;;;;;;;;;;;;;
;; LoadRichEdit ;;
;;;;;;;;;;;;;;;;;;
    push    OFFSET RichDll              ; lpLibFileName = Riched20.dll
    call    [__imp__LoadLibraryA@4]     ; register RichEdit20W class

;;;;;;;;;;;;;;;;;
;; RichEdit20W ;;
;;;;;;;;;;;;;;;;;
    push    edi                         ; lpParam      = no creation data
    push    edi                         ; hInstance    = no local class instance
    push    edi                         ; hMenu        = no child ID
    push    ebx                         ; hWndParent   = main window
    push    231h                        ; nHeight      = 600px client area
    push    310h                        ; nWidth       = 800px client area
    push    edi                         ; Y            = zero
    push    edi                         ; X            = zero
    push    50200044h                   ; show bar only when text overflows
    push    edi                         ; lpWindowName = no initial text
    push    OFFSET RichClass            ; lpClassName  = RichEdit20W
    push    edi                         ; dwExStyle    = none

    call    dword ptr [esi]             ; create first Rich Edit control

    mov     dword ptr [ebp-18h], eax    ; retain callback-safe child HWND
    xchg    ebp, eax                    ; keep Rich Edit HWND in EBP

;;;;;;;;;;;;;;;;
;; SystemMenu ;;
;;;;;;;;;;;;;;;;
    push    edi                         ; bRevert = false
    push    ebx                         ; hWnd    = main window
    call    [__imp__GetSystemMenu@8]    ; obtain existing System Menu

    push    OFFSET ExitText             ; second lpNewItem = X!
    push    51h                         ; second uIDNewItem
    push    edi                         ; second uFlags = MF_STRING
    push    eax                         ; second hMenu
    push    OFFSET SaveText             ; first lpNewItem = Save
    push    50h                         ; first uIDNewItem
    push    edi                         ; first uFlags = MF_STRING
    push    eax                         ; first hMenu

    mov     esi, OFFSET __imp__AppendMenuA@16
                                        ; share compact AppendMenu IAT slot
    call    dword ptr [esi]             ; append Save and expose X! frame
    call    dword ptr [esi]             ; append X! below Save

    push    ebx                         ; retain parent above MSG workspace
    sub     esp, 7Fh                    ; MSG plus short find-text buffer
    mov     esi, esp                    ; keep MSG in callee-saved ESI
    mov     ebx, OFFSET __imp__SendMessageA@16
                                        ; compact SendMessage IAT slot

;;;;;;;;;;;;;;;;;;
;; PatchableFont ;;
;;;;;;;;;;;;;;;;;;
    mov     eax, FONT_FACE_ADDR          ; base of external patch tail
    push    eax                          ; lpszFace = configured font name
    push    0Ch                          ; twelve remaining zero arguments
    pop     ecx                          ; ECX = compact zero-push counter

FontZeros:
    push    edi                          ; push one zero CreateFont argument
    loop    FontZeros                    ; repeat for twelve zero arguments

    push    dword ptr [eax+0Fh]          ; nHeight follows 15-byte face slot
    call    [__imp__CreateFontA@56]      ; create configured HFONT

    push    edi                          ; lParam = no immediate redraw needed
    push    eax                          ; wParam = configured HFONT
    push    30h                          ; Msg    = WM_SETFONT
    push    ebp                          ; hWnd   = Rich Edit child

    call    dword ptr [ebx]              ; apply font to RICHEDIT

;;;;;;;;;;;;;;;;;
;; GrowthLimit ;;
;;;;;;;;;;;;;;;;;
    push    -1                          ; lParam = maximum text limit
    push    edi                         ; wParam = reserved zero
    push    435h                        ; Msg    = EM_EXLIMITTEXT
    push    ebp                         ; hWnd   = Rich Edit child

    call    dword ptr [ebx]             ; remove default 32767-char limit

;;;;;;;;;;;;;;
;; DropOpen ;;
;;;;;;;;;;;;;;
DropOpen:
    push    edi                         ; hTemplateFile = none
    push    edi                         ; flags         = default
    push    4                           ; creation      = OPEN_ALWAYS
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

    call    dword ptr [ebx]             ; stream file directly into editor

    pop     edx                         ; restore EDITSTREAM address
    add     dword ptr [edx+8], 7        ; select adjacent WriteCallback

;;;;;;;;;;;;;;;;
;; ResizeProc ;;
;;;;;;;;;;;;;;;;
ResizeProc:
    push    OFFSET WindowProc           ; new parent window procedure
    push    -4                          ; nIndex = GWL_WNDPROC
    push    dword ptr [esi+7Fh]         ; hWnd   = retained main window
    call    [__imp__SetWindowLongA@12]  ; install after child exists

;;;;;;;;;;;;;;;;;
;; DirtyNotify ;;
;;;;;;;;;;;;;;;;;
    push    1                           ; lParam = ENM_CHANGE
    push    edi                         ; wParam = unused
    push    445h                        ; Msg    = EM_SETEVENTMASK
    push    ebp                         ; hWnd   = Rich Edit child

    call    dword ptr [ebx]             ; request text-change notifications

;;;;;;;;;;;;;;;;;
;; MessageLoop ;;
;;;;;;;;;;;;;;;;;
MessageLoop:
    push    edi                         ; wMsgFilterMax = zero
    push    edi                         ; wMsgFilterMin = zero
    push    edi                         ; hWnd          = all thread windows
    push    esi                         ; lpMsg         = stack MSG structure

    call    [__imp__GetMessageA@16]     ; wait for next window message
    dec     eax                         ; zero or minus one becomes negative
    js      ProcessExit                 ; zero or error = terminate process

;;;;;;;;;;;;;;;;;;;;
;; DispatchQueued ;;
;;;;;;;;;;;;;;;;;;;;
DispatchQueued:
    cmp     word ptr [esi+4], 100h      ; WM_KEYDOWN message?
    jne     DispatchNormal              ; no = normal message handling
    mov     al, byte ptr [esi+8]        ; AL = virtual-key code
    sub     al, 71h                     ; F2 becomes zero, F3 becomes one
    cmp     al, 1
    jbe     FindNext                    ; F2/F3 share search machinery
    cmp     al, 7                       ; original VK_F9?
    je      SaveKey
    cmp     al, 0Ah                     ; original VK_F12?
    je      PrintKey

DispatchNormal:
    push    esi                         ; lpMsg = retrieved message
    call    [__imp__TranslateMessage@4] ; convert key press to WM_CHAR

    push    esi                         ; lpMsg = retrieved message
    call    [__imp__DispatchMessageA@4] ; call target window proc

    jmp     MessageLoop                 ; wait for next message

;;;;;;;;;;;;;
;; SaveKey ;;
;;;;;;;;;;;;;
SaveKey:
    push    edi                         ; lParam = zero
    push    50h                         ; wParam = existing Save command
    push    112h                        ; Msg    = WM_SYSCOMMAND
    push    dword ptr [esi+7Fh]         ; hWnd   = retained parent window
    call    dword ptr [ebx]             ; reuse System Menu Save path
    jmp     MessageLoop                 ; swallow F9 and wait for next msg

;;;;;;;;;;;;;;
;; PrintKey ;;
;;;;;;;;;;;;;;
PrintKey:
    mov     eax, TitleEnd               ; EAX = clean title terminator
    cmp     byte ptr [eax], 0           ; unsaved changes present?
    jne     MessageLoop                 ; yes = refuse F12 print

    push    esi                         ; preserve MSG workspace pointer
    mov     esi, OFFSET PrintPrefix     ; ESI = fixed Notepad print prefix
    mov     edi, OFFSET PrintCmd        ; prefix sits directly before pathname
    movsd                               ; copy first four prefix bytes
    movsd                               ; copy second four prefix bytes
    movsd                               ; copy final four prefix bytes

    mov     word ptr [eax], 22h         ; temporary quote plus trailing NUL
    xchg    esi, eax                    ; ESI = clean title terminator
    xor     edi, edi                    ; restore permanent zero register
    push    edi                         ; uCmdShow = SW_HIDE
    push    OFFSET PrintCmd             ; prefix followed by existing pathname
    call    [__imp__WinExec@8]          ; Notepad prints default printer
    mov     byte ptr [esi], 0           ; remove temporary closing quote
    pop     esi                         ; restore MSG workspace pointer
    jmp     MessageLoop                 ; swallow F12 and continue

;;;;;;;;;;;;;;
;; FindNext ;;
;;;;;;;;;;;;;;
FindNext:
    push    esi                         ; lParam = CHARRANGE in MSG workspace
    push    edi                         ; wParam = unused zero
    push    434h                        ; Msg    = EM_EXGETSEL
    push    ebp                         ; hWnd   = Rich Edit child
    call    dword ptr [ebx]             ; get current selection range

    mov     eax, dword ptr [esi+4]      ; EAX = selection end
    sub     eax, dword ptr [esi]        ; EAX = selected text length
    jz      FindDone                    ; nothing selected = do nothing
    cmp     eax, 62h                    ; fit 98 chars plus terminator?
    ja      FindDone                    ; no = ignore oversized selection

    cmp     byte ptr [esi+8], 71h       ; F2 backward search?
    je      FindBackward                ; yes = keep selection start in cpMin

    add     eax, dword ptr [esi]        ; length + start = selection end
    mov     dword ptr [esi], eax          ; F3 starts after selection
    or      dword ptr [esi+4], -1       ; forward range ends at document end
    jmp     FindText

FindBackward:
    mov     dword ptr [esi+4], edi      ; backward range ends at document start

FindText:
    lea     eax, [esi+1Ch]              ; reuse spare stack as search text
    mov     dword ptr [esi+8], eax      ; keep text pointer for FINDTEXTEX
    push    eax                         ; lParam = search text buffer
    push    edi                         ; wParam = unused zero
    push    43Eh                        ; Msg    = EM_GETSELTEXT
    push    ebp                         ; hWnd   = Rich Edit child
    call    dword ptr [ebx]             ; copy highlighted search word

FindSearch:
    mov     eax, dword ptr [esi+4]      ; -1 forward, zero backward
    neg     eax                         ; convert range marker to FR_DOWN flag
    push    esi                         ; lParam = FINDTEXTEX workspace
    push    eax                         ; wParam = FR_DOWN or zero
    push    44Fh                        ; Msg    = EM_FINDTEXTEX
    push    ebp                         ; hWnd   = Rich Edit child
    call    dword ptr [ebx]             ; let Rich Edit perform search

    inc     eax                         ; -1 not-found becomes zero
    jnz     FindFound                   ; match = select it

    cmp     dword ptr [esi+4], edi      ; backward search?
    je      FindBackWrap                ; yes = wrap from document end
    mov     dword ptr [esi], edi        ; forward wrap starts at document start
    jmp     FindSearch

FindBackWrap:
    push    edi                         ; lParam = zero
    push    edi                         ; wParam = zero
    push    0Eh                         ; Msg    = WM_GETTEXTLENGTH
    push    ebp                         ; hWnd   = Rich Edit child
    call    dword ptr [ebx]             ; obtain document end for backward wrap
    mov     dword ptr [esi], eax        ; backward wrap starts at document end
    jmp     FindSearch

FindFound:
    lea     eax, [esi+0Ch]              ; found CHARRANGE in FINDTEXTEX
    push    eax                         ; lParam = found character range
    push    edi                         ; wParam = unused zero
    push    437h                        ; Msg    = EM_EXSETSEL
    push    ebp                         ; hWnd   = Rich Edit child
    call    dword ptr [ebx]             ; select and reveal next match

FindDone:
    jmp     MessageLoop                 ; swallow F3 and wait for next msg

;;;;;;;;;;;;;;;;;
;; ProcessExit ;;
;;;;;;;;;;;;;;;;;
ProcessExit:
    push    edi                         ; dwExitCode = permanent zero register
    jmp     [__imp__ExitProcess@4]      ; terminate process without returning

;;;;;;;;;;;;;;;;
;; WindowProc ;;
;;;;;;;;;;;;;;;;
WindowProc:
    mov     eax, dword ptr [esp+8]      ; EAX = callback message value
    push    esi                         ; preserve callback nonvolatile ESI
    mov     esi, OFFSET FileHnd         ; ESI = shared DTE state base
    cmp     eax, 10h                    ; WM_CLOSE message?
    jne     WindowNotClose              ; no = test other parent messages
    mov     eax, dword ptr [esi+14h]    ; EAX = clean title terminator
    cmp     byte ptr [eax], 0           ; dirty suffix present?
    jne     WindowDone                  ; yes = disable normal Close / X
    jmp     ProcessExit                 ; clean = close normally

WindowNotClose:
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
    pop     esi                         ; restore callback nonvolatile ESI
    jmp     [__imp__DefWindowProcA@16]  ; handle unclaimed window messages

;;;;;;;;;;;;;;;;
;; WindowSize ;;
;;;;;;;;;;;;;;;;
WindowSize:
    mov     eax, dword ptr [esp+14h]    ; packed client width and height
    movzx   edx, ax                     ; EDX = unsigned client width
    shr     eax, 16                     ; EAX = unsigned client height

    push    1                           ; bRepaint = yes
    push    eax                         ; nHeight  = client height
    push    edx                         ; nWidth   = client width
    push    0                           ; Y        = top client border
    push    0                           ; X        = left client border
    push    dword ptr [esi+0Ch]         ; hWnd     = Rich Edit child

    call    [__imp__MoveWindow@24]      ; match all client borders

;;;;;;;;;;;;;;;;
;; WindowDone ;;
;;;;;;;;;;;;;;;;
WindowDone:
    pop     esi                         ; restore callback nonvolatile ESI
    sub     eax, eax                    ; handled message result = zero
    ret     10h                         ; remove four callback arguments

;;;;;;;;;;;;;;;;;;;
;; WindowCommand ;;
;;;;;;;;;;;;;;;;;;;
WindowCommand:
    cmp     byte ptr [esp+13h], 3       ; EN_CHANGE notification code?
    jne     DefaultWindow               ; ignore focus and blur notifications

    mov     eax, dword ptr [esi+14h]    ; clean title terminator position
    mov     word ptr [eax], 2A20h       ; append space and star

;;;;;;;;;;;;;;;;;
;; TitleUpdate ;;
;;;;;;;;;;;;;;;;;
TitleUpdate:
    push    dword ptr [esi+10h]         ; lParam = filename leaf title
    push    0                           ; wParam = unused
    push    0Ch                         ; Msg    = WM_SETTEXT
    push    dword ptr [esp+14h]         ; hWnd   = callback parent HWND

    call    [__imp__SendMessageA@16]    ; display dirty or clean title
    jmp     WindowDone                  ; title update handled

;;;;;;;;;;;;;;;;;;
;; WindowSystem ;;
;;;;;;;;;;;;;;;;;;
WindowSystem:
    cmp     dword ptr [esp+10h], 51h    ; custom X! discard command?
    je      ProcessExit                 ; yes = exit even when dirty
    cmp     dword ptr [esp+10h], 50h    ; custom Save command?
    jne     DefaultWindow               ; no = normal System Menu command

;;;;;;;;;;;;;;
;; SaveFile ;;
;;;;;;;;;;;;;;
SaveFile:
    sub     eax, eax                    ; EAX = compact Save zero
    mov     dword ptr [esi+4], eax      ; dwError = no stream error
    push    eax                         ; dwMoveMethod = FILE_BEGIN
    push    eax                         ; lpDistanceHigh = none
    push    eax                         ; lDistanceToMove = zero
    push    dword ptr [esi]             ; hFile = retained dropped file

    call    [__imp__SetFilePointer@16]  ; rewind file to byte zero
    inc     eax                         ; failure minus one becomes zero
    jz      SaveDone                    ; no file or rewind error = no save

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

    jmp     TitleUpdate                 ; use shared dirty or clean refresh

SaveDone:
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
    push    0                           ; lpOverlapped = none
    push    4
    pop     ecx                         ; four original callback arguments

StreamArgs:
    push    dword ptr [esp+14h]         ; next arg stays at the same offset
    loop    StreamArgs

    call    eax                         ; call ReadFile or WriteFile

    dec     eax                         ; TRUE = success zero, FALSE = error
    ret     10h                         ; remove four callback arguments

;;;;;;;;;;;;;;;;;
;; StaticClass ;;
;;;;;;;;;;;;;;;;;
.const                                  ; compression-friendly read-only data
StaticClass db "static",0               ; ANSI saves bytes and
                                        ; needs no registration

;;;;;;;;;;;;;
;; RichDll ;;
;;;;;;;;;;;;;
RichDll     db "riched20",0             ; loader appends default
                                        ; .DLL extension
RichClass   db "richedit20a",0          ; adjacent common "riched" prefix
                                        ; ANSI Rich Edit 2 or 3 class

;;;;;;;;;;;;;;
;; SaveText ;;
;;;;;;;;;;;;;;
SaveText    db "Save",0                 ; no ampersand and no
                                        ; keyboard shortcut
                                        ; might add it later
ExitText    db "X!",0                   ; discard changes and exit
PrintPrefix db 'notepad /p "'           ; twelve copied command bytes

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
PrintCmd    db 0Ch dup(?)               ; F12 prefix directly before pathname
TitleText   db 106h dup(?)              ; loader-zeroed path/title workspace

END WinX86Entry

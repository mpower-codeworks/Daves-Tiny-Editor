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

; 000 init amd clear thread - 372 bytes exe
; 001
; 002
; 003
; 004

;;;;;;;;;;;;;;;;;;;
;; initial setup ;;
;;;;;;;;;;;;;;;;;;;
.386                 ; enable 80386 instrctns and 32-bit rgistrs
.model flat          ; use the 32-bit flat memory model
option casemap:none  ; preserve symbol case exactly as written
.code                ; Begin the executable machine-code section

;;;;;;;;;;;;;;;;; 
;; WinX86Entry ;;
;;;;;;;;;;;;;;;;;
WinX86Entry:
    xor     eax, eax ; clr EAX so init thread returns zero
    ret              ; RET hands control back to NT
END WinX86Entry

; Multiplication file:
#include <xc.inc>

; Final
global  Process_ADC        ; make visible to other files

; ==============================
; DATA SECTION (Access RAM)
; ==============================
psect udata_acs

ADC_L      ds 1
ADC_H      ds 1

RES0       ds 1
RES1       ds 1
RES2       ds 1
RES3       ds 1

VAL0       ds 1
VAL1       ds 1
VAL2       ds 1
VAL3       ds 1

DIG3       ds 1
DIG2       ds 1
DIG1       ds 1
DIG0       ds 1

; ==============================
; CONSTANTS
; ==============================
K_L        equ 0x8A
K_H        equ 0x41

psect code

; ========================================
; Process ADC ? Decimal Digits
; ========================================
Process_ADC:

    movff   ADRESL, ADC_L
    movff   ADRESH, ADC_H

    call    Mul16x16

    movff   RES3, DIG3

    movff   RES0, VAL0
    movff   RES1, VAL1
    movff   RES2, VAL2
    clrf    VAL3

    call    Mul24x10
    movff   VAL3, DIG2

    call    Mul24x10
    movff   VAL3, DIG1

    call    Mul24x10
    movff   VAL3, DIG0

    return

;==================================================
; Multiply (ADC_H:ADC_L) × (0x41:0x8A)
; Result ? RES3:RES2:RES1:RES0
;==================================================

Mul16x16:

    ; Clear 32-bit result
    clrf    RES0
    clrf    RES1
    clrf    RES2
    clrf    RES3

;------------------------------------------
; 1) AL × KL
;------------------------------------------
    movf    ADC_L, W
    mulwf   K_L          ; W × K_L ? PRODH:PRODL

    movff   PRODL, RES0  ; store low byte
    movff   PRODH, RES1  ; store high byte

;------------------------------------------
; 2) AL × KH
;------------------------------------------
    movf    ADC_L, W
    mulwf   K_H

    movf    PRODL, W
    addwf   RES1, F      ; add shifted result
    movf    PRODH, W
    addwfc  RES2, F
    clrf    WREG
    addwfc  RES3, F

;------------------------------------------
; 3) AH × KL
;------------------------------------------
    movf    ADC_H, W
    mulwf   K_L

    movf    PRODL, W
    addwf   RES1, F
    movf    PRODH, W
    addwfc  RES2, F
    clrf    WREG
    addwfc  RES3, F

;------------------------------------------
; 4) AH × KH
;------------------------------------------
    movf    ADC_H, W
    mulwf   K_H

    movf    PRODL, W
    addwf   RES2, F
    movf    PRODH, W
    addwfc  RES3, F

    return

;==================================================
; Multiply 24-bit VAL2:VAL1:VAL0 by 10
; Result returned in VAL3:VAL2:VAL1:VAL0
;==================================================

Mul24x10:

;-----------------------
; Copy original for x2
;-----------------------
    movff   VAL0, RES0
    movff   VAL1, RES1
    movff   VAL2, RES2
    clrf    RES3

;-----------------------
; x2 (shift left once)
;-----------------------
    rlf     RES0, F
    rlf     RES1, F
    rlf     RES2, F
    rlf     RES3, F

;-----------------------
; x8 (shift left 3)
;-----------------------
    rlf     VAL0, F
    rlf     VAL1, F
    rlf     VAL2, F
    rlf     VAL3, F

    rlf     VAL0, F
    rlf     VAL1, F
    rlf     VAL2, F
    rlf     VAL3, F

    rlf     VAL0, F
    rlf     VAL1, F
    rlf     VAL2, F
    rlf     VAL3, F

;-----------------------
; Add x2 + x8
;-----------------------
    movf    RES0, W
    addwf   VAL0, F
    movf    RES1, W
    addwfc  VAL1, F
    movf    RES2, W
    addwfc  VAL2, F
    movf    RES3, W
    addwfc  VAL3, F

 end


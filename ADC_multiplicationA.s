; Multiplication file:
#include <xc.inc>

; Final
global  Process_ADC       ; make visible to other files
global	DIG0, DIG1, DIG2, DIG3

; ==============================
; DATA SECTION (Access RAM)
; ==============================
psect udata_acs

ADC_L:      ds 1
ADC_H:      ds 1

RES0:       ds 1
RES1:       ds 1
RES2:       ds 1
RES3:       ds 1

VAL0:       ds 1
VAL1:       ds 1
VAL2:       ds 1
VAL3:       ds 1

DIG3:       ds 1
DIG2:       ds 1
DIG1:       ds 1
DIG0:       ds 1

; ==============================
; CONSTANTS
; ==============================
K_L        equ 0x41
K_H        equ 0x8A

psect adc_code, class=CODE

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
    clrf    VAL3, A

    call    Mul24x10
    movff   VAL3, DIG2

    call    Mul24x10
;    movff   VAL3, DIG1
    movf    VAL3, W
    andlw   0x09
    movwf   DIG1

    call    Mul24x10
    ; movff   VAL3, DIG0
    movf    VAL3, W
    andlw   0x09
    movwf   DIG0

    return

;==================================================
; Multiply (ADC_H:ADC_L) × (0x41:0x8A)
; Result ? RES3:RES2:RES1:RES0
;==================================================

Mul16x16:

    ; Clear 32-bit result
    clrf    RES0, A
    clrf    RES1, A
    clrf    RES2, A
    clrf    RES3, A

;------------------------------------------
; 1) AL × KL
;------------------------------------------
    movf    ADC_L, W, A
    mulwf   K_L          ; W × K_L -> PRODH:PRODL

    movff   PRODL, RES0  ; store low byte
    movff   PRODH, RES1  ; store high byte

;------------------------------------------
; 2) AL × KH
;------------------------------------------
    movf    ADC_L, W, A
    mulwf   K_H

    movf    PRODL, W, A
    addwf   RES1, F, A      ; add shifted result
   
    movf    PRODH, W, A
    addwfc  RES2, F, A
   
    clrf    WREG
    addwfc  RES3, F, A

;------------------------------------------
; 3) AH × KL
;------------------------------------------
    movf    ADC_H, W, A
    mulwf   K_L

    movf    PRODL, W, A
    addwf   RES1, F, A
   
    movf    PRODH, W, A
    addwfc  RES2, F, A
   
    clrf    WREG
    addwfc  RES3, F, A

;------------------------------------------
; 4) AH × KH
;------------------------------------------
    movf    ADC_H, W, A
    mulwf   K_H

    movf    PRODL, W, A
    addwf   RES2, F, A
   
    movf    PRODH, W, A
    addwfc  RES3, F, A

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
    clrf    RES3, A

;-----------------------
; x2 (shift left once)
;-----------------------
    rlcf     RES0, F, A
    rlcf     RES1, F, A
    rlcf     RES2, F, A
    rlcf     RES3, F, A

;-----------------------
; x8 (shift left 3)
;-----------------------
    rlcf     VAL0, F, A
    rlcf     VAL1, F, A
    rlcf     VAL2, F, A
    rlcf     VAL3, F, A

    rlcf     VAL0, F, A
    rlcf     VAL1, F, A
    rlcf     VAL2, F, A
    rlcf     VAL3, F, A

    rlcf     VAL0, F, A
    rlcf     VAL1, F, A
    rlcf     VAL2, F, A
    rlcf     VAL3, F, A

;-----------------------
; Add x2 + x8
;-----------------------
    movf    RES0, W, A
    addwf   VAL0, F, A
   
    movf    RES1, W, A
    addwfc  VAL1, F, A
   
    movf    RES2, W, A
    addwfc  VAL2, F, A
   
    movf    RES3, W, A
    addwfc  VAL3, F, A

 end



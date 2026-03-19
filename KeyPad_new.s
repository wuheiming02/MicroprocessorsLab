
#include <xc.inc>

; ============================================================
; KeyPad Module for 4x4 Matrix Keypad on PORTE
; RE0-3  <-> Columns (outputs / swapped during scan)
; RE4-7  <-> Rows    (inputs with pull-ups)
;
; Ribbon cable connection (keypad pin 0-7 -> RE0-7 in order).
; Previous individual-wire wiring had rows on RE0-3 and
; columns on RE4-7; the ribbon swaps the two halves.
;
; Returns ASCII value of key pressed in W
; Returns 0xFF if no valid key
; ============================================================

global  KeyPad_Init, KeyPad_Read, KP_Table

; ------------------------------------------------------------
; Reserve variables in Access RAM
; ------------------------------------------------------------
psect   udata_acs

KP_row:        ds 1      ; Masked RE0?3
KP_col:        ds 1      ; Masked RE4?7
KP_rowNum:     ds 1      ; Row number 0?3
KP_colNum:     ds 1      ; Column number 0?3
KP_index:      ds 1      ; row*4 + column
KP_result:     ds 1      ; Final ASCII result

; ------------------------------------------------------------
; CODE SECTION
; ------------------------------------------------------------
psect   keypad_code, class=CODE

; ============================================================
; KeyPad_Init
; ============================================================
KeyPad_Init:

        movlb   0x0F          ; Select bank containing PADCFG1
        bsf     REPU          ; Enable PORTE pull-ups

        clrf    LATE, A           ; Clear output latch

        movlw   0xF0
        movwf   TRISE, A         ; RE4-7 inputs (rows), RE0-3 outputs (cols)

        return


; ============================================================
; KeyPad_Read
; ============================================================
KeyPad_Read:

; ------------------ STEP 1: Detect Row ----------------------

        movlw   0xF0
        movwf   TRISE, A         ; RE4-7 inputs (rows), RE0-3 outputs (cols)

        clrf    LATE, A          ; Drive columns LOW

        call    KP_Delay

        movf    PORTE, W, A
        andlw   0xF0             ; mask to row bits only
        movwf   KP_row, A

        movf    KP_row, W, A
        xorlw   0xF0          ; 11110000 = no key
        bz      KP_NoKey

; ------------------ STEP 2: Detect Column -------------------

        movlw   0x0F
        movwf   TRISE, A         ; Swap: RE0-3 inputs (cols), RE4-7 outputs (rows)

        clrf    LATE, A          ; Drive rows LOW

        call    KP_Delay

        movf    PORTE, W, A
        andlw   0x0F             ; mask to column bits only
        movwf   KP_col, A

; ------------------ STEP 3: Decode --------------------------

        call    KP_Decode

        movf    KP_result, W, A
        return


KP_NoKey:
        movlw   0xFF
        return


; ============================================================
; KP_Decode
; ============================================================
KP_Decode:

; ------------------------------------------------------------
; Convert Row Pattern (Active LOW on RE4-7)
; Valid:
; 1110 0000 (0xE0) -> row 0  (RE4 pulled low)
; 1101 0000 (0xD0) -> row 1  (RE5 pulled low)
; 1011 0000 (0xB0) -> row 2  (RE6 pulled low)
; 0111 0000 (0x70) -> row 3  (RE7 pulled low)
; ------------------------------------------------------------

        movf    KP_row, W, A

        xorlw   0xE0
        bz      Row0

        movf    KP_row, W, A
        xorlw   0xD0
        bz      Row1

        movf    KP_row, W, A
        xorlw   0xB0
        bz      Row2

        movf    KP_row, W, A
        xorlw   0x70
        bz      Row3

        goto    KP_Invalid     ; Invalid pattern (multi-key)

Row0:   movlw   0
        movwf   KP_rowNum, A
        goto    ColDecode

Row1:   movlw   1
        movwf   KP_rowNum, A
        goto    ColDecode

Row2:   movlw   2
        movwf   KP_rowNum, A
        goto    ColDecode

Row3:   movlw   3
        movwf   KP_rowNum, A


; ------------------------------------------------------------
; Convert Column Pattern (Active LOW on RE0-3)
; Valid:
; 0000 1110 (0x0E) -> col 0  (RE0 pulled low)
; 0000 1101 (0x0D) -> col 1  (RE1 pulled low)
; 0000 1011 (0x0B) -> col 2  (RE2 pulled low)
; 0000 0111 (0x07) -> col 3  (RE3 pulled low)
; ------------------------------------------------------------

ColDecode:

        movf    KP_col, W, A

        xorlw   0x0E
        bz      Col0

        movf    KP_col, W, A
        xorlw   0x0D
        bz      Col1

        movf    KP_col, W, A
        xorlw   0x0B
        bz      Col2

        movf    KP_col, W, A
        xorlw   0x07
        bz      Col3

        goto    KP_Invalid

Col0:   movlw   0
        movwf   KP_colNum, A
        goto    ComputeIndex

Col1:   movlw   1
        movwf   KP_colNum, A
        goto    ComputeIndex

Col2:   movlw   2
        movwf   KP_colNum, A
        goto    ComputeIndex

Col3:   movlw   3
        movwf   KP_colNum, A


; ------------------------------------------------------------
; Compute index = row*4 + column
; ------------------------------------------------------------

ComputeIndex:

        movf    KP_rowNum, W, A
        mullw   4
        movf    PRODL, W, A

        addwf   KP_colNum, W, A
        movwf   KP_index, A


; ------------------------------------------------------------
; Lookup ASCII in Program Memory
; ------------------------------------------------------------

        movlw   low highword(KP_Table)
        movwf   TBLPTRU, A

        movlw   high(KP_Table)
        movwf   TBLPTRH, A

        movlw   low(KP_Table)
        movwf   TBLPTRL, A

        movf    KP_index, W, A
        addwf   TBLPTRL, F, A  ; should really propagate carry bits to TBLPTRH and TBLPTRU

        tblrd*
        movff   TABLAT, KP_result

        return


KP_Invalid:
        movlw   0xFF
        movwf   KP_result, A
        return

; ------------------------------------------------------------
; Small Settling Delay
; ------------------------------------------------------------
KP_Delay:
        movlw   0xFF
        movwf   KP_index, A
KP_D1:
        decfsz  KP_index, F, A
        bra     KP_D1
        return

; ------------------------------------------------------------
; ASCII Lookup Table
; ------------------------------------------------------------
psect   data

KP_Table:
        db '1','2','3','F'
        db '4','5','6','E'
        db '7','8','9','D'
        db 'A','0','B','C'

align 2
        end

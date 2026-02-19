
#include <xc.inc>

; ============================================================
; KeyPad Module for 4x4 Matrix Keypad on PORTE
; RE0?3  <-> Rows (inputs with pull-ups)
; RE4?7  <-> Columns (outputs / swapped during scan)
;
; Returns ASCII value of key pressed in W
; Returns 0xFF if no valid key
; ============================================================

global  KeyPad_Init, KeyPad_Read

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

        clrf    LATE          ; Clear output latch

        movlw   0x0F
        movwf   TRISE         ; RE0?3 inputs, RE4?7 outputs

        return


; ============================================================
; KeyPad_Read
; ============================================================
KeyPad_Read:

; ------------------ STEP 1: Detect Row ----------------------

        movlw   0x0F
        movwf   TRISE         ; RE0?3 input, RE4?7 output

        clrf    LATE          ; Drive columns LOW

        call    KP_Delay

        movf    PORTE, W
        andlw   0x0F
        movwf   KP_row

        movf    KP_row, W
        xorlw   0x0F          ; 1111 = no key
        bz      KP_NoKey

; ------------------ STEP 2: Detect Column -------------------

        movlw   0xF0
        movwf   TRISE         ; Swap directions

        clrf    LATE          ; Drive rows LOW

        call    KP_Delay

        movf    PORTE, W
        andlw   0xF0
        movwf   KP_col

; ------------------ STEP 3: Decode --------------------------

        call    KP_Decode

        movf    KP_result, W
        return


KP_NoKey:
        movlw   0xFF
        return


; ============================================================
; KP_Decode
; ============================================================
KP_Decode:

; ------------------------------------------------------------
; Convert Row Pattern (Active LOW)
; Valid:
; 1110 (0x0E) ? row 0
; 1101 (0x0D) ? row 1
; 1011 (0x0B) ? row 2
; 0111 (0x07) ? row 3
; ------------------------------------------------------------

        movf    KP_row, W

        xorlw   0x0E
        bz      Row0

        movf    KP_row, W
        xorlw   0x0D
        bz      Row1

        movf    KP_row, W
        xorlw   0x0B
        bz      Row2

        movf    KP_row, W
        xorlw   0x07
        bz      Row3

        goto    KP_Invalid     ; Invalid pattern (multi-key)

Row0:   movlw   0
        movwf   KP_rowNum
        goto    ColDecode

Row1:   movlw   1
        movwf   KP_rowNum
        goto    ColDecode

Row2:   movlw   2
        movwf   KP_rowNum
        goto    ColDecode

Row3:   movlw   3
        movwf   KP_rowNum


; ------------------------------------------------------------
; Convert Column Pattern (Active LOW)
; Valid:
; 1110 0000 (0xE0) ? col 0
; 1101 0000 (0xD0) ? col 1
; 1011 0000 (0xB0) ? col 2
; 0111 0000 (0x70) ? col 3
; ------------------------------------------------------------

ColDecode:

        movf    KP_col, W

        xorlw   0xE0
        bz      Col0

        movf    KP_col, W
        xorlw   0xD0
        bz      Col1

        movf    KP_col, W
        xorlw   0xB0
        bz      Col2

        movf    KP_col, W
        xorlw   0x70
        bz      Col3

        goto    KP_Invalid

Col0:   movlw   0
        movwf   KP_colNum
        goto    ComputeIndex

Col1:   movlw   1
        movwf   KP_colNum
        goto    ComputeIndex

Col2:   movlw   2
        movwf   KP_colNum
        goto    ComputeIndex

Col3:   movlw   3
        movwf   KP_colNum


; ------------------------------------------------------------
; Compute index = row*4 + column
; ------------------------------------------------------------

ComputeIndex:

        movf    KP_rowNum, W
        mullw   4
        movf    PRODL, W

        addwf   KP_colNum, W
        movwf   KP_index


; ------------------------------------------------------------
; Lookup ASCII in Program Memory
; ------------------------------------------------------------

        movlw   low highword(KP_Table)
        movwf   TBLPTRU, A

        movlw   high(KP_Table)
        movwf   TBLPTRH, A

        movlw   low(KP_Table)
        movwf   TBLPTRL, A

        movf    KP_index, W
        addwf   TBLPTRL, F

        tblrd*
        movff   TABLAT, KP_result

        return


KP_Invalid:
        movlw   0xFF
        movwf   KP_result
        return


; ------------------------------------------------------------
; ASCII Lookup Table
; ------------------------------------------------------------
psect   data

KP_Table:
        db '1','2','3','A'
        db '4','5','6','B'
        db '7','8','9','C'
        db '*','0','#','D'

align 2


; ------------------------------------------------------------
; Small Settling Delay
; ------------------------------------------------------------
KP_Delay:
        movlw   0xFF
        movwf   KP_index
KP_D1:
        decfsz  KP_index, F
        bra     KP_D1
        return

        end




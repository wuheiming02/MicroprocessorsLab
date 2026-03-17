#include <xc.inc>

; ============================================================
; Proj_Decrypt.s  -  Key entry, validation, and
;                    character-by-character decryption
;
; ACCESS RAM
; ----------
; This file declares NO access RAM variables.
; All variables are shared with Proj_Encrypt.s via extrn:
;
;   key_digits      8   raw ASCII digits of entered key
;   key_count       1   digits entered so far
;   enc_sub1        1   substitution index A
;   enc_sub2        1   substitution index B
;   enc_shift       1   initial Caesar shift
;   enc_step        1   shift increment interval
;   enc_run_shift   1   running shift value
;   enc_step_cnt    1   step interval counter
;   enc_alpha_pos   1   alphabet position scratch
;   enc_tmp         1   general scratch
;
; This saves 16 bytes compared to declaring separate dec_
; variables, bringing the project total to 91/96 bytes.
;
; Sharing is safe because:
;   - Decrypt_Init re-enters the full key entry flow and
;     overwrites enc_sub1/2, enc_shift, enc_step, key_digits,
;     key_count with the decryption key values
;   - enc_run_shift and enc_step_cnt are re-seeded at the
;     end of Decrypt_Init before any decryption begins
;   - Encryption (Encrypt_Run) is never called again after
;     decryption starts, so there is no conflict
;
; ============================================================
; Decryption algorithm
; --------------------
; Encryption applied, in order:
;   1. CharToPos    : ASCII -> 0-35 position
;   2. Substitution : swap sub1 <-> sub2
;   3. Caesar shift : pos = (pos + run_shift) mod 36
;   4. PosToChar    : 0-35 -> ASCII
;
; Decryption applies the inverse in reverse order:
;   1. CharToPos    : ASCII -> 0-35 position
;   2. Inverse Caesar shift:
;         pos = (pos - run_shift + 36) mod 36
;         +36 prevents unsigned underflow
;   3. Inverse substitution (swap is its own inverse)
;   4. PosToChar    : 0-35 -> ASCII
;
; Non-alphabet characters pass through unchanged and still
; advance the step counter, matching encryptor behaviour.
;
; ============================================================
; Key format (identical to Proj_Encrypt.s)
; -----------------------------------------
;   Digits 1-2 : enc_sub1   01-26
;   Digits 3-4 : enc_sub2   01-26
;   Digits 5-6 : enc_shift  01-36
;   Digits 7-8 : enc_step   not 00
; ============================================================

; ============================================================
; PUBLIC SYMBOLS
; ============================================================
global  Decrypt_Init        ; key entry + validation + seed; call once
global  DecryptChar         ; decrypt decoded_char in place; call per char

; ============================================================
; EXTERNAL SYMBOLS
; ============================================================

; From Proj_ReadMorseCode.s
extrn   decoded_char        ; input character; overwritten with result

; From Proj_Encrypt.s  (all variables shared, no new RAM needed)
extrn   key_digits          ; reused for decryption key entry
extrn   key_count           ; reused for decryption key entry
extrn   enc_sub1            ; overwritten with decryption key sub1
extrn   enc_sub2            ; overwritten with decryption key sub2
extrn   enc_shift           ; overwritten with decryption key shift
extrn   enc_step            ; overwritten with decryption key step
extrn   enc_run_shift       ; re-seeded by Decrypt_Init
extrn   enc_step_cnt        ; re-seeded by Decrypt_Init
extrn   enc_alpha_pos       ; shared scratch
extrn   enc_tmp             ; shared scratch

; From LCD module
extrn   LCD_Send_Byte_D
extrn   LCD_Send_Byte_I
extrn   LCD_delay_ms
extrn   LCD_delay_x4us
extrn   clear_LCD

; From Keypad module
extrn   KeyPad_Read

; ============================================================
; CONSTANTS
; ============================================================
LCD_LINE1_BASE  EQU 0x80
LCD_LINE2_BASE  EQU 0xC0
ALPHA_SIZE      EQU 36
KEY_LEN         EQU 8

; ============================================================
; NO ACCESS RAM DECLARED HERE
; ============================================================

; ============================================================
; CODE
; ============================================================
psect   decrypt_code, class=CODE

; ============================================================
; Decrypt_Init
; ============================================================
; Prompt the user to enter the 8-digit decryption key.
; Validates it using identical rules to Proj_Encrypt.s.
; Overwrites enc_sub1, enc_sub2, enc_shift, enc_step with
; the decryption key values, then seeds enc_run_shift and
; enc_step_cnt ready for DecryptChar.
; Does not return until a valid key has been accepted.
; ============================================================
Decrypt_Init:
        ; Zero key entry state (reusing enc_ variables)
        clrf    key_count,      A
        clrf    enc_sub1,       A
        clrf    enc_sub2,       A
        clrf    enc_shift,      A
        clrf    enc_step,       A
        clrf    enc_run_shift,  A
        clrf    enc_step_cnt,   A
        clrf    enc_tmp,        A

        call    DEC_PromptKey

DEC_KeyEntryLoop:
        call    KeyPad_Read
        movwf   enc_tmp, A

        movlw   0xFF
        cpfseq  enc_tmp, A
        bra     DEC_GotKey
        bra     DEC_KeyEntryLoop

DEC_GotKey:
        call    DEC_WaitRelease

        ; ---- 'C' = confirm ----
        movf    enc_tmp, W, A
        xorlw   'C'
        bz      DEC_TryConfirm

        ; ---- 'E' = backspace ----
        movf    enc_tmp, W, A
        xorlw   'E'
        bz      DEC_Backspace

        ; ---- Accept only '0'-'9' ----
        movf    enc_tmp, W, A
        sublw   '9'
        bnc     DEC_KeyEntryLoop    ; carry=0: enc_tmp > '9', ignore

        movf    enc_tmp, W, A
        sublw   '0' - 1
        bc      DEC_KeyEntryLoop    ; carry=1: enc_tmp < '0', ignore

DEC_AcceptDigit:
        movlw   KEY_LEN
        cpfslt  key_count, A
        bra     DEC_KeyEntryLoop

        ; ---- Store digit at key_digits[key_count] ----
        movf    key_count, W, A
        addlw   low(key_digits)
        movwf   FSR0L, A
        movlw   high(key_digits)
        movwf   FSR0H, A
        movf    enc_tmp, W, A
        movwf   INDF0, A

        ; ---- Echo digit on LCD line 2 ----
        movf    key_count, W, A
        addlw   LCD_LINE2_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us
        movf    enc_tmp, W, A
        call    LCD_Send_Byte_D

        incf    key_count, F, A
        bra     DEC_KeyEntryLoop

; ---- Backspace ----
DEC_Backspace:
        movf    key_count, W, A
        bz      DEC_KeyEntryLoop

        decf    key_count, F, A

        movf    key_count, W, A
        addlw   LCD_LINE2_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us
        movlw   ' '
        call    LCD_Send_Byte_D

        movf    key_count, W, A
        addlw   LCD_LINE2_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us

        bra     DEC_KeyEntryLoop

; ---- Confirm: require exactly 8 digits ----
DEC_TryConfirm:
        movlw   KEY_LEN
        cpfseq  key_count, A
        bra     DEC_KeyEntryLoop

        ; --------------------------------------------------
        ; Parse and validate the four key fields
        ; --------------------------------------------------

        ; ---- enc_sub1 = digits 0-1, must be 01-26 ----
        call    DEC_ParsePair0
        movwf   enc_sub1, A
        bz      DEC_Invalid
        movlw   27
        cpfslt  enc_sub1, A
        bra     DEC_Invalid

        ; ---- enc_sub2 = digits 2-3, must be 01-26 ----
        call    DEC_ParsePair1
        movwf   enc_sub2, A
        bz      DEC_Invalid
        movlw   27
        cpfslt  enc_sub2, A
        bra     DEC_Invalid

        ; ---- enc_shift = digits 4-5, must be 01-36 ----
        call    DEC_ParsePair2
        movwf   enc_shift, A
        bz      DEC_Invalid
        movlw   37
        cpfslt  enc_shift, A
        bra     DEC_Invalid

        ; ---- enc_step = digits 6-7, must not be 00 ----
        call    DEC_ParsePair3
        movwf   enc_step, A
        bz      DEC_Invalid

        bra     DEC_KeyValid

; ---- Invalid key: show error, pause, restart ----
DEC_Invalid:
        call    clear_LCD

        ; "ERROR" on line 1
        movlw   LCD_LINE1_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us
        movlw   'E'
        call    LCD_Send_Byte_D
        movlw   'R'
        call    LCD_Send_Byte_D
        movlw   'R'
        call    LCD_Send_Byte_D
        movlw   'O'
        call    LCD_Send_Byte_D
        movlw   'R'
        call    LCD_Send_Byte_D

        ; "BAD KEY" on line 2
        movlw   LCD_LINE2_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us
        movlw   'B'
        call    LCD_Send_Byte_D
        movlw   'A'
        call    LCD_Send_Byte_D
        movlw   'D'
        call    LCD_Send_Byte_D
        movlw   ' '
        call    LCD_Send_Byte_D
        movlw   'K'
        call    LCD_Send_Byte_D
        movlw   'E'
        call    LCD_Send_Byte_D
        movlw   'Y'
        call    LCD_Send_Byte_D

        ; ~2 second pause
        movlw   250
        call    LCD_delay_ms
        movlw   250
        call    LCD_delay_ms
        movlw   250
        call    LCD_delay_ms
        movlw   250
        call    LCD_delay_ms
        movlw   250
        call    LCD_delay_ms
        movlw   250
        call    LCD_delay_ms
        movlw   250
        call    LCD_delay_ms
        movlw   250
        call    LCD_delay_ms

        ; Reset and re-prompt
        clrf    key_count,  A
        clrf    enc_sub1,   A
        clrf    enc_sub2,   A
        clrf    enc_shift,  A
        clrf    enc_step,   A
        call    clear_LCD
        call    DEC_PromptKey
        bra     DEC_KeyEntryLoop

; ---- Valid key: confirm and seed running shift ----
DEC_KeyValid:
        call    clear_LCD

        ; "KEY OK" on line 1
        movlw   LCD_LINE1_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us
        movlw   'K'
        call    LCD_Send_Byte_D
        movlw   'E'
        call    LCD_Send_Byte_D
        movlw   'Y'
        call    LCD_Send_Byte_D
        movlw   ' '
        call    LCD_Send_Byte_D
        movlw   'O'
        call    LCD_Send_Byte_D
        movlw   'K'
        call    LCD_Send_Byte_D

        ; ~750 ms pause
        movlw   250
        call    LCD_delay_ms
        movlw   250
        call    LCD_delay_ms
        movlw   250
        call    LCD_delay_ms

        ; Seed running shift from parsed key
        movf    enc_shift, W, A
        movwf   enc_run_shift, A
        clrf    enc_step_cnt, A

        call    clear_LCD
        return

; ============================================================
; DecryptChar
; ============================================================
; Decrypt the single ASCII character in decoded_char.
; Writes the plaintext result back to decoded_char.
; Advances the running shift regardless of whether the
; character is in the encryption alphabet.
; ============================================================
DecryptChar:

        ; ---- Step 1: convert to alphabet position ----
        movf    decoded_char, W, A
        movwf   enc_tmp, A
        call    DEC_CharToPos       ; result in enc_tmp (0-35 or 0xFF)

        ; ---- Not in alphabet: skip decryption, still update shift ----
        movf    enc_tmp, W, A
        xorlw   0xFF
        bz      DEC_UpdateShift

        ; ---- Step 2: inverse Caesar shift ----
        ; plain_pos = (enc_pos - run_shift + 36) mod 36
        movlw   ALPHA_SIZE
        addwf   enc_tmp, F, A       ; enc_tmp = enc_pos + 36
        movf    enc_run_shift, W, A
        subwf   enc_tmp, F, A       ; enc_tmp = enc_pos + 36 - run_shift

DEC_ModLoop:
        movlw   ALPHA_SIZE
        cpfslt  enc_tmp, A
        bra     DEC_ModReduce
        bra     DEC_ModDone

DEC_ModReduce:
        movlw   ALPHA_SIZE
        subwf   enc_tmp, F, A
        bra     DEC_ModLoop

DEC_ModDone:

        ; ---- Step 3: inverse substitution swap ----
        movf    enc_sub1, W, A
        addlw   -1
        cpfseq  enc_tmp, A
        bra     DEC_CheckSub2

        movf    enc_sub2, W, A
        addlw   -1
        movwf   enc_tmp, A
        bra     DEC_DoneSubstitution

DEC_CheckSub2:
        movf    enc_sub2, W, A
        addlw   -1
        cpfseq  enc_tmp, A
        bra     DEC_DoneSubstitution

        movf    enc_sub1, W, A
        addlw   -1
        movwf   enc_tmp, A

DEC_DoneSubstitution:

        ; ---- Step 4: convert position back to ASCII ----
        movf    enc_tmp, W, A
        call    DEC_PosToChar       ; W = decrypted ASCII character
        movwf   decoded_char, A

DEC_UpdateShift:
        ; ---- Advance running shift every enc_step characters ----
        incf    enc_step_cnt, F, A
        movf    enc_step, W, A
        cpfseq  enc_step_cnt, A
        bra     DEC_NoShiftUpdate

        ; Increment by 1, wrap 36 -> 1
        incf    enc_run_shift, F, A
        movlw   ALPHA_SIZE + 1      ; 37
        cpfseq  enc_run_shift, A
        bra     DEC_ShiftWrapDone
        movlw   1
        movwf   enc_run_shift, A

DEC_ShiftWrapDone:
        clrf    enc_step_cnt, A

DEC_NoShiftUpdate:
        return

; ============================================================
; DEC_PromptKey  (private)
; ============================================================
DEC_PromptKey:
        call    clear_LCD

        movlw   LCD_LINE1_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us
        movlw   'E'
        call    LCD_Send_Byte_D
        movlw   'N'
        call    LCD_Send_Byte_D
        movlw   'T'
        call    LCD_Send_Byte_D
        movlw   'E'
        call    LCD_Send_Byte_D
        movlw   'R'
        call    LCD_Send_Byte_D
        movlw   ' '
        call    LCD_Send_Byte_D
        movlw   'K'
        call    LCD_Send_Byte_D
        movlw   'E'
        call    LCD_Send_Byte_D
        movlw   'Y'
        call    LCD_Send_Byte_D
        movlw   ':'
        call    LCD_Send_Byte_D

        movlw   LCD_LINE2_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us
        return

; ============================================================
; DEC_WaitRelease  (private)
; ============================================================
DEC_WaitRelease:
        call    KeyPad_Read
        addlw   1                   ; 0xFF + 1 = 0x00, sets Z if released
        bnz     DEC_WaitRelease
        return

; ============================================================
; DEC_Mul10  (private)
; ============================================================
; Multiply W by 10 via repeated addition.
; Uses enc_tmp and enc_step_cnt as scratch.
; Uses enc_alpha_pos as accumulator.
; Safe during key parsing (before decryption starts).
; ============================================================
DEC_Mul10:
        movwf   enc_tmp, A
        clrf    enc_alpha_pos, A
        movlw   10
        movwf   enc_step_cnt, A
DEC_Mul10Loop:
        movf    enc_tmp, W, A
        addwf   enc_alpha_pos, F, A
        decfsz  enc_step_cnt, F, A
        bra     DEC_Mul10Loop
        movf    enc_alpha_pos, W, A
        return

; ---- ParsePair0: key_digits[0..1] ----
DEC_ParsePair0:
        movf    key_digits + 0, W, A
        addlw   -'0'
        call    DEC_Mul10
        movwf   enc_tmp, A
        movf    key_digits + 1, W, A
        addlw   -'0'
        addwf   enc_tmp, W, A
        return

; ---- ParsePair1: key_digits[2..3] ----
DEC_ParsePair1:
        movf    key_digits + 2, W, A
        addlw   -'0'
        call    DEC_Mul10
        movwf   enc_tmp, A
        movf    key_digits + 3, W, A
        addlw   -'0'
        addwf   enc_tmp, W, A
        return

; ---- ParsePair2: key_digits[4..5] ----
DEC_ParsePair2:
        movf    key_digits + 4, W, A
        addlw   -'0'
        call    DEC_Mul10
        movwf   enc_tmp, A
        movf    key_digits + 5, W, A
        addlw   -'0'
        addwf   enc_tmp, W, A
        return

; ---- ParsePair3: key_digits[6..7] ----
DEC_ParsePair3:
        movf    key_digits + 6, W, A
        addlw   -'0'
        call    DEC_Mul10
        movwf   enc_tmp, A
        movf    key_digits + 7, W, A
        addlw   -'0'
        addwf   enc_tmp, W, A
        return

; ============================================================
; DEC_CharToPos  (private)
; ============================================================
; Converts ASCII character in enc_tmp to 0-35 position.
; Result stored back in enc_tmp. 0xFF if not in alphabet.
; ============================================================
DEC_CharToPos:
        movf    enc_tmp, W, A
        sublw   'A' - 1
        bc      DEC_CheckDigit      ; carry=1: enc_tmp < 'A'

        movf    enc_tmp, W, A
        sublw   'Z'
        bnc     DEC_NotAlpha        ; carry=0: enc_tmp > 'Z'

        movf    enc_tmp, W, A
        addlw   -'A'
        movwf   enc_tmp, A
        return

DEC_CheckDigit:
        movf    enc_tmp, W, A
        sublw   '0' - 1
        bc      DEC_NotAlpha        ; carry=1: enc_tmp < '0'

        movf    enc_tmp, W, A
        sublw   '9'
        bnc     DEC_NotAlpha        ; carry=0: enc_tmp > '9'

        movf    enc_tmp, W, A
        addlw   -'0'
        addlw   26
        movwf   enc_tmp, A
        return

DEC_NotAlpha:
        movlw   0xFF
        movwf   enc_tmp, A
        return

; ============================================================
; DEC_PosToChar  (private)
; ============================================================
; Converts 0-35 position in W to ASCII in W.
; Clobbers enc_tmp.
; ============================================================
DEC_PosToChar:
        movwf   enc_tmp, A
        movlw   26
        cpfslt  enc_tmp, A
        bra     DEC_PosIsDigit
        movf    enc_tmp, W, A
        addlw   'A'
        return
DEC_PosIsDigit:
        movf    enc_tmp, W, A
        addlw   -26
        addlw   '0'
        return

        end

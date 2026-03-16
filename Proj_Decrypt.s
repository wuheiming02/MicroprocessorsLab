#include <xc.inc>

; ============================================================
; Proj_Decrypt.s  -  Key entry, validation, and
;                    character-by-character decryption
;
; Overview
; --------
; Decrypt_Init prompts the user to enter the 8-digit
; decryption key (same format and validation rules as the
; encryption key in Proj_Encrypt.s), parses it, and seeds
; the running shift state.  It does not return until a valid
; key has been accepted.
;
; DecryptChar decrypts the single ASCII character currently
; in decoded_char and writes the plaintext result back to
; decoded_char.  It is called from Proj_ReadMorseCode.s
; after each Morse character has been decoded, before it is
; printed to the LCD.
;
; ============================================================
; Decryption algorithm
; --------------------
; Encryption applied, in order:
;   1. CharToPos    : ASCII -> 0-35 position
;   2. Substitution : swap sub1 <-> sub2
;   3. Caesar shift : pos = (pos + run_shift) mod 36
;   4. PosToChar    : 0-35 position -> ASCII
;
; Decryption applies the inverse in reverse order:
;   1. CharToPos    : ASCII -> 0-35 position
;   2. Inverse Caesar shift:
;         pos = (pos - run_shift + 36) mod 36
;         +36 prevents unsigned underflow
;   3. Inverse substitution (swap is its own inverse)
;   4. PosToChar    : 0-35 position -> ASCII
;
; Non-alphabet characters pass through unchanged and still
; advance the step counter, matching encryptor behaviour.
;
; ============================================================
; Key format (identical to Proj_Encrypt.s)
; -----------------------------------------
;   Digits 1-2 : dec_sub1   01-26
;   Digits 3-4 : dec_sub2   01-26
;   Digits 5-6 : dec_shift  01-36
;   Digits 7-8 : dec_step   not 00
;
; ============================================================
; ACCESS RAM  (16 bytes, all new)
; --------------------------------
;   dec_key_digits  8   raw ASCII digits of entered key
;   dec_key_count   1   digits entered so far (0-8)
;   dec_sub1        1   substitution index A, 1-26
;   dec_sub2        1   substitution index B, 1-26
;   dec_shift       1   initial Caesar shift, 1-36
;   dec_step        1   shift increment interval, 1-99
;   dec_run_shift   1   running shift value
;   dec_step_cnt    1   step interval counter
;   dec_tmp         1   general scratch
; ============================================================

; ============================================================
; PUBLIC SYMBOLS
; ============================================================
global  Decrypt_Init        ; key entry + validation + seed; call once
global  DecryptChar         ; decrypt decoded_char in place; call per char

; ============================================================
; EXTERNAL SYMBOLS
; ============================================================
extrn   decoded_char        ; from Proj_ReadMorseCode.s: input and output
extrn   LCD_Send_Byte_D
extrn   LCD_Send_Byte_I
extrn   LCD_delay_ms
extrn   LCD_delay_x4us
extrn   clear_LCD
extrn   KeyPad_Read

; ============================================================
; CONSTANTS
; ============================================================
LCD_LINE1_BASE  EQU 0x80
LCD_LINE2_BASE  EQU 0xC0
ALPHA_SIZE      EQU 36
KEY_LEN         EQU 8

; ============================================================
; ACCESS RAM  (16 bytes)
; ============================================================
psect   udata_acs

dec_key_digits: ds 8    ; raw ASCII key digits as typed
dec_key_count:  ds 1    ; digits entered so far; also LCD cursor column
dec_sub1:       ds 1    ; substitution index A, range 1-26
dec_sub2:       ds 1    ; substitution index B, range 1-26
dec_shift:      ds 1    ; initial Caesar shift, range 1-36
dec_step:       ds 1    ; shift increment interval, range 1-99
dec_run_shift:  ds 1    ; running shift (starts at dec_shift, increments
                        ; by dec_shift every dec_step characters)
dec_step_cnt:   ds 1    ; characters processed in current step interval
dec_tmp:        ds 1    ; scratch byte

; ============================================================
; CODE
; ============================================================
psect   decrypt_code, class=CODE

; ============================================================
; Decrypt_Init
; ============================================================
; Prompt for and validate the 8-digit decryption key.
; Seeds dec_run_shift and dec_step_cnt for DecryptChar.
; Does not return until a valid key has been accepted.
; ============================================================
Decrypt_Init:
        ; Zero all key entry state
        clrf    dec_key_count,  A
        clrf    dec_sub1,       A
        clrf    dec_sub2,       A
        clrf    dec_shift,      A
        clrf    dec_step,       A
        clrf    dec_run_shift,  A
        clrf    dec_step_cnt,   A
        clrf    dec_tmp,        A

        call    DEC_PromptKey       ; display "ENTER KEY:" on line 1

DEC_KeyEntryLoop:
        call    KeyPad_Read
        movwf   dec_tmp, A

        movlw   0xFF
        cpfseq  dec_tmp, A          ; skip if no key pressed
        bra     DEC_GotKey
        bra     DEC_KeyEntryLoop

DEC_GotKey:
        call    DEC_WaitRelease     ; drain the keypress before acting

        ; ---- 'C' = confirm ----
        movf    dec_tmp, W, A
        xorlw   'C'
        bz      DEC_TryConfirm

        ; ---- 'E' = backspace ----
        movf    dec_tmp, W, A
        xorlw   'E'
        bz      DEC_Backspace

        ; ---- Accept only '0'-'9' ----
        ; Upper bound: reject if dec_tmp > '9'
        movf    dec_tmp, W, A
        sublw   '9'
        bnc     DEC_KeyEntryLoop    ; carry=0: dec_tmp > '9', ignore

        ; Lower bound: reject if dec_tmp < '0'
        movf    dec_tmp, W, A
        sublw   '0' - 1
        bc      DEC_KeyEntryLoop    ; carry=1: dec_tmp < '0', ignore

DEC_AcceptDigit:
        ; Ignore extra digits once buffer is full
        movlw   KEY_LEN
        cpfslt  dec_key_count, A
        bra     DEC_KeyEntryLoop

        ; ---- Store digit at dec_key_digits[dec_key_count] ----
        movf    dec_key_count, W, A
        addlw   low(dec_key_digits)
        movwf   FSR0L, A
        movlw   high(dec_key_digits)
        movwf   FSR0H, A
        movf    dec_tmp, W, A
        movwf   INDF0, A

        ; ---- Echo digit on LCD line 2 ----
        movf    dec_key_count, W, A
        addlw   LCD_LINE2_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us
        movf    dec_tmp, W, A
        call    LCD_Send_Byte_D

        incf    dec_key_count, F, A
        bra     DEC_KeyEntryLoop

; ---- Backspace ----
DEC_Backspace:
        movf    dec_key_count, W, A
        bz      DEC_KeyEntryLoop    ; nothing to erase

        decf    dec_key_count, F, A

        ; Blank the erased position
        movf    dec_key_count, W, A
        addlw   LCD_LINE2_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us
        movlw   ' '
        call    LCD_Send_Byte_D

        ; Reposition cursor at the blank column
        movf    dec_key_count, W, A
        addlw   LCD_LINE2_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us

        bra     DEC_KeyEntryLoop

; ---- Confirm: require exactly 8 digits ----
DEC_TryConfirm:
        movlw   KEY_LEN
        cpfseq  dec_key_count, A    ; skip if dec_key_count == 8
        bra     DEC_KeyEntryLoop    ; fewer than 8 digits, keep waiting

        ; --------------------------------------------------
        ; Parse and validate the four key fields
        ; --------------------------------------------------

        ; ---- dec_sub1 = digits 0-1, must be 01-26 ----
        call    DEC_ParsePair0
        movwf   dec_sub1, A
        bz      DEC_Invalid
        movlw   27
        cpfslt  dec_sub1, A
        bra     DEC_Invalid

        ; ---- dec_sub2 = digits 2-3, must be 01-26 ----
        call    DEC_ParsePair1
        movwf   dec_sub2, A
        bz      DEC_Invalid
        movlw   27
        cpfslt  dec_sub2, A
        bra     DEC_Invalid

        ; ---- dec_shift = digits 4-5, must be 01-36 ----
        call    DEC_ParsePair2
        movwf   dec_shift, A
        bz      DEC_Invalid
        movlw   37
        cpfslt  dec_shift, A
        bra     DEC_Invalid

        ; ---- dec_step = digits 6-7, must not be 00 ----
        call    DEC_ParsePair3
        movwf   dec_step, A
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

        ; Reset key entry state and re-prompt
        clrf    dec_key_count, A
        clrf    dec_sub1,      A
        clrf    dec_sub2,      A
        clrf    dec_shift,     A
        clrf    dec_step,      A
        call    clear_LCD
        call    DEC_PromptKey
        bra     DEC_KeyEntryLoop

; ---- Valid key: show confirmation and seed running shift ----
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
        movf    dec_shift, W, A
        movwf   dec_run_shift, A
        clrf    dec_step_cnt, A

        call    clear_LCD
        return                      ; Decrypt_Init complete

; ============================================================
; DecryptChar
; ============================================================
; Decrypt the single ASCII character in decoded_char.
; Writes the plaintext result back to decoded_char.
; Advances the running shift state regardless of whether
; the character is in the encryption alphabet.
; ============================================================
DecryptChar:

        ; ---- Step 1: convert to alphabet position ----
        movf    decoded_char, W, A
        movwf   dec_tmp, A
        call    DEC_CharToPos       ; result stored in dec_tmp (0-35 or 0xFF)

        ; ---- Not in alphabet: skip decryption, still update shift ----
        movf    dec_tmp, W, A
        xorlw   0xFF
        bz      DEC_UpdateShift

        ; ---- Step 2: inverse Caesar shift ----
        ; plain_pos = (enc_pos - run_shift + 36) mod 36
        movlw   ALPHA_SIZE          ; W = 36
        addwf   dec_tmp, F, A       ; dec_tmp = enc_pos + 36
        movf    dec_run_shift, W, A
        subwf   dec_tmp, F, A       ; dec_tmp = enc_pos + 36 - run_shift

DEC_ModLoop:
        movlw   ALPHA_SIZE
        cpfslt  dec_tmp, A          ; skip if dec_tmp < 36
        bra     DEC_ModReduce
        bra     DEC_ModDone

DEC_ModReduce:
        movlw   ALPHA_SIZE
        subwf   dec_tmp, F, A
        bra     DEC_ModLoop

DEC_ModDone:

        ; ---- Step 3: inverse substitution swap ----
        movf    dec_sub1, W, A
        addlw   -1                  ; sub1_pos (0-based)
        cpfseq  dec_tmp, A
        bra     DEC_CheckSub2

        ; Matched sub1: swap to sub2
        movf    dec_sub2, W, A
        addlw   -1
        movwf   dec_tmp, A
        bra     DEC_DoneSubstitution

DEC_CheckSub2:
        movf    dec_sub2, W, A
        addlw   -1                  ; sub2_pos (0-based)
        cpfseq  dec_tmp, A
        bra     DEC_DoneSubstitution

        ; Matched sub2: swap to sub1
        movf    dec_sub1, W, A
        addlw   -1
        movwf   dec_tmp, A

DEC_DoneSubstitution:

        ; ---- Step 4: convert position back to ASCII ----
        movf    dec_tmp, W, A
        call    DEC_PosToChar       ; W = decrypted ASCII character
        movwf   decoded_char, A     ; write result back

DEC_UpdateShift:
        ; ---- Advance running shift every dec_step characters ----
        incf    dec_step_cnt, F, A
        movf    dec_step, W, A
        cpfseq  dec_step_cnt, A
        bra     DEC_NoShiftUpdate

        ; Increment running shift by 1 and wrap 36 -> 1
        incf    dec_run_shift, F, A ; dec_run_shift += 1
        movlw   ALPHA_SIZE + 1      ; 37
        cpfseq  dec_run_shift, A    ; skip if dec_run_shift == 37
        bra     DEC_ShiftWrapDone
        movlw   1                   ; wrap: 37 -> 1
        movwf   dec_run_shift, A

DEC_ShiftWrapDone:
        clrf    dec_step_cnt, A

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
; Input: W = digit 0-9.  Output: W = digit * 10.
; Uses dec_tmp and dec_step_cnt as scratch.
; Safe during key parsing (before decryption starts).
; ============================================================
DEC_Mul10:
        movwf   dec_tmp, A          ; save digit
        clrf    dec_run_shift, A    ; use dec_run_shift as accumulator
                                    ; (safe: seeded after parsing completes)
        movlw   10
        movwf   dec_step_cnt, A     ; loop counter
DEC_Mul10Loop:
        movf    dec_tmp, W, A
        addwf   dec_run_shift, F, A
        decfsz  dec_step_cnt, F, A
        bra     DEC_Mul10Loop
        movf    dec_run_shift, W, A ; W = digit * 10
        return

; ---- ParsePair0: dec_key_digits[0..1] ----
DEC_ParsePair0:
        movf    dec_key_digits + 0, W, A
        addlw   -'0'
        call    DEC_Mul10
        movwf   dec_tmp, A
        movf    dec_key_digits + 1, W, A
        addlw   -'0'
        addwf   dec_tmp, W, A
        return

; ---- ParsePair1: dec_key_digits[2..3] ----
DEC_ParsePair1:
        movf    dec_key_digits + 2, W, A
        addlw   -'0'
        call    DEC_Mul10
        movwf   dec_tmp, A
        movf    dec_key_digits + 3, W, A
        addlw   -'0'
        addwf   dec_tmp, W, A
        return

; ---- ParsePair2: dec_key_digits[4..5] ----
DEC_ParsePair2:
        movf    dec_key_digits + 4, W, A
        addlw   -'0'
        call    DEC_Mul10
        movwf   dec_tmp, A
        movf    dec_key_digits + 5, W, A
        addlw   -'0'
        addwf   dec_tmp, W, A
        return

; ---- ParsePair3: dec_key_digits[6..7] ----
DEC_ParsePair3:
        movf    dec_key_digits + 6, W, A
        addlw   -'0'
        call    DEC_Mul10
        movwf   dec_tmp, A
        movf    dec_key_digits + 7, W, A
        addlw   -'0'
        addwf   dec_tmp, W, A
        return

; ============================================================
; DEC_CharToPos  (private)
; ============================================================
; Convert ASCII character in dec_tmp to 0-35 position.
; Result stored back in dec_tmp.  0xFF if not in alphabet.
;
; Carry flag for sublw on PIC18:
;   sublw k  ->  W = k - W
;   Borrow (carry=0) when W > k  (i.e. enc_tmp > k)
;   No borrow (carry=1) when W <= k
; ============================================================
DEC_CharToPos:
        ; ---- A-Z check ----
        movf    dec_tmp, W, A
        sublw   'A' - 1
        bc      DEC_CheckDigit      ; carry=1: dec_tmp < 'A'

        movf    dec_tmp, W, A
        sublw   'Z'
        bnc     DEC_NotAlpha        ; carry=0: dec_tmp > 'Z'

        movf    dec_tmp, W, A
        addlw   -'A'
        movwf   dec_tmp, A          ; position 0-25
        return

DEC_CheckDigit:
        ; ---- 0-9 check ----
        movf    dec_tmp, W, A
        sublw   '0' - 1
        bc      DEC_NotAlpha        ; carry=1: dec_tmp < '0'

        movf    dec_tmp, W, A
        sublw   '9'
        bnc     DEC_NotAlpha        ; carry=0: dec_tmp > '9'

        movf    dec_tmp, W, A
        addlw   -'0'
        addlw   26
        movwf   dec_tmp, A          ; position 26-35
        return

DEC_NotAlpha:
        movlw   0xFF
        movwf   dec_tmp, A
        return

; ============================================================
; DEC_PosToChar  (private)
; ============================================================
; Convert 0-35 position in W to ASCII character in W.
; Clobbers dec_tmp.
; ============================================================
DEC_PosToChar:
        movwf   dec_tmp, A
        movlw   26
        cpfslt  dec_tmp, A
        bra     DEC_PosIsDigit
        movf    dec_tmp, W, A
        addlw   'A'
        return
DEC_PosIsDigit:
        movf    dec_tmp, W, A
        addlw   -26
        addlw   '0'
        return

        end

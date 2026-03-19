#include <xc.inc>

; ============================================================
; Proj_Encrypt.s  -  Key entry, validation, and in-place
;                    encryption
;
; ACCESS RAM BUDGET (this file)
; ------------------------------
; Previous version used 53 bytes.  This version uses 18 bytes:
;
;   key_digits      8   raw key digit characters
;   key_count       1   digits entered so far
;   enc_sub1        1   parsed substitution index A
;   enc_sub2        1   parsed substitution index B
;   enc_shift       1   parsed initial Caesar shift
;   enc_step        1   parsed shift increment interval
;   enc_index       1   loop counter over message_buffer
;   enc_alpha_pos   1   0-35 alphabet position (0xFF = not alpha)
;   enc_run_shift   1   running Caesar shift value
;   enc_step_cnt    1   counts chars within current step interval
;   enc_tmp         1   general scratch (doubles as enc_char)
;   TOTAL          18 bytes  (saving 35 bytes vs previous version)
;
; Variables removed and how:
;   enc_buffer  (32) - encryption now done IN-PLACE directly
;                      into message_buffer, overwriting each
;                      plaintext byte with its ciphertext byte
;   enc_result   (1) - encrypted value written straight from W
;   enc_char     (1) - merged into enc_tmp (only one needed
;                      at a time throughout the routine)
;   key_cursor   (1) - cursor column = key_count directly
;
; ============================================================
; In-place encryption
; -------------------
; message_buffer is overwritten character by character.
; Each byte is read, encrypted, and written back to the SAME
; index before enc_index advances.  Because no character's
; encryption depends on any later character, overwriting as
; we go is safe and produces identical output to a separate
; buffer.
;
; After Encrypt_Run returns, message_buffer contains the
; encrypted message and lock_counter is unchanged, so the
; UART routines in Proj_UARTOutput.s can transmit it directly.
;
; ============================================================
; Key format
; ----------
;   Digits 1-2 : sub1   substitution index A  (01-26)
;   Digits 3-4 : sub2   substitution index B  (01-26)
;   Digits 5-6 : shift  initial Caesar shift   (01-36)
;   Digits 7-8 : step   shift increment interval (not 00)
;
; Encryption alphabet:
;   Positions  0-25 : A-Z
;   Positions 26-35 : 0-9
;   (36 symbols total)
;
; Non-alphabet characters pass through unchanged.
; ============================================================

; ============================================================
; PUBLIC SYMBOLS
; ============================================================
global  Encrypt_Init
global  Encrypt_Run
    
global  key_digits          ; shared with Proj_Decrypt.s
global  key_count           ; shared with Proj_Decrypt.s
global  enc_sub1            ; shared with Proj_Decrypt.s
global  enc_sub2            ; shared with Proj_Decrypt.s
global  enc_shift           ; shared with Proj_Decrypt.s
global  enc_step            ; shared with Proj_Decrypt.s
global  enc_alpha_pos       ; shared with Proj_Decrypt.s
global  enc_run_shift       ; shared with Proj_Decrypt.s
global  enc_step_cnt        ; shared with Proj_Decrypt.s
global  enc_tmp             ; shared with Proj_Decrypt.s
global	enc_index

; ============================================================
; EXTERNAL SYMBOLS
; ============================================================
extrn   message_buffer      ; 32-byte buffer: read and written in-place
extrn   lock_counter        ; character count, owned by Proj_ReadNokia.s
extrn   LCDClearLine2
extrn   LCD_Send_Byte_D
extrn   LCD_Send_Byte_I
extrn   LCD_delay_ms
extrn   LCD_delay_x4us
extrn   clear_LCD
extrn   KeyPad_Read
    
    
    
extrn	HomePageStart

; ============================================================
; CONSTANTS
; ============================================================
LCD_LINE1_BASE  EQU 0x80
LCD_LINE2_BASE  EQU 0xC0
ALPHA_SIZE      EQU 36
KEY_LEN         EQU 8
LCD_SHIFT_LEFT  EQU 00011000B

; ============================================================
; ACCESS-RAM VARIABLES  (18 bytes total)
; ============================================================
psect   udata_acs

key_digits:     ds 8    ; raw ASCII digits of entered key
key_count:      ds 1    ; digits entered (0-8); also serves as
                        ; LCD echo cursor column (no separate
                        ; key_cursor variable needed)
enc_sub1:       ds 1    ; substitution index A, range 1-26
enc_sub2:       ds 1    ; substitution index B, range 1-26
enc_shift:      ds 1    ; initial Caesar shift, range 1-36
enc_step:       ds 1    ; shift increment interval, range 1-99
enc_index:      ds 1    ; current position in message_buffer
enc_alpha_pos:  ds 1    ; 0-35 alphabet position; 0xFF if not alpha
enc_run_shift:  ds 1    ; running shift (seeds from enc_shift,
                        ; increments by enc_shift every enc_step chars)
enc_step_cnt:   ds 1    ; characters processed in current step interval
enc_tmp:        ds 1    ; scratch byte; also holds current char
                        ; (replaces the separate enc_char variable)

; ============================================================
; CODE
; ============================================================
psect   encrypt_code, class=CODE

; ============================================================
; Encrypt_Init
; ============================================================
; Zero all encryption state.  Call once before Encrypt_Run.
; Does not touch message_buffer or lock_counter.
; ============================================================
Encrypt_Init:
        clrf    key_count,      A
        clrf    enc_sub1,       A
        clrf    enc_sub2,       A
        clrf    enc_shift,      A
        clrf    enc_step,       A
        clrf    enc_index,      A
        clrf    enc_run_shift,  A
        clrf    enc_step_cnt,   A
        clrf    enc_tmp,        A
        return

; ============================================================
; Encrypt_Run
; ============================================================
; Executes all four stages and does not return until the
; encrypted message is displayed on the LCD.
; ============================================================
Encrypt_Run:

        ; --------------------------------------------------
        ; STAGE 1: Prompt and collect 8-digit key
        ; --------------------------------------------------
        call    ENC_PromptKey       ; "ENTER KEY:" on line 1

ENC_KeyEntryLoop:
        call    KeyPad_Read         ; W = ASCII key or 0xFF
        movwf   enc_tmp, A

        movlw   0xFF
        cpfseq  enc_tmp, A          ; skip if nothing pressed
        bra     ENC_GotKey
        bra     ENC_KeyEntryLoop

ENC_GotKey:
        ; Wait for physical release so one press is not
        ; counted multiple times by the fast polling loop
        call    ENC_WaitRelease

        ; ---- 'C' = confirm / submit ----
        movf    enc_tmp, W, A
        xorlw   'C'
        bz      ENC_TryConfirm

        ; ---- 'E' = backspace ----
        movf    enc_tmp, W, A
        xorlw   'E'
        bz      ENC_Backspace
	
	; ---- 'F' = homepage ----
	movlw	'F'
	cpfseq	enc_tmp, A
	bra	$ + 6
	goto	HomePageStart	

        ; ---- Accept only '0'-'9' ----
        ; Upper bound: reject if enc_tmp > '9'
        movf    enc_tmp, W, A
        sublw   '9'
        bnc     ENC_KeyEntryLoop    ; carry=0: enc_tmp > '9', ignore

        ; Lower bound: reject if enc_tmp < '0'
        movf    enc_tmp, W, A
        sublw   '0' - 1
        bc      ENC_KeyEntryLoop    ; carry=1: enc_tmp < '0', ignore

ENC_AcceptDigit:

        ; Ignore extra digits once buffer is full
        movlw   KEY_LEN
        cpfslt  key_count, A
        bra     ENC_KeyEntryLoop

        ; ---- Store digit at key_digits[key_count] ----
        movf    key_count, W, A
        addlw   low(key_digits)
        movwf   FSR0L, A
        movlw   high(key_digits)
        movwf   FSR0H, A
        movf    enc_tmp, W, A
        movwf   INDF0, A

        ; ---- Echo digit on LCD line 2 ----
        ; key_count is the column directly - no key_cursor needed
        movf    key_count, W, A
        addlw   LCD_LINE2_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us
        movf    enc_tmp, W, A
        call    LCD_Send_Byte_D

        incf    key_count, F, A
        bra     ENC_KeyEntryLoop

; ---- Backspace ----
ENC_Backspace:
        movf    key_count, W, A
        bz      ENC_KeyEntryLoop    ; nothing to erase

        decf    key_count, F, A     ; step back (key_count now = erased column)

        ; Blank the erased position on the LCD
        movf    key_count, W, A
        addlw   LCD_LINE2_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us
        movlw   ' '
        call    LCD_Send_Byte_D

        ; Leave cursor at the blank column for next digit
        movf    key_count, W, A
        addlw   LCD_LINE2_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us

        bra     ENC_KeyEntryLoop

; ---- Confirm: require exactly 8 digits ----
ENC_TryConfirm:
        movlw   KEY_LEN
        cpfseq  key_count, A        ; skip if key_count == 8
        bra     ENC_KeyEntryLoop    ; fewer than 8 digits, keep waiting

        ; Fall through to Stage 2

        ; --------------------------------------------------
        ; STAGE 2: Parse and validate the four key fields
        ; --------------------------------------------------

        ; ---- sub1 = digits 0-1, must be 01-26 ----
        call    ENC_ParsePair0
        movwf   enc_sub1, A
        movf    enc_sub1, W, A
        bz      ENC_Invalid
        movlw   37
        cpfslt  enc_sub1, A
        bra     ENC_Invalid

        ; ---- sub2 = digits 2-3, must be 01-26 ----
        call    ENC_ParsePair1
        movwf   enc_sub2, A
        movf    enc_sub2, W, A
        bz      ENC_Invalid
        movlw   37
        cpfslt  enc_sub2, A
        bra     ENC_Invalid

        ; ---- shift = digits 4-5, must be 01-36 ----
        call    ENC_ParsePair2
        movwf   enc_shift, A
;        movf    enc_shift, W, A
;        bz      ENC_Invalid
        movlw   37
        cpfslt  enc_shift, A
        bra     ENC_Invalid

        ; ---- step = digits 6-7, must not be 00 ----
        call    ENC_ParsePair3
        movwf   enc_step, A
        movf    enc_step, W, A
        bz      ENC_Invalid

        bra     ENC_KeyValid

; ---- Invalid key: print error, pause, restart ----
ENC_Invalid:
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

        ; ~2 second pause (8 x 250 ms)
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

        call    Encrypt_Init        ; clear key entry state
        call    clear_LCD
        call    ENC_PromptKey       ; re-display prompt
        bra     ENC_KeyEntryLoop

; ---- Valid key: brief confirmation then encrypt ----
ENC_KeyValid:
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

        ; --------------------------------------------------
        ; STAGE 3: In-place encryption of message_buffer
        ; --------------------------------------------------
        ; For each character at message_buffer[enc_index]:
        ;   1. Read the character into enc_tmp
        ;   2. Convert to 0-35 alphabet position
        ;   3. Apply substitution swap
        ;   4. Apply Caesar shift mod 36
        ;   5. Convert back to ASCII
        ;   6. Write result back to message_buffer[enc_index]
        ; Non-alphabet characters are left unchanged.

        movf    enc_shift, W, A
        movwf   enc_run_shift, A    ; seed running shift
        clrf    enc_step_cnt, A
        clrf    enc_index, A

ENC_EncryptLoop:
        movf    lock_counter, W, A
        cpfslt  enc_index, A
        bra     ENC_EncryptDone     ; processed all characters

        ; ---- Read message_buffer[enc_index] ----
        ; FSR0 is set here and NOT changed until the write-back
        ; below, so INDF0 can be used for both read and write
        lfsr    0, message_buffer
        movf    enc_index, W, A
        addwf   FSR0L, F, A
        movlw   0
        addwfc  FSR0H, F, A
        movf    INDF0, W, A         ; W = plaintext char
        movwf   enc_tmp, A          ; enc_tmp = current character

        ; ---- Step 1: alphabet position ----
        call    ENC_CharToPos       ; enc_alpha_pos = 0-35 or 0xFF

        movf    enc_alpha_pos, W, A
        xorlw   0xFF
        bz      ENC_SkipEncrypt     ; not in alphabet, leave unchanged

        ; ---- Step 2: substitution swap ----
        movf    enc_sub1, W, A
        addlw   -1                  ; sub1_pos = enc_sub1 - 1
        cpfseq  enc_alpha_pos, A
        bra     ENC_CheckSub2

        ; Matched sub1: swap to sub2
        movf    enc_sub2, W, A
        addlw   -1
        movwf   enc_alpha_pos, A
        bra     ENC_DoneSubstitution

ENC_CheckSub2:
        movf    enc_sub2, W, A
        addlw   -1                  ; sub2_pos = enc_sub2 - 1
        cpfseq  enc_alpha_pos, A
        bra     ENC_DoneSubstitution

        ; Matched sub2: swap to sub1
        movf    enc_sub1, W, A
        addlw   -1
        movwf   enc_alpha_pos, A

ENC_DoneSubstitution:

        ; ---- Step 3: Caesar shift mod 36 ----
        movf    enc_run_shift, W, A
        addwf   enc_alpha_pos, W, A ; W = shifted position (may be >= 36)
        movwf   enc_tmp, A          ; reuse enc_tmp for reduction

ENC_ModLoop:
        movlw   ALPHA_SIZE          ; 36
        cpfslt  enc_tmp, A          ; skip if enc_tmp < 36
        bra     ENC_ModReduce
        bra     ENC_ModDone

ENC_ModReduce:
        movlw   ALPHA_SIZE
        subwf   enc_tmp, F, A       ; enc_tmp -= 36
        bra     ENC_ModLoop

ENC_ModDone:
        ; ---- Step 4: convert position back to ASCII ----
        movf    enc_tmp, W, A
        call    ENC_PosToChar       ; W = encrypted ASCII character

        ; ---- Step 5: write back to message_buffer[enc_index] ----
        ; FSR0 still points to message_buffer[enc_index] from above
        movwf   INDF0, A            ; overwrite plaintext with ciphertext
        bra     ENC_UpdateShift

ENC_SkipEncrypt:
        ; Character not in alphabet: INDF0 already holds the
        ; original value and enc_tmp was not modified after the
        ; CharToPos call, so no write is needed

ENC_UpdateShift:
        ; ---- Update running shift every enc_step characters ----
        incf    enc_step_cnt, F, A
        movf    enc_step, W, A
        cpfseq  enc_step_cnt, A
        bra     ENC_NoShiftUpdate

        ; Increment running shift by 1 and wrap 36 -> 1
        incf    enc_run_shift, F, A ; enc_run_shift += 1
        movlw   ALPHA_SIZE + 1      ; 37
        cpfseq  enc_run_shift, A    ; skip if enc_run_shift == 37
        bra     ENC_ShiftWrapDone
        movlw   1                   ; wrap: 37 -> 1
        movwf   enc_run_shift, A

ENC_ShiftWrapDone:
        clrf    enc_step_cnt, A

ENC_NoShiftUpdate:
        incf    enc_index, F, A
        bra     ENC_EncryptLoop

ENC_EncryptDone:

        ; --------------------------------------------------
        ; STAGE 4: Display encrypted message_buffer on LCD
        ; --------------------------------------------------
        call    ENC_DisplayResult
        return

; ============================================================
; ENC_DisplayResult
; ============================================================
; Clears LCD, prints "ENC:" label on line 2, then displays
; the (now encrypted) message_buffer contents on line 1.
; Uses the same left-shift mechanism as Proj_NokiaLCD.s for
; messages longer than 16 characters.
; ============================================================
ENC_DisplayResult:
        call    clear_LCD

        ; "ENC:" label on LINE 1
        movlw   LCD_LINE1_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us
        movlw   'E'
        call    LCD_Send_Byte_D
        movlw   'N'
        call    LCD_Send_Byte_D
        movlw   'C'
        call    LCD_Send_Byte_D
        movlw   ':'
        call    LCD_Send_Byte_D

        ; Encrypted message on LINE 2
        movlw   LCD_LINE2_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us

        ; Save lock_counter into enc_step_cnt before the loop.
        ; enc_step_cnt is idle during display (only used during
        ; encryption which is now complete).  This protects the
        ; loop bound against any side-effects from LCD routines
        ; that might read or modify lock_counter internally.
        movf    lock_counter, W, A
        movwf   enc_step_cnt, A

        clrf    enc_index, A

ENC_DisplayLoop:
        movf    enc_step_cnt, W, A      ; compare against saved copy
        cpfslt  enc_index, A
        return

        ; Load message_buffer[enc_index] (now contains encrypted char)
        lfsr    0, message_buffer
        movf    enc_index, W, A
        addwf   FSR0L, F, A
        movlw   0
        addwfc  FSR0H, F, A
        movf    INDF0, W, A
        movwf   enc_tmp, A              ; stash before LCD calls clobber W

        ; Characters 0-15: print at natural cursor position on line 2
        movlw   16
        cpfslt  enc_index, A
        bra     ENC_ShiftAndPrint

        movf    enc_tmp, W, A
        call    LCD_Send_Byte_D
        bra     ENC_DisplayNext

ENC_ShiftAndPrint:
        ; Shift display left one position
        movlw   LCD_SHIFT_LEFT
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us

        ; Reposition cursor to line 2 right edge
        movf    enc_index, W, A
        addlw   LCD_LINE2_BASE
        call    LCD_Send_Byte_I
        movlw   10
        call    LCD_delay_x4us

        movf    enc_tmp, W, A
        call    LCD_Send_Byte_D

ENC_DisplayNext:
        incf    enc_index, F, A
        bra     ENC_DisplayLoop

; ============================================================
; ENC_PromptKey
; ============================================================
ENC_PromptKey:
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
; ENC_WaitRelease
; ============================================================
; Spin until keypad returns 0xFF (key released).
; Clobbers enc_tmp.
; ============================================================
ENC_WaitRelease:
        call    KeyPad_Read
        addlw   1                   ; 0xFF + 1 = 0x00, sets Z flag if released
        bnz     ENC_WaitRelease     ; not released yet, keep waiting
        return

; ============================================================
; ENC_Mul10
; ============================================================
; Multiply W by 10 via repeated addition.
; Input: W = digit 0-9.  Output: W = digit * 10.
; Uses enc_tmp, enc_alpha_pos, enc_step_cnt as scratch.
; Safe to call during key parsing (before encryption starts).
; ============================================================
ENC_Mul10:
        movwf   enc_tmp, A          ; save original digit
        clrf    enc_alpha_pos, A    ; accumulator
        movlw   10
        movwf   enc_step_cnt, A     ; loop counter
ENC_Mul10Loop:
        movf    enc_tmp, W, A
        addwf   enc_alpha_pos, F, A
        decfsz  enc_step_cnt, F, A
        bra     ENC_Mul10Loop
        movf    enc_alpha_pos, W, A ; W = digit * 10
        return

; ---- ParsePair0: key_digits[0..1] ----
ENC_ParsePair0:
        movf    key_digits + 0, W, A
        addlw   -'0'
        call    ENC_Mul10
        movwf   enc_tmp, A
        movf    key_digits + 1, W, A
        addlw   -'0'
        addwf   enc_tmp, W, A
        return

; ---- ParsePair1: key_digits[2..3] ----
ENC_ParsePair1:
        movf    key_digits + 2, W, A
        addlw   -'0'
        call    ENC_Mul10
        movwf   enc_tmp, A
        movf    key_digits + 3, W, A
        addlw   -'0'
        addwf   enc_tmp, W, A
        return

; ---- ParsePair2: key_digits[4..5] ----
ENC_ParsePair2:
        movf    key_digits + 4, W, A
        addlw   -'0'
        call    ENC_Mul10
        movwf   enc_tmp, A
        movf    key_digits + 5, W, A
        addlw   -'0'
        addwf   enc_tmp, W, A
        return

; ---- ParsePair3: key_digits[6..7] ----
ENC_ParsePair3:
        movf    key_digits + 6, W, A
        addlw   -'0'
        call    ENC_Mul10
        movwf   enc_tmp, A
        movf    key_digits + 7, W, A
        addlw   -'0'
        addwf   enc_tmp, W, A
        return

; ============================================================
; ENC_CharToPos
; ============================================================
; Converts the character in enc_tmp to a 0-35 alphabet
; position stored in enc_alpha_pos.
; Returns 0xFF in enc_alpha_pos if not in A-Z or 0-9.
; ============================================================
ENC_CharToPos:
        ; sublw 'A'-1 computes W = ('A'-1) - enc_tmp
        ; Borrow (carry=0) occurs when enc_tmp >= 'A'
        ; carry=0 (bnc) means enc_tmp >= 'A': it may be a letter, fall through
        ; carry=1 (bc)  means enc_tmp <  'A': below letters, check digits
        movf    enc_tmp, W, A
        sublw   'A' - 1
        bc      ENC_CheckDigit      ; carry=1: enc_tmp < 'A', not a letter

        ; sublw 'Z' computes W = 'Z' - enc_tmp
        ; Borrow (carry=0) occurs when enc_tmp > 'Z'
        ; carry=0 (bnc) means enc_tmp > 'Z': above letters, not alpha
        movf    enc_tmp, W, A
        sublw   'Z'
        bnc     ENC_NotAlpha        ; carry=0: enc_tmp > 'Z', not a letter

        ; enc_tmp is in 'A'-'Z': position = enc_tmp - 'A' (0-25)
        movf    enc_tmp, W, A
        addlw   -'A'
        movwf   enc_alpha_pos, A
        return

ENC_CheckDigit:
        ; sublw '0'-1 computes W = ('0'-1) - enc_tmp
        ; Borrow (carry=0) occurs when enc_tmp >= '0'
        ; carry=1 (bc) means enc_tmp < '0': below digits, not alpha
        movf    enc_tmp, W, A
        sublw   '0' - 1
        bc      ENC_NotAlpha        ; carry=1: enc_tmp < '0', not a digit

        ; sublw '9' computes W = '9' - enc_tmp
        ; Borrow (carry=0) occurs when enc_tmp > '9'
        ; carry=0 (bnc) means enc_tmp > '9': above digits, not alpha
        movf    enc_tmp, W, A
        sublw   '9'
        bnc     ENC_NotAlpha        ; carry=0: enc_tmp > '9', not a digit

        ; enc_tmp is in '0'-'9': position = 26 + (enc_tmp - '0') (26-35)
        movf    enc_tmp, W, A
        addlw   -'0'
        addlw   26
        movwf   enc_alpha_pos, A
        return

ENC_NotAlpha:
        movlw   0xFF
        movwf   enc_alpha_pos, A
        return

; ============================================================
; ENC_PosToChar
; ============================================================
; Converts 0-35 position in W back to ASCII character in W.
; Clobbers enc_tmp.
; ============================================================
ENC_PosToChar:
        movwf   enc_tmp, A
        movlw   26
        cpfslt  enc_tmp, A
        bra     ENC_PosIsDigit
        movf    enc_tmp, W, A
        addlw   'A'
        return
ENC_PosIsDigit:
        movf    enc_tmp, W, A
        addlw   -26
        addlw   '0'
        return

        end

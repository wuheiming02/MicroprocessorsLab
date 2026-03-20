#include <xc.inc>

; from NokiaTimer
extrn	TimerSetup, TimerInterrupt

; from KeyPad
extrn   KeyPad_Init, KeyPad_Read

; from LCD
extrn   LCD_Setup
extrn	LCD_Send_Byte_I
extrn   LCD_Send_Byte_D
extrn   clear_LCD
extrn	LCD_delay_x4us
extrn	LCD_delay_ms

; from DecodeNokia    
extrn	DecodeChar
    
; from NokiaLCD
extrn	shift_counter
extrn	LCDPrintDecoded
extrn   ShiftCursorRight
extrn   LCDPrintOverflow
extrn	LCDClearLine2
    
; from HomePage
extrn	HomePageStart
    
extrn	timer_counter
extrn	current_state
extrn	last_state
extrn	current_key
extrn	decoded_char
    
; from Encryption, UART
extrn	UART_Setup
extrn	UART_Out_Plain
extrn	UART_Out_Encrypted
extrn	UART_Out_Key
extrn	Encrypt_Init
extrn	Encrypt_Run
    
extrn	enc_index           ; reused as morse_index (idle after encryption)
extrn	enc_alpha_pos       ; reused as morse_bits  (idle after encryption)
extrn	enc_tmp             ; reused as morse_char  (idle after encryption)
extrn	enc_step_cnt        ; reused as morse_len   (idle after encryption)
extrn	UART_counter        ; reused as morse_bit_cnt (idle after UART send)
   
    
global	lock_counter, key_counter, message_buffer
global	NokiaStart

psect	udata_acs
last_key:	ds 1 ; last key that was pressed
lock_counter:	ds 1 ; number of characters stored in message_buffer
key_counter:	ds 1 ; number of times a key is pressed consecutively
message_buffer: ds 32 ; stores all locked characters
    
psect	read_nokia, class=CODE
	
NokiaStart:
	clrf	timer_counter, A
	clrf	current_state, A
	clrf	last_state, A
	clrf	current_key, A
	clrf	last_key, A
	clrf	lock_counter, A
	clrf	key_counter, A
	clrf	decoded_char, A

	clrf	shift_counter, A
	
	call    LCD_Setup
	call    clear_LCD
	
	call    KeyPad_Init
	
	call	UART_Setup
	call	Encrypt_Init
	
SetupWaitLoop:
; program starts when a numeric key is pressed
	call	KeyPad_Read
	movwf	last_key, A
	
	movlw	'F' ; if 'F' is pressed branch to ExecF
	cpfseq	last_key, A
	bra	$ + 6
	goto	ExecF
	
	movlw	'E' ; if 'E' is pressed branch to ExecE
	cpfseq	last_key, A
	bra	$ + 6
	goto	ExecE
	
	movlw	'C' ; if 'C' is pressed branch to ExecC
	cpfseq	last_key, A
	bra	$ + 6
	goto	ExecC
	
	movlw	'D' ; if 'D' is pressed branch to ExecD
	cpfseq	last_key, A
	bra	$ + 6
	goto	ExecD
	
	bra	EntryCheckHigh
	
EntryCheckHigh:
	movlw	'9'
	cpfsgt	last_key, A
	bra	EntryCheckLow
	
	bra	SetupWaitLoop
	
EntryCheckLow:
	movlw	'0'
	cpfslt	last_key, A
	bra	MainLoop
	
	bra	SetupWaitLoop

MainLoop:
	movlw	32 ; check if there are already 32 decoded characters
	cpfseq	lock_counter, A
	bra	$ + 6
	goto	Overflow ; if yes branch to Overflow
    
	call	KeyPad_Read
	movwf	current_key, A ; store key in current_key
	
	movf	current_key, W, A ; if key is not pressed
	xorlw	0xFF
	bz	KeyReleased ; branch to KeyReleased
	
	movlw	'F' ; if 'F' is pressed branch to ExecF
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecF
	
	movlw	'E' ; if 'E' is pressed branch to ExecE
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecE
	
	movlw	'C' ; if 'C' is pressed branch to ExecC
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecC
	
	movlw	'D' ; if 'D' is pressed branch to ExecD
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecD
	
	bra	CheckHigh ; check if current_key is numeric, else branch back to MainLoop
	
CheckHigh:
	movlw	'9'
	cpfsgt	current_key, A
	bra	CheckLow
	
	bra	MainLoop 
	
CheckLow:
	movlw	'0'
	cpfslt	current_key, A
	bra	KeyPressed ; else branch to KeyPressed
	
	goto	MainLoop
	
KeyReleased:
	movff	last_key, current_key ; copy last_key to current_key
	clrf	current_state, A ; set current_state to 0
	bra	CheckState ; branch to CheckState
	
KeyPressed:
	movlw	1 ; set current_state to 1
	movwf	current_state, A
	bra	CheckState ; branch to CheckState
	
CheckState:
	movf	current_state, W, A ; compare current_state to last_state
	cpfseq	last_state, A
	bra	StateChange ; branch to StateChange if there is a state change
	
	movf	current_state, W, A ; if no state change check current_state
	bz	CheckTimer ; if current_state is 0 branch to CheckTimer
	goto	MainLoop ; else branch back to MainLoop
	
StateChange:
	movff	current_state, last_state ; copy current_state into last_state
	movf	current_state, W, A ; check current_state
	bz	ResetTimer ; if current_state is 0 branch to ResetTimer
	
	bra	NumericKey ; else branch to NumericKey
	
ResetTimer:
	clrf	timer_counter, A ; set timer_counter to 0
	call	TimerSetup ; setup timer
	goto	MainLoop ; branch back to MainLoop
	
CheckTimer:
	movlw	5 ; check if no key is pressed for less than 6 units of time (1500ms)
	cpfsgt	timer_counter, A 
	goto	MainLoop ; if yes branch back to MainLoop
	
	call	LockChar ; else lock the current character
	goto	SetupWaitLoop ; branch to SetupWaitLoop
	
NumericKey:
	movf	current_key, W, A ; check if the current key is the same as the last key
	cpfseq	last_key, A
	call	LockChar ; if no lock the current character
	
	bra	SameKey ; if yes branch to SameKey
    
SameKey:
	movff	current_key, last_key ; copy current_key into last_key
	
	; branch to specific branches for specific key
	movf    current_key, W, A
        xorlw   '0'
        bz      Exec0

        movf    current_key, W, A
        xorlw   '1'
        bz      Exec1

        movf    current_key, W, A
        xorlw   '2'
        bz      Exec234568
        movf    current_key, W, A
        xorlw   '3'
        bz      Exec234568
        movf    current_key, W, A
        xorlw   '4'
        bz      Exec234568
        movf    current_key, W, A
        xorlw   '5'
        bz      Exec234568
        movf    current_key, W, A
        xorlw   '6'
        bz      Exec234568
        movf    current_key, W, A
        xorlw   '8'
        bz      Exec234568

        movf    current_key, W, A
        xorlw   '7'
        bz      Exec79
        movf    current_key, W, A
        xorlw   '9'
        bz      Exec79
	
	goto	MainLoop ; else branch back to MainLoop
	
; Numeric key branches	
Exec0:
	incf	key_counter, A
	movlw	3
	cpfslt	key_counter, A
	call	CounterWrap
	
	goto	DecodeKey
	  
Exec1:
	incf	key_counter, A
	movlw	2
	cpfslt	key_counter, A
	call	CounterWrap
	
	goto	DecodeKey
 
Exec234568:
	incf	key_counter, A
	movlw	5
	cpfslt	key_counter, A
	call	CounterWrap
	
	goto	DecodeKey
    
Exec79:
	incf	key_counter, A
	movlw	6
	cpfslt	key_counter, A
	call	CounterWrap
	
	goto	DecodeKey
    
CounterWrap: ; wrap key_counter back to 1
	movlw	1
	movwf	key_counter, A
	return
	
DecodeKey:
	call	DecodeChar ; decode character
	movwf	decoded_char, A ; store decoded character into decoded_char
	call	LCDPrintDecoded ; display character to LCD line 1
	goto	MainLoop ; branch back to MainLoop

LockChar: 
	; load decoded_char into message buffer
	lfsr    0, message_buffer
	movf    lock_counter, W, A
	addwf   FSR0L, F, A
	movlw   0
	addwfc  FSR0H, F, A

	movf    decoded_char, W, A
	movwf   INDF0, A
    
	clrf	key_counter, A ; set key_counter to 0
	clrf	timer_counter, A ; set timer_counter to 0
	incf	lock_counter, A ; increment lock_counter
	call	ShiftCursorRight ; shift cursor right
	
	return
	
Overflow:
	call	LCDPrintOverflow ; displays 'OVERFLOW' on LCD line 2
	
OverflowWaitLoop:
	call	KeyPad_Read ; only break loop if specific keys are pressed
	movwf	current_key, A
	
	movlw	'F' ; if 'F' is pressed branch to ExecF
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecF
	
	movlw	'E' ; if 'E' is pressed branch to ExecE
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecE
	
	movlw	'C' ; if 'C' is pressed branch to ExecC
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecC
	
	movlw	'D' ; if 'D' is pressed branch to ExecD
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecD
	
	bra	OverflowWaitLoop
	
ExecF:
    	call	KeyPad_Read ; wait till key is released
	xorlw	0xFF
	bz	GotoHomepage
	
	bra	ExecF
	
GotoHomepage:
	call	clear_LCD ; clears LCD
	goto	HomePageStart ; go back to home page
	
ReadBufferChar:
	lfsr    0, message_buffer
	addwf   FSR0L, F, A
	movlw   0
	addwfc  FSR0H, F, A
	movf    INDF0, W, A
	return
	
ExecE:
	call	KeyPad_Read
	xorlw	0xFF
	bz	BackSpaceFunc
	bra	ExecE
	
BackSpaceFunc:
	call	LCDClearLine2
	movf	key_counter, W, A
	bz	BackSpaceLock
	
	
	movlw	0x80
	addwf	lock_counter, W, A
	call    LCD_Send_Byte_I
	movlw   10
	call    LCD_delay_x4us
	
	movlw	' '
	call	LCD_Send_Byte_D
	
	movlw   00010000B ; shift cursor left by 1
	call    LCD_Send_Byte_I
	movlw   10
	call    LCD_delay_x4us
	
	clrf	key_counter, A
	
	bra	BackSpaceDone
BackSpaceLock:
	movf	lock_counter, W, A
	bz	BackSpaceDone
	
	decf	lock_counter, F, A
	
	movlw	0x80
	addwf	lock_counter, W, A
	call    LCD_Send_Byte_I
	movlw   10
	call    LCD_delay_x4us
	
	movlw	' '
	call	LCD_Send_Byte_D
	
	movlw   00010000B ; shift cursor left by 1
	call    LCD_Send_Byte_I
	movlw   10
	call    LCD_delay_x4us
	
	movf	shift_counter, W, A
	bz	BackSpaceDone
	
	movlw   00011100B
	call    LCD_Send_Byte_I
	movlw   10
	call    LCD_delay_x4us 
	decf    shift_counter, F, A ; decrement shift counter
	
BackSpaceDone:
	clrf	current_state, A
	goto	SetupWaitLoop
	
ExecC:
	call	KeyPad_Read ; wait till key is released
	xorlw	0xFF
	bz	SendEncryptedMessage
	
	bra	ExecC
	
SendEncryptedMessage:    
	movf	lock_counter, W, A
	bz	SetupWaitLoop
	
	call	Encrypt_Init
	call	Encrypt_Run
	call	MorseSend
	call	UART_Out_Key
	call	UART_Out_Encrypted
	bra	GotoHomepage
	
ExecD:
	call	KeyPad_Read ; wait till key is released
	xorlw	0xFF
	bz	SendPlainMessage
	
	bra	ExecD
	
SendPlainMessage:
	movf	lock_counter, W, A
	bz	SetupWaitLoop
	
	call	UART_Out_Plain
	bra	GotoHomepage
	
MorseSend:
        clrf    enc_index, A        ; morse_index = 0

MorseSend_CharLoop:
        ; ---- Stop when all characters sent ----
        movf    lock_counter, W, A
        cpfslt  enc_index, A
        bra     MorseSend_End

        ; ---- Load message_buffer[enc_index] ----
        lfsr    0, message_buffer
        movf    enc_index, W, A
        addwf   FSR0L, F, A
        movlw   0
        addwfc  FSR0H, F, A
        movf    INDF0, W, A
        movwf   enc_tmp, A          ; morse_char = current character
	
	movlw	' '
	cpfseq	enc_tmp, A
	bra	$ + 6
	goto	MorseSend_Space

        ; ---- Look up Morse pattern for this character ----
        call    MorseLookup         ; loads enc_alpha_pos=bits, enc_step_cnt=len
                                    ; if enc_step_cnt == 0 character is skipped

        movf    enc_step_cnt, W, A
        bz      MorseSend_NextChar  ; 0 length = unsupported char, skip

        ; ---- Send each dot/dash for this character ----
        movff   enc_step_cnt, UART_counter ; morse_bit_cnt = morse_len

MorseSend_BitLoop:
        ; Test MSB of enc_alpha_pos (morse_bits)
        ; rlcf shifts MSB into carry
        bcf     STATUS, 0, A        ; clear carry
        rlcf    enc_alpha_pos, F, A ; MSB -> carry, pattern shifts left

        btfss   STATUS, 0, A        ; skip if carry set (dash)
        bra     MorseSend_Dot

MorseSend_Dash:
        movlw   '-'
        call    MorseUARTByte
        bra     MorseSend_SymbolDone

MorseSend_Dot:
        movlw   '.'
        call    MorseUARTByte
	bra	MorseSend_SymbolDone
	
MorseSend_Space:
	movlw	' '
	call	MorseUARTByte
	movlw	'/'
	call	MorseUARTByte
	movlw	' '
	call	MorseUARTByte
	bra	MorseSend_NextChar

MorseSend_SymbolDone:
;        movlw   ' '                 ; space between symbols
;        call    MorseUARTByte

        decfsz  UART_counter, F, A
        bra     MorseSend_BitLoop

        ; ---- Send '/' separator between characters ----
;        movlw   '/'
;        call    MorseUARTByte
        movlw   ' '
        call    MorseUARTByte

MorseSend_NextChar:
        incf    enc_index, F, A
        bra     MorseSend_CharLoop

MorseSend_End:
        ; ---- Terminate with CR LF ----
        movlw   0x0D
        call    MorseUARTByte
        movlw   0x0A
        call    MorseUARTByte
        return

; ============================================================
; MorseUARTByte  (private)
; ============================================================
; Transmit single byte in W directly via UART.
; Polls TXIF until transmit register is empty.
; ============================================================
MorseUARTByte:
        btfss   TX1IF               ; wait until TXREG1 is empty
        bra     MorseUARTByte
        movwf   TXREG1, A
        return

; ============================================================
; MorseLookup  (private)
; ============================================================
; Given the ASCII character in enc_tmp, loads:
;   enc_alpha_pos = bit pattern (MSB-first, 0=dot 1=dash)
;   enc_step_cnt  = number of symbols (0 if unsupported)
;
; Supported characters: A-Z (letters), 0-9 (digits)
; All others: enc_step_cnt set to 0 (caller skips them)
;
; Table layout (MorseTable in Flash):
;   Two bytes per entry: [bit_pattern, length]
;   Entries 0-25:  A-Z
;   Entries 26-35: 0-9
;
; Bit pattern encoding:
;   Symbols are stored in the HIGH bits of the byte.
;   e.g. 'A' = .- = 01 stored as 01xxxxxx = 0x40, length 2
;   e.g. 'E' = .  = 0  stored as 0xxxxxxx = 0x00, length 1
;   e.g. 'T' = -  = 1  stored as 1xxxxxxx = 0x80, length 1
;
; The MorseSend loop reads MSB first via rlcf, so the pattern
; must be left-aligned in the byte.
; ============================================================
MorseLookup:
        ; ---- Check A-Z ----
        movf    enc_tmp, W, A
        sublw   'A' - 1
        bc      ML_CheckDigit       ; carry=1: below 'A'

        movf    enc_tmp, W, A
        sublw   'Z'
        bnc     ML_Unsupported      ; carry=0: above 'Z'

        movf    enc_tmp, W, A
        addlw   -'A'                ; index 0-25
        bra     ML_Lookup

ML_CheckDigit:
        movf    enc_tmp, W, A
        sublw   '0' - 1
        bc      ML_Unsupported      ; carry=1: below '0'

        movf    enc_tmp, W, A
        sublw   '9'
        bnc     ML_Unsupported      ; carry=0: above '9'

        movf    enc_tmp, W, A
        addlw   -'0'
        addlw   26                  ; index 26-35

ML_Lookup:
        ; W = table index (0-35)
        ; Each entry is 2 bytes so multiply index by 2
        ; Use addwf trick: save index, add to itself
        movwf   enc_step_cnt, A     ; save index temporarily
        addwf   enc_step_cnt, W, A  ; W = index * 2

        ; Load TBLPTR with address of MorseTable
        movwf   enc_alpha_pos, A    ; save byte offset
        movlw   low(MorseTable)
        movwf   TBLPTRL, A
        movlw   high(MorseTable)
        movwf   TBLPTRH, A
        movlw   low highword(MorseTable)
        movwf   TBLPTRU, A

        ; Add byte offset to TBLPTR
        movf    enc_alpha_pos, W, A
        addwf   TBLPTRL, F, A
        movlw   0
        addwfc  TBLPTRH, F, A
        addwfc  TBLPTRU, F, A

        ; Read bit pattern (first byte of entry)
        tblrd*+
        movff   TABLAT, enc_alpha_pos ; morse_bits = pattern

        ; Read length (second byte of entry)
        tblrd*
        movff   TABLAT, enc_step_cnt  ; morse_len = length
        return

ML_Unsupported:
        clrf    enc_alpha_pos, A
        clrf    enc_step_cnt, A     ; length 0 signals skip
        return

; ============================================================
; MorseTable  -  Morse code bit patterns in Flash
; ============================================================
; Two bytes per character: [pattern, length]
; Pattern is left-aligned: MSB is first symbol
; 0 = dot, 1 = dash
;
; Letters A-Z (indices 0-25):
;   A .-    01000000 2    N -.    10000000 2
;   B -...  10000000 4    O ---   11100000 3
;   C -.-.  10100000 4    P .--.  01100000 4
;   D -..   10000000 3    Q --.-  11010000 4
;   E .     00000000 1    R .-.   01000000 3
;   F ..-.  00100000 4    S ...   00000000 3
;   G --.   11000000 3    T -     10000000 1
;   H ....  00000000 4    U ..-   00100000 3
;   I ..    00000000 2    V ...-  00010000 4
;   J .---  01110000 4    W .--   01100000 3
;   K -.-   10100000 3    X -..-  10010000 4
;   L .-..  01000000 4    Y -.--  10110000 4
;   M --    11000000 2    Z --..  11000000 4
;
; Digits 0-9 (indices 26-35):
;   0 -----  11111000 5
;   1 .----  01111000 5
;   2 ..---  00111000 5
;   3 ...--  00011000 5
;   4 ....-  00001000 5
;   5 .....  00000000 5
;   6 -....  10000000 5
;   7 --...  11000000 5
;   8 ---..  11100000 5
;   9 ----.  11110000 5
; ============================================================
psect   data
MorseTable:
    ; A-Z
    db  0x40, 2     ; A .-
    db  0x80, 4     ; B -...
    db  0xA0, 4     ; C -.-.
    db  0x80, 3     ; D -..
    db  0x00, 1     ; E .
    db  0x20, 4     ; F ..-.
    db  0xC0, 3     ; G --.
    db  0x00, 4     ; H ....
    db  0x00, 2     ; I ..
    db  0x70, 4     ; J .---
    db  0xA0, 3     ; K -.-
    db  0x40, 4     ; L .-..
    db  0xC0, 2     ; M --
    db  0x80, 2     ; N -.
    db  0xE0, 3     ; O ---
    db  0x60, 4     ; P .--.
    db  0xD0, 4     ; Q --.-
    db  0x40, 3     ; R .-.
    db  0x00, 3     ; S ...
    db  0x80, 1     ; T -
    db  0x20, 3     ; U ..-
    db  0x10, 4     ; V ...-
    db  0x60, 3     ; W .--
    db  0x90, 4     ; X -..-
    db  0xB0, 4     ; Y -.--
    db  0xC0, 4     ; Z --..
    ; 0-9
    db  0xF8, 5     ; 0 -----
    db  0x78, 5     ; 1 .----
    db  0x38, 5     ; 2 ..---
    db  0x18, 5     ; 3 ...--
    db  0x08, 5     ; 4 ....-
    db  0x00, 5     ; 5 .....
    db  0x80, 5     ; 6 -....
    db  0xC0, 5     ; 7 --...
    db  0xE0, 5     ; 8 ---..
    db  0xF0, 5     ; 9 ----.
    align 2
	
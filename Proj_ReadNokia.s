#include <xc.inc>

; from NokiaTimer
extrn	TimerSetup, TimerInterrupt

; from KeyPad
extrn   KeyPad_Init, KeyPad_Read

; from LCD    
extrn   LCD_Setup
extrn   LCD_Send_Byte_D
extrn   clear_LCD
extrn	LCD_delay_ms

; from DecodeNokia    
extrn	DecodeChar
    
; from NokiaLCD
extrn	shift_counter
extrn	LCDPrintDecoded
extrn   ShiftCursorRight
extrn   LCDPrintOverflow
    
; from HomePage
extrn	HomePageStart
    
extrn	timer_counter
extrn	current_state
extrn	last_state
extrn	current_key
extrn	decoded_char
    
global	lock_counter, key_counter
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
	
SetupWaitLoop:
; program starts when a numeric key is pressed
	call	KeyPad_Read
	
	movwf	last_key, A
	
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
	movlw	32 ; check if there are already 32 characters in message buffer
	cpfslt	lock_counter, A
	bra	Overflow ; if yes branch to Overflow
    
	call	KeyPad_Read
	movwf	current_key, A ; store key in current_key
	
	movf	current_key, W, A ; if key is not pressed
	xorlw	0xFF
	bz	KeyReleased ; branch to KeyReleased
	
	movf	current_key, W, A ; if 'F' is pressed branch to ExecF
	xorlw	'F'
	bz	ExecF
	
	bra	CheckHigh ; check if current_key is numeric, else branch back to MainLoop
	
CheckHigh:
	movlw	'9'
	cpfsgt	current_key, A
	bra	CheckLow
	
	bra	MainLoop 
	
CheckLow:
	movlw	'0'
	cpfslt	last_key, A
	bra	MainLoop
	
	bra	KeyPressed ; else branch to KeyPressed
	
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
	bra	MainLoop ; else branch back to MainLoop
	
StateChange:
	movff	current_state, last_state ; copy current_state into last_state
	movf	current_state, W, A ; check current_state
	bz	ResetTimer ; if current_state is 0 branch to ResetTimer
	
	bra	NumericKey ; else branch to NumericKey
	
ResetTimer:
	clrf	timer_counter, A ; set timer_counter to 0
	call	TimerSetup ; setup timer
	bra	MainLoop ; branch back to MainLoop
	
CheckTimer:
	movlw	5 ; check if no key is pressed for less than 6 units of time (1500ms)
	cpfsgt	timer_counter, A 
	bra	MainLoop ; if yes branch back to MainLoop
	
	call	LockChar ; else lock the current character
	bra	SetupWaitLoop ; branch to SetupWaitLoop
	
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
	
	bra	MainLoop ; else branch back to MainLoop
	
; Numeric key branches	
Exec0:
	incf	key_counter, A
	movlw	3
	cpfslt	key_counter, A
	call	CounterWrap
	
	bra	DecodeKey
	  
Exec1:
	incf	key_counter, A
	movlw	2
	cpfslt	key_counter, A
	call	CounterWrap
	
	bra	DecodeKey
 
Exec234568:
	incf	key_counter, A
	movlw	5
	cpfslt	key_counter, A
	call	CounterWrap
	
	bra	DecodeKey
    
Exec79:
	incf	key_counter, A
	movlw	6
	cpfslt	key_counter, A
	call	CounterWrap
	
	bra	DecodeKey
    
CounterWrap: ; wrap key_counter back to 1
	movlw	1
	movwf	key_counter, A
	return
	
DecodeKey:
	call	DecodeChar ; decode character
	movwf	decoded_char, A ; store decoded character into decoded_char
	call	LCDPrintDecoded ; display character to LCD line 1
	bra	MainLoop ; branch back to MainLoop

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
	
	movf	current_key, W, A
	xorlw	'F' 
	bz	ExecF ; restarts program
	
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
    

#include <xc.inc>

extrn	TimerSetup, TimerInterrupt

extrn   KeyPad_Init, KeyPad_Read

extrn   LCD_Setup
extrn   LCD_Send_Byte_D
extrn   clear_LCD
extrn	LCD_delay_ms

extrn	DecodeChar
    
extrn	shift_counter
extrn	LCDPrintDecoded, ShiftCursorRight, LCDPrintOverflow
    
global	timer_counter, lock_counter, key_counter, current_key

psect	udata_acs
timer_counter:	ds 1 
current_state:	ds 1 
last_state:	ds 1 
current_key:	ds 1 
last_key:	ds 1
lock_counter:	ds 1
key_counter:	ds 1
decoded_char:	ds 1
message_buffer: ds 32 

    
psect	code, abs
	
rst:
	org	0x0000	; reset vector
	goto	start

int_hi:
	org	0x0008	; high vector, no low vector
	goto	TimerInterrupt
	
start:
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
	movlw	32
	cpfslt	lock_counter, A
	bra	Overflow	
    
	call	KeyPad_Read
	movwf	current_key, A
	
	xorlw	0xFF
	bz	KeyReleased
	
	bra	KeyPressed
	
KeyReleased:
	movff	last_key, current_key
	clrf	current_state, A
	bra	CheckState
	
KeyPressed:
	movlw	1
	movwf	current_state, A
	bra	CheckState
	
CheckState:
	movf	current_state, W, A
	cpfseq	last_state, A
	bra	StateChange
	
	movf	current_state, W, A
	bz	CheckTimer
	bra	MainLoop
	
StateChange:
	movff	current_state, last_state
	movf	current_state, W, A
	bz	ResetTimer
	
	bra	NumericKey
	
ResetTimer:
	clrf	timer_counter, A
	call	TimerSetup
	bra	MainLoop
	
CheckTimer:
	movlw	5
	cpfsgt	timer_counter, A
	bra	MainLoop
	
	call	LockChar
	bra	SetupWaitLoop
	
NumericKey:
	movf	current_key, W, A
	cpfseq	last_key, A
	call	LockChar
	
	bra	SameKey
    
SameKey:
	movff	current_key, last_key
    
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
    
CounterWrap:
	movlw	1
	movwf	key_counter, A
	return
	
DecodeKey:
	call	DecodeChar
	movwf	decoded_char, A
	call	LCDPrintDecoded 
	bra	MainLoop

LockChar:
	lfsr    0, message_buffer
	movf    lock_counter, W, A
	addwf   FSR0L, F, A
	movlw   0
	addwfc  FSR0H, F, A

	movf    decoded_char, W, A
	movwf   INDF0, A
    
	clrf	key_counter, A
	clrf	timer_counter, A
	incf	lock_counter, A
	call	ShiftCursorRight
	
	return
	
Overflow:
	call	LCDPrintOverflow
	bra	MainLoop
	
ReadBufferChar:
	lfsr    0, message_buffer
	addwf   FSR0L, F, A
	movlw   0
	addwfc  FSR0H, F, A
	movf    INDF0, W, A
	return
    
	end	rst

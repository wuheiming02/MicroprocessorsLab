#include <xc.inc>

extrn	TimerSetup, TimerInterrupt

extrn   KeyPad_Init, KeyPad_Read

extrn   LCD_Setup
extrn   LCD_Send_Byte_D
extrn   clear_LCD
extrn	LCD_delay_ms
    
extrn	decoded_count
extrn	decoded_char
extrn	shift_count
extrn	line2_pos
    
global	timer_counter

psect	udata_acs
timer_counter:	ds 1 
current_state:	ds 1 
last_state:	ds 1 
current_key:	ds 1 
last_key:	ds 1
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
	clrf	last_ley, A
	clrf	message_buffer
	
	clrf	decoded_count, A
	clrf	shift_count, A
	clrf	line2_pos, A
	clrf	decoded_char, A
	
	call    LCD_Setup
	call    clear_LCD
	
	call    KeyPad_Init
	
	
SetupWaitLoop:
	call	KeyPad_Read
	
	movwf	current_key, A
	
EntryCheckHigh:
	movlw	'9'
	cpfsgt	current_key
	bra	EntryCheckLow
	
	bra	SetupWaitLoop
	
EntryCheckLow:
	movlw	'0'
	cpfslt	current_key
	bra	MainLoop
	
	bra	SetupWaitLoop

MainLoop:
	call	KeyPad_Read
	
	movwf	current_key, A
	movlw	0xFF
	cpfseq	current_key
	bra
	
	
	
	
	xorlw	'5'
	bz	KeyPressed
	
KeyReleased:
	clrf	key_state, A
	bra	CheckState
	
KeyPressed:
	movlw	1
	movwf	key_state, A
	
CheckState:
	movf	key_state, W, A
	cpfseq	last_key_state, A
	bra	StateChange
	bra	NoStateChange
	
StateChange:
	movf	last_key_state, W, A
	bz	ReleaseFinished
	
	bra	PressFinished
	
PressFinished:
	movlw	3
	cpfsgt	timer_counter, A
	bra	StoreDot
	
	bra	StoreDash
	
StoreDot:
	movlw	'.'
	call	StoreSymbol
	bra	ResetTimer
	
StoreDash:
	movlw	'-'
	call	StoreSymbol
	bra	ResetTimer	

ReleaseFinished:
	movlw	3
	cpfsgt	timer_counter, A
	bra	ResetTimer
	
	bra	DecodeChar
	
DecodeChar:
	call	DecodeLetter
	call    LCDPrintDecoded
	call	LCDClearLine2
	bra	ResetTimer
	
ResetTimer:
	clrf	timer_counter, A
	
	movff	key_state, last_key_state
	bra	MainLoop	
	
NoStateChange:
	movf	key_state, W, A
	bz	CheckRelease
	
CheckPress:
	movlw	7
	cpfsgt	timer_counter, A
	bra	MainLoop
	
	call	LCDPrintError
	call	ClearBuffer
	
WaitRelease:
	call	KeyPad_Read
	xorlw	'5'
	bz	WaitRelease
	call	LCDClearLine2
	bra	ResetTimer
	
CheckRelease:
	movlw	7
	cpfsgt	timer_counter, A
	bra	MainLoop
	
	call	DecodeLetter
	call    LCDPrintDecoded
	call    LCDClearLine2
	movlw	' '
	call	LCDPrintDecoded
	
WaitPress:
	call	KeyPad_Read
	xorlw	'5'
	bnz	WaitPress
	call	LCDClearLine2
	bra	ResetTimer
	
	end	rst

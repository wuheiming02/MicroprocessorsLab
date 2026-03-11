#include <xc.inc>

extrn	TimerSetup, TimerInterrupt

extrn   KeyPad_Init, KeyPad_Read

extrn   LCD_Setup
extrn   LCD_Send_Byte_D
extrn   clear_LCD
extrn	LCD_delay_ms
    
extrn	DecodeLetter
extrn	StoreSymbol
extrn	ClearBuffer
    
extrn	LCDPrintDecoded
extrn	LCDPrintError
extrn	LCDClearLine2
extrn	MorseError
    
extrn	decoded_count
extrn	shift_count
extrn	line2_pos
    
global	timer_counter, decoded_char

psect	udata_acs
timer_counter:	ds 1 ; track amount of time pressed or released
key_state:	ds 1 ; whether the button was pressed or not
last_key_state:	ds 1 ; whether the button was pressed or not in the last check
morse_index:	ds 1 
decoded_char:	ds 1

    
psect	code, abs
	
rst:
	org	0x0000	; reset vector
	goto	start

int_hi:
	org	0x0008	; high vector, no low vector
	goto	TimerInterrupt
	
start:
	clrf	timer_counter, A
	clrf	key_state, A
	clrf	last_key_state, A
	clrf	morse_index, A
	
	clrf	decoded_count, A
	clrf	shift_count, A
	clrf	line2_pos, A
	clrf	decoded_char, A
	
	call    LCD_Setup
	call    clear_LCD
	
	call    KeyPad_Init
	
	call	ClearBuffer
	
SetupWaitLoop:
	call	KeyPad_Read
	
	xorlw	'5'
	bnz	SetupWaitLoop
	call    TimerSetup

MainLoop:
	call	KeyPad_Read
	
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
	movwf	decoded_char, A
	
	movf	decoded_char, W, A
	xorlw	'?'
	bz	InvalidMorse
	
	call	PrintChar
	bra	ResetTimer
	
InvalidMorse:
	call	MorseError
	bra	ResetTimer
	
PrintChar:
	call    LCDPrintDecoded
	call	LCDClearLine2
	
	return
	
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
	movwf	decoded_char, A
	
	movf	decoded_char, W, A
	xorlw	'?'
	bz	InvalidMorseWait
	
	call	PrintChar
	movlw	' '
	call	LCDPrintDecoded
	
WaitPress:
	call	KeyPad_Read
	xorlw	'5'
	bnz	WaitPress
	call	LCDClearLine2
	bra	ResetTimer
	
InvalidMorseWait:
	call	MorseError
	bra	WaitPress
	
	end	rst

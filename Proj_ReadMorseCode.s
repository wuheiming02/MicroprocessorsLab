#include <xc.inc>

extrn	TimerSetup, TimerInterrupt

extrn   KeyPad_Init, KeyPad_Read

extrn   LCD_Setup
extrn   LCD_Send_Byte_D
extrn   clear_LCD
    
extrn	DecodeLetter
extrn	StoreSymbol
extrn	ClearBuffer
    
global	timer_counter, temp_symbol

psect	udata_acs
timer_counter:	ds 1 ; track amount of time pressed or released
key_state:	ds 1 ; whether the button was pressed or not
last_key_state:	ds 1 ; whether the button was pressed or not in the last check
morse_index:	ds 1 
temp_symbol:	ds 1

    
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
	
	call    LCD_Setup
	call    clear_LCD
	
	call    KeyPad_Init
	
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
	bra	NoStateChange
	
	movf	last_key_state, W, A
	bz	ReleaseFinished
	
	bra	PressFinished
	
PressFinished:
	movlw	3
	cpfsgt	timer_counter, A
	bra	StoreDot
	
	movlw	7
	cpfsgt	timer_counter, A
	bra	StoreDash
	
	bra	PressError
	
StoreDot:
	movlw	'.'
	call	StoreSymbol
	bra	ResetTimer
	
StoreDash:
	movlw	'-'
	call	StoreSymbol
	bra	ResetTimer
	
PressError:
	movlw	'E'
	call	LCD_Send_Byte_D
	call	ClearBuffer
	bra	ResetTimer
	

ReleaseFinished:
	movlw	3
	cpfsgt	timer_counter, A
	bra	ResetTimer
	
	movlw	7
	cpfsgt	timer_counter, A
	bra	DecodeChar
	
	call	DecodeLetter
	movlw	' '
	call	LCD_Send_Byte_D
	bra	ResetTimer
	
DecodeChar:
	call	DecodeLetter
	bra	ResetTimer
	
ResetTimer:
	clrf	timer_counter, A
	
	movf	key_state, W, A
	movwf	last_key_state, A
	bra	MainLoop	
	
NoStateChange:
	bra	MainLoop
	
	end	rst



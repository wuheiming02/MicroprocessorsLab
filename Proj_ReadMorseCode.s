#include <xc.inc>
    
; from Proj_Timer
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

; from DecodeMorseCode
extrn	DecodeLetter
extrn	StoreSymbol
extrn	ClearBuffer

extrn	bit_buffer
extrn	bit_length
    
; from MorseLCD    
extrn	LCDPrintDecoded
extrn	LCDPrintError
extrn	LCDClearLine2
extrn	MorseError

extrn	decoded_counter
extrn	shift_counter
    
global	timer_counter, decoded_char

psect	udata_acs
timer_counter:	ds 1 ; track amount of time pressed or released
current_state:	ds 1 ; whether the button was pressed or not
last_state:	ds 1 ; whether the button was pressed or not in the last check
current_key:	ds 1 ; the key being pressed
decoded_char:	ds 1 ; decoded character
    

    
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
	
	clrf	decoded_counter, A
	clrf	shift_counter, A
	clrf	decoded_char, A
	
	call    LCD_Setup
	call    clear_LCD
	
	call    KeyPad_Init
	
	call	ClearBuffer
	
SetupWaitLoop: 
; program starts when '5' is pressed to start Morse code input
	call	KeyPad_Read
	
	xorlw	'5'
	bnz	SetupWaitLoop
	
	call    TimerSetup
	bra	MainLoop

MainLoop: 
	call	KeyPad_Read
	
	xorlw	'5' ; if '5' is pressed, branch to KeyPressed
	bz	KeyPressed
	
	bra	KeyReleased ; else branch to KeyReleased
	
KeyReleased: 
	clrf	current_state, A ; set current_state to 0
	bra	CheckState ; check if a key was pressed just before this
	
KeyPressed:
	movlw	1
	movwf	current_state, A ; set current_state to 1
	bra	CheckState ; check if a key was pressed just before this
	
CheckState:
	movf	current_state, W, A ; compare current_state with last_state
	cpfseq	last_state, A
	bra	StateChange ; branch to StateChange if there is a state change
	bra	NoStateChange ; branch to NoStateChange if there is no change
	
StateChange:
	movf	last_state, W, A ; check if a key was pressed before this
	bz	ReleaseFinished ; branch to ReleasedFinished if there was no key pressed before
	
	bra	PressFinished ; else branch to PressFinished
	
PressFinished:
	movlw	2 ; if '5' was pressed for less than 3 dits
	cpfsgt	timer_counter, A 
	bra	StoreDot ; interpret as a got
	
	bra	StoreDash ; else interpret as a dash
	
StoreDot:
	movlw	'.' ; store a dot
	call	StoreSymbol
	bra	ResetTimer ; reset timer
	
StoreDash:
	movlw	'-' ; store a dash
	call	StoreSymbol
	bra	ResetTimer ; reset timer

ReleaseFinished:
	movlw	2 ; if a key was released for less than 3 dits
	cpfsgt	timer_counter, A
	bra	ResetTimer ; reset the timer
	
	bra	DecodeChar ; decode the character in Morse code
	
DecodeChar:
	call	DecodeLetter ; decode the character stored in bit_buffer
	movwf	decoded_char, A ; place the decoded character in decoded_char
	
	movf	decoded_char, W, A ; check for invalid input
	xorlw	'?'
	bz	InvalidMorse ; if yes branch to InvalidMorse
	
	movf	decoded_char, W, A ; display character on LCD
	call	PrintChar
	bra	ResetTimer ; reset timer
	
InvalidMorse:
	call	MorseError ; display error message
	bra	ResetTimer ; reset timer
	
PrintChar:
	call    LCDPrintDecoded ; display valid character on line 1 of LCD
	call	LCDClearLine2 ; clear line 2 on LCD
	
	return
	
ResetTimer:
	clrf	timer_counter, A ; clear timer_counter
	
	movff	current_state, last_state ; set last_state as current_state
	bra	MainLoop ; branch back to MainLoop
	
NoStateChange:
	movf	current_state, W, A ; check if it was a continuous press or release
	bz	CheckRelease ; check no key was pressed for too long
	
	bra	CheckPress ; check if '5' was pressed for too long
	
CheckPress:
	movlw	6 ; if '5' was pressed for less than 7 dits
	cpfsgt	timer_counter, A
	bra	MainLoop ; if yes nothing happens, branch back to MainLoop
	
	call	LCDPrintError ; else display error message on LCD line 2
	call	ClearBuffer ; clear bit_buffer and bit_length to restart Morse input
	
WaitRelease:
	call	KeyPad_Read ; press '5' to clear error message
	xorlw	'5'
	bz	WaitRelease
	
	call	LCDClearLine2
	bra	ResetTimer ; reset timer
	
CheckRelease:
	movlw	6 ; check if no key was pressed for less than 7 dits
	cpfsgt	timer_counter, A
	bra	MainLoop ; if yes nothing happens, branch back to MainLoop
	
	call	DecodeLetter ; if no decode the letter
	movwf	decoded_char, A
	
	movf	decoded_char, W, A
	xorlw	'?'
	bz	InvalidMorseWait ; branch to InvalidMorseWait if '?'
	
	movf	decoded_char, W, A
	call	PrintChar ; else display the character and a space bar
	movlw	' '
	call	LCDPrintDecoded
	
WaitPress:
	call	KeyPad_Read ; press '5' to continue input
	xorlw	'5'
	bnz	WaitPress
	
	call	LCDClearLine2 ; clear line 2
	bra	ResetTimer ; reset timer
	
InvalidMorseWait:
	call	LCDPrintError ; else display error message on LCD line 2
	call	ClearBuffer ; clear bit_buffer and bit_length to restart Morse input
	bra	WaitPress ; branch to WaitPress
	
	end	rst

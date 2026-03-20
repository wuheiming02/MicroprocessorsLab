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
    
; from Proj_Decrypt
 
extrn	Decrypt_Init        
extrn	DecryptChar
extrn	DEC_UpdateShift
extrn	DecBackSpaceUpdate
    
; from MorseLCD    
extrn	LCDPrintDecodedMorse
extrn	LCDPrintErrorMorse
extrn	LCDPrintOverflowMorse
extrn	LCDClearLine2Morse
extrn	MorseError

extrn	decoded_counter
    
; from HomePage
extrn	HomePageStart
    
extrn	timer_counter
extrn	current_state
extrn	last_state
extrn	current_key
extrn	decoded_char
    
extrn	shift_counter
    
global	MorseStart

psect	read_morse_code, class=CODE
	
MorseStart:
	clrf	timer_counter, A
	clrf	current_state, A
	;clrf	last_state, A
	clrf	current_key, A
	
	movlw	1
	movwf	last_state, A
	
	clrf	decoded_counter, A
	clrf	shift_counter, A
	clrf	decoded_char, A
	
	call    LCD_Setup
	call    clear_LCD
	
	call    KeyPad_Init
	
	call	ClearBuffer
	
	call	Decrypt_Init
	
SetupWaitLoop: 
; program starts when '5' is pressed to start Morse code input
	call	KeyPad_Read
	movwf	current_key, A
	
	movlw	'F' ; if 'F' is pressed branch to ExecF
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecF
	
	movf	current_key, W, A ; press '5' to exit SetupWaitLoop
	xorlw	'5'
	bnz	SetupWaitLoop
	
	clrf	timer_counter, A
	call    TimerSetup
	bra	MainLoop

MainLoop:
	movlw	32 ; check if there are already 32 decoded characters
	cpfseq	decoded_counter, A
	bra	$ + 6
	goto	Overflow ; if yes branch to Overflow
    
	call	KeyPad_Read
	movwf	current_key, A ; store key in current_key
	
	movf	current_key, W, A ; if a key is pressed
	xorlw	0xFF 
	bnz	KeyPressed ; branch to KeyPressed
	
	bra	KeyReleased ; else branch to KeyReleased
	
KeyReleased: 
	clrf	current_state, A ; set current_state to 0
	bra	CheckState ; check if a key was pressed just before this
	
KeyPressed:
	movlw	1
	movwf	current_state, A ; set current_state to 1
	
	movf	current_key, W, A ; only proceed if '5' was pressed
	xorlw	'5'
	bz	CheckState ; check if a key was pressed just before this
	
	movlw	'F' ; if 'F' is pressed branch to ExecF
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecF
	
	movlw	'E'
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecE
	
	movlw	'C'
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecC
	
	clrf	current_state, A
	
	goto	ResetTimer ; reset timer
	
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
	movlw	5 ; if '5' was pressed for less than 6 units
	cpfsgt	timer_counter, A 
	bra	StoreDot ; interpret as a dot
	
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
	movlw	5 ; if a key was released for less than 3 dits
	cpfsgt	timer_counter, A
	bra	ResetTimer ; reset the timer
	
	bra	DecodeChar ; decode the character in Morse code
	
DecodeChar:
	call	DecodeLetter ; decode the character stored in bit_buffer
	movwf	decoded_char, A ; place the decoded character in decoded_char
	
	movf	decoded_char, W, A ; check for invalid input
	xorlw	'?'
	bz	InvalidMorse ; if yes branch to InvalidMorse
	
	call	DecryptChar
	
	movf	decoded_char, W, A ; display character on LCD
	call	PrintChar
	bra	ResetTimer ; reset timer
	
InvalidMorse:
	call	MorseError ; display error message
	bra	ResetTimer ; reset timer
	
PrintChar:
	call    LCDPrintDecodedMorse ; display valid character on line 1 of LCD
	call	LCDClearLine2Morse ; clear line 2 on LCD
	
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
	movlw	13 ; if '5' was pressed for less than 14 units
	cpfsgt	timer_counter, A
	bra	MainLoop ; if yes nothing happens, branch back to MainLoop
	
	call	LCDPrintErrorMorse ; else display error message on LCD line 2
	
	movlw   250 ; wait 1 second 
	call    LCD_delay_ms
	movlw   250
	call    LCD_delay_ms
	movlw   250
	call    LCD_delay_ms
	movlw   250
	call    LCD_delay_ms
	
	call	ClearBuffer ; clear bit_buffer and bit_length to restart Morse input
	
WaitRelease:
	call	KeyPad_Read ; press '5' to clear error message
	movwf	current_key, A
	
	movlw	'F' ; if 'F' is pressed branch to ExecF
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecF
	
	movlw	'E'
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecE
	
	movlw	'C'
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecC
	
	movf	current_key, W, A
	xorlw	'5'
	bnz	WaitRelease
	
	call	LCDClearLine2Morse
	bra	ResetTimer ; reset timer
	
CheckRelease:
	movlw	13 ; check if no key was pressed for less than 13 units
	cpfsgt	timer_counter, A
	bra	MainLoop ; if yes nothing happens, branch back to MainLoop
	
	call	DecodeLetter ; if no decode the letter
	movwf	decoded_char, A
	
	movf	decoded_char, W, A
	xorlw	'?'
	bz	InvalidMorseWait ; branch to InvalidMorseWait if '?'
	
	call	DecryptChar
	
	movf	decoded_char, W, A
	call	PrintChar ; else display the character and a space bar
	movlw	' '
	call	LCDPrintDecodedMorse
	call	DEC_UpdateShift
	
WaitPress:
	call	KeyPad_Read ; press '5' to continue input
	movwf	current_key, A
	
	movlw	'F' ; if 'F' is pressed branch to ExecF
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecF
	
	movlw	'E'
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecE
	
	movlw	'C'
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecC
	
	movf	current_key, W, A
	xorlw	'5'
	bnz	WaitPress
	
	call	LCDClearLine2Morse ; clear line 2
	bra	ResetTimer ; reset timer
	
InvalidMorseWait:
	call	LCDPrintErrorMorse ; else display error message on LCD line 2
	call	ClearBuffer ; clear bit_buffer and bit_length to restart Morse input
	bra	WaitPress ; branch to WaitPress
	
Overflow:
	call	LCDPrintOverflowMorse ; displays 'OVERFLOW' on LCD line 2
	
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
	
	movlw	'C'
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecC
	
	bra	OverflowWaitLoop
	
ExecF:
	call	KeyPad_Read ; wait till key is released
	xorlw	0xFF
	bz	GotoHomepage
	
	bra	ExecF
	
GotoHomepage:
	call	clear_LCD ; clears LCD
	goto	HomePageStart ; go back to home page
	
ExecE:
	call	KeyPad_Read
	xorlw	0xFF
	bz	BackSpaceFunc
	bra	ExecE

BackSpaceFunc:
	call	LCDClearLine2Morse
	movf	bit_length, W, A
	bz	BackSpaceChar

	bra	BackSpaceMorse

BackSpaceMorse:
	call	LCDClearLine2Morse
	call	ClearBuffer
	bra	BackSpaceDone

BackSpaceChar:
	movf	decoded_counter, W, A
	bz	BackSpaceDone
	call	DecBackSpaceUpdate
	decf	decoded_counter, F, A
	
	movlw   0x80 ; display character on line 1[decoded_counter]
	addwf   decoded_counter, W, A
	call    LCD_Send_Byte_I
	movlw   10
	call    LCD_delay_x4us
    
	movlw	' '
	call    LCD_Send_Byte_D
	
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
	bra	ResetTimer
	
ExecC:
	call	KeyPad_Read
	xorlw	0xFF
	bz	InspectionMode
	bra	ExecC
	
InspectionMode:
	call	KeyPad_Read
	movwf	current_key, A
	
	movlw	'F' ; if 'F' is pressed branch to ExecF
	cpfseq	current_key, A
	bra	$ + 6
	goto	ExecF
	
	movlw	16
	cpfsgt	decoded_counter, A
	bra	InspectionMode
	
	movf	current_key, W, A
	xorlw	'A'
	bz	ExecA
	
	movf	current_key, W, A
	xorlw	'B'
	bz	ExecB
	
	bra	InspectionMode
	
ExecA:
	call	KeyPad_Read
	xorlw	0xFF
	bz	ShiftDisplayLeft
	bra	ExecA
	
ExecB:
	call	KeyPad_Read
	xorlw	0xFF
	bz	ShiftDisplayRight
	bra	ExecB
	
ShiftDisplayLeft:
	movf	shift_counter, W, A
	bz	InspectionMode
	
	movlw   00011100B
	call    LCD_Send_Byte_I
	movlw   10
	call    LCD_delay_x4us 
	decf    shift_counter, F, A ; decrement shift counter
	
	bra	InspectionMode
	
ShiftDisplayRight:
	movf	shift_counter, W, A
	xorlw	16
	bz	InspectionMode
	
	movlw   00011000B
	call    LCD_Send_Byte_I
	movlw   10
	call    LCD_delay_x4us 
	incf    shift_counter, F, A
	
	bra	InspectionMode
	
	
	
	

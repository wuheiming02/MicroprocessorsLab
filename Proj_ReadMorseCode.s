#include <xc.inc>

extrn	TimerSetup, TimerInterrupt

extrn   KeyPad_Init, KeyPad_Read

extrn   LCD_Setup
extrn	LCD_Send_Byte_I
extrn   LCD_Send_Byte_D
extrn   clear_LCD
extrn	LCD_delay_ms
extrn	LCD_delay_x4us

extrn	DecodeLetter
extrn	StoreSymbol
extrn	ClearBuffer
extrn	bit_buffer
extrn	bit_length
    
extrn	LCDPrintDecoded
extrn	LCDPrintError
extrn	LCDClearLine2
extrn	MorseError
extrn	LCDShiftDisplayLeft
extrn	LCDShiftDisplayRight
    
extrn	decoded_count
extrn	shift_count
extrn	line2_pos
    
global	timer_counter, decoded_char

psect	udata_acs
timer_counter:	ds 1 ; track amount of time pressed or released
current_state:	ds 1 ; whether the button was pressed or not
last_state:	ds 1 ; whether the button was pressed or not in the last check
current_key:	ds 1
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
	clrf	current_state, A
	clrf	last_state, A
	clrf	current_key, A
	
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
	bra	MainLoop

MainLoop:
	call	KeyPad_Read
	movwf	current_key, A
	
	xorlw	0xFF
	bz	KeyReleased
	
	movf	current_key, W, A
	xorlw	'5'
	bz	MorseKeyPressed
	
	bra	SpecialFunctions
	
KeyReleased:
	clrf	current_state, A
	
	movf	bit_length, W, A
	bz	ResetTimer
	
	bnz	MorseCheckState
	
MorseKeyPressed:
	movlw	1
	movwf	current_state, A
	bra	MorseCheckState
	
MorseCheckState:
	movf	current_state, W, A
	cpfseq	last_state, A
	bra	MorseStateChange
	bra	MorseNoStateChange
	
MorseStateChange:   
	movf	last_state, W, A
	bz	MorseReleaseFinished
	
	bra	MorsePressFinished
	
MorsePressFinished:
	movlw	2
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

MorseReleaseFinished:
	incf	bit_length, F, A
	movlw	2
	cpfsgt	timer_counter, A
	bra	ResetTimer
	
	bra	DecodeChar
	
DecodeChar:
	call	DecodeLetter
	movwf	decoded_char, A
	
	movf	decoded_char, W, A
	xorlw	'?'
	bz	InvalidMorse
	
	movf	decoded_char, W, A
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
	
	movff	current_state, last_state
	bra	MainLoop	
	
MorseNoStateChange:
	movf	current_state, W, A
	bz	CheckRelease
	
CheckPress:
	;decf	bit_length, F ,A
	movlw	6
	cpfsgt	timer_counter, A
	bra	MainLoop
	
	call	MorseError
	call	ClearBuffer
	
WaitRelease:
	call	KeyPad_Read
	xorlw	'C'
	bz	WaitRelease
	call	LCDClearLine2
	bra	ResetTimer
	
CheckRelease:
	movlw	6
	cpfsgt	timer_counter, A
	bra	MainLoop
	
	call	DecodeLetter
	movwf	decoded_char, A
	
	movf	decoded_char, W, A
	xorlw	'?'
	bz	InvalidMorseWait
	
	movf	decoded_char, W, A
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
	
SpecialFunctions:
	movlw	1
	movwf	current_state, A
	
	movf	last_state, W, A
	bnz	MainLoop
	
	movff	current_state, last_state
	
	movf	current_key, W, A
	xorlw	'E'
	bz	ExecE
	
	goto	MainLoop
	
ExecE:
	call	Efunc
	goto	MainLoop
	
;Efunc:
;	movf	bit_length, W, A
;	bz	EfuncLine1
;	
;	bcf	STATUS, 0, A
;	rrcf	bit_buffer, F, A
;	decf	line2_pos, F, A
;	decf	bit_length, F, A
;	
;	movlw	0x40
;	addlw	0x80
;	addwf	shift_count, W, A
;	addwf	line2_pos, W, A
;	call	LCD_Send_Byte_I
;	movlw	10
;	call	LCD_delay_x4us
;	
;	movlw	' '
;	call	LCD_Send_Byte_D
;	
;	return
;	
;EfuncLine1:
;	movlw	0
;	cpfseq	decoded_count, A
;	bra	EfuncLine1Continue
;	
;	return
;    
;EfuncLine1Continue:   
;	decf	decoded_count, F, A
;    
;	movlw	0x80
;	addwf	decoded_count, W, A
;	call	LCD_Send_Byte_I
;	movlw	10
;	call	LCD_delay_x4us
;	
;	movlw	' '
;	call	LCD_Send_Byte_D
;	
;	movlw   00010000B   
;	call    LCD_Send_Byte_I
;	movlw   10
;	call    LCD_delay_x4us
;	
;	movlw	0
;	cpfseq	shift_count, A
;	call	LCDShiftDisplayLeft
;	
;	return
	
	
Efunc:
	movf    bit_length, W, A
	bz      EfuncLine1

	bcf     STATUS, 0, A
	rrcf    bit_buffer, F, A

        decf    bit_length, F, A
	decf    line2_pos, F, A

        movlw   0x40
	addlw   0x80
	addwf   shift_count, W, A
	addwf   line2_pos, W, A
	call    LCD_Send_Byte_I
	movlw   10
	call    LCD_delay_x4us

	movlw   ' '
	call    LCD_Send_Byte_D

	movlw   0x40
	addlw   0x80
	addwf   shift_count, W, A
	addwf   line2_pos, W, A
	call    LCD_Send_Byte_I
	movlw   10
	call    LCD_delay_x4us

	return

EfuncLine1:
    movf    decoded_count, W, A
    bz      EfuncDone

    movf    shift_count, W, A
    bz      EfuncLine1NoShiftUndo

    call    LCDShiftDisplayRight
    decf    shift_count, F, A

EfuncLine1NoShiftUndo:
    decf    decoded_count, F, A

    movlw   0x80
    addwf   decoded_count, W, A
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us

    movlw   ' '
    call    LCD_Send_Byte_D

    movlw   0x80
    addwf   decoded_count, W, A
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us

EfuncDone:
    return
	
	end	rst
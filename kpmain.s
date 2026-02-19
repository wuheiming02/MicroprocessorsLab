#include <xc.inc>

extrn  KeyPad_Init, KeyPad_Read
extrn  LCD_Setup, LCD_Send_Byte_D, clear_LCD, LCD_delay_ms, line2_shift, LCD_Send_Byte_I, LCD_delay_x4us

psect udata_acs

DB_inner:   ds 1
DB_outer:   ds 1
DB_temp:    ds 1
dly1:	    ds 1
dly2:	    ds 1
dummy:	    ds 1
current_line:	ds 1
cursor_pos: ds 1
shift_count:	ds 1
    
    
psect  code, abs

org 0x0000
goto    setup

org 0x0100

setup:
        call    LCD_Setup         ; Initialise LCD
        call    KeyPad_Init       ; Initialise keypad
	call	clear_LCD
	movlw	0x00
	movwf	current_line, A
	movwf	cursor_pos, A
	movwf	shift_count, A
        goto    main_loop


; ============================================================
; MAIN LOOP
; Continuously read keypad and display ASCII on LCD
; ============================================================
	
main_loop:
	
	call    KeyPad_Read       ; Read key
        movwf   dummy, A              ; ASCII returned in W

        xorlw   0xFF              ; Check invalid
        bz      main_loop         ; If no key, then keep looping
	
	movlw	80
        call	LCD_delay_ms
	
	call	KeyPad_Read
	
	xorwf	dummy, W, A
	bnz	main_loop
	
check_F:
	movlw	'F'
	cpfseq	dummy, A
	bra	check_E
	bra	clear

check_E:
	movlw	'E'
	cpfseq	dummy, A
	bra	check_D
	bra	back_space
	
check_D:
	movlw	'D'
	cpfseq	dummy, A
	bra	print
	bra	D_func
	
print:
	movf	dummy, W, A
	call	LCD_Send_Byte_D
	
	incf	cursor_pos, F, A
	movlw	16
	cpfslt	cursor_pos, A
	bra	shift_display
	bra	main_loop
	
clear:
	call	clear_LCD
	movlw	0
	movwf	current_line, A
	movwf	cursor_pos, A
	bra	shift_back
    
; Simple delay
delay:	; delay subroutine
	movlw	0xFF
	movwf	dly1, A
delay_outer:
	movlw	0xFF
	movwf	dly2, A
delay_inner:
	decfsz	dly2, A    ; count down from 255 before starting next loop
 	bra	delay_inner
	decfsz	dly1, A
	bra	delay_outer
	return

; Debounce Delay
Debounce_Delay:
	movlw	200
	movwf	DB_outer, A

DB_L1:
	movlw	200
	movwf	DB_inner, A

DB_L2:
	decfsz	DB_inner, F, A
	bra	DB_L2
	
	decfsz	DB_outer, F, A
	bra	DB_L1
	
	return
	
back_space:
	movlw	00010000B
	call	LCD_Send_Byte_I
	movlw	10
	call	LCD_delay_x4us
	movlw	' '
	call	LCD_Send_Byte_D
	movlw	00010000B
	call	LCD_Send_Byte_I
	movlw	10
	call	LCD_delay_x4us
	decf	cursor_pos, F, A
	decf	shift_count, F, A
	movlw	00011100B
	call	LCD_Send_Byte_I
	movlw	10
	call	LCD_delay_x4us
	bra	main_loop
	
D_func:
	movlw	0x01
	cpfseq	current_line, A
	bra	next_line
	bra	clear
next_line:
	call	line2_shift
	incf	current_line, F, A
	movlw	0
	movwf	cursor_pos
	bra	main_loop	

shift_display:
	movlw	00011000B
	call	LCD_Send_Byte_I
	movlw	10
	call	LCD_delay_x4us
	
	incf	shift_count, F, A
	
	movlw	32
	cpfseq	cursor_pos, A
	return
	bra	shift_back
	
shift_back:
	movlw	00011100B
	call	LCD_Send_Byte_I
	movlw	10
	call	LCD_delay_x4us
	decfsz	shift_count
	bra	shift_back
	call	D_func
	movlw	0
	movwf	cursor_pos, A
	bra	main_loop

end	main_loop


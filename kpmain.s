#include <xc.inc>

extrn  KeyPad_Init, KeyPad_Read
extrn  LCD_Setup, LCD_Send_Byte_D, clear_LCD, LCD_delay_ms, line2_shift, LCD_Send_Byte_I, LCD_delay_x4us

psect udata_acs

DB_inner:   ds 1
DB_outer:   ds 1
DB_temp:    ds 1
dly1:	    ds 1		    ; outer counter for delay functon
dly2:	    ds 1		    ; inner counter for delay function
dummy:	    ds 1		    ; dummy variable to hold input for waiting for debouce
current_line:	ds 1		    ; line on LCD, 0 = first line, 1 = second line
cursor_pos: ds 1		    ; cursor position on LCD, range [0, 32)
shift_count:	ds 1		    ; count how many times LCD display is shifted left, range [0, 16)
    
    
psect  code, abs

org 0x0000
goto    setup

org 0x0100

setup:
        call    LCD_Setup	  ; Initialise LCD
        call    KeyPad_Init	  ; Initialise keypad
	call	clear_LCD	  ; clear LCD display
	movlw	0x00		  ; reset LCD tracking variables
	movwf	current_line, A
	movwf	cursor_pos, A
	movwf	shift_count, A
        goto    main_loop


; ============================================================
; MAIN LOOP
; Continuously read keypad and display ASCII on LCD
; ============================================================
	
main_loop:
	
	call    KeyPad_Read     ; Read key
        movwf   dummy, A        ; ASCII returned in W

        xorlw   0xFF            ; Check invalid
        bz      main_loop	; If no key, then keep looping
	
	movlw	80		; debounce wait time set at 80 ms
        call	LCD_delay_ms
	
	call	KeyPad_Read	; read key again
	
	xorwf	dummy, W, A	; compare with first key read
	bnz	main_loop	; start again if two keys are different
	
check_F:			; 'F' clears display
	movlw	'F'
	cpfseq	dummy, A
	bra	check_E
	bra	clear

check_E:
	movlw	'E'		; 'E' is backspace
	cpfseq	dummy, A
	bra	check_D
	bra	back_space
	
check_D:			; 'D' goes to next line
	movlw	'D'
	cpfseq	dummy, A
	bra	print
	bra	D_func
	
print:
	movf	dummy, W, A	; send key to LCD
	call	LCD_Send_Byte_D
	
	incf	cursor_pos, F, A    ; increment cursor position
	movlw	16
	cpfslt	cursor_pos, A	    ; shifts display if cursor position is larger then 15 (15 characters on 1 line)
	bra	shift_display
	bra	main_loop
	
clear:
	call	clear_LCD	; clear LCD display
	movlw	0		; reset tracking variables
	movwf	current_line, A
	movwf	cursor_pos, A
	movf	shift_count, W, A   ; if display was shifted before, shift all the way back
	bz	main_loop
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
	movlw	00010000B   ; shift cursor back 1
	call	LCD_Send_Byte_I
	movlw	10
	call	LCD_delay_x4us
	movlw	' '	    ; replace last character with blank space
	call	LCD_Send_Byte_D
	movlw	00010000B   ; shift cursor back 1 again
	call	LCD_Send_Byte_I
	movlw	10
	call	LCD_delay_x4us
	decf	cursor_pos, F, A    ; decrement cursor position tracker
	
	movf	shift_count, W, A   ; shift display right bby 1 if dispay was shifted before
	bz	main_loop
	bra	shift_right
	
shift_right:
	decf	shift_count, F, A   ; decrement shift counter
	movlw	00011100B	    ; shift display right by 1
	call	LCD_Send_Byte_I
	movlw	10
	call	LCD_delay_x4us
	bra	main_loop
	
D_func:
	movlw	0x01	    ; check wich line the display is currently on
	cpfseq	current_line, A
	bra	next_line   ; go to line 2 if currently on line 1
	bra	clear	    ; clear display and start again of currently on line 2
next_line:
	call	line2_shift ; set cursor to line 2
	incf	current_line, F, A  ; increment current line tracker
	movlw	0	    ; reset cursor position tracker
	movwf	cursor_pos, A
	bra	main_loop	

shift_display:
	movlw	00011000B   ; shift display left by 1
	call	LCD_Send_Byte_I
	movlw	10
	call	LCD_delay_x4us
	
	incf	shift_count, F, A   ; increment shift counter
	
	movlw	32	    ; if cursor position is on 32 (end of line), shift display and cursor all the way back
	cpfseq	cursor_pos, A
	bra	main_loop
	bra	shift_back
	
shift_back:
	movlw	00011100B   ; shift displa back by 1
	call	LCD_Send_Byte_I
	movlw	10
	call	LCD_delay_x4us
	decfsz	shift_count, F, A   ; decrement shift counter
	movlw	0		    ; continue until shift counter is 0
	cpfseq	shift_count, A
	bra	shift_back
	movlw	0		    ; reset cursor position tracker
	movwf	cursor_pos, A
	bra	D_func		    ; start next line (like pressing D)

end	main_loop


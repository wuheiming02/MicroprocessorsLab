#include <xc.inc>

global  LCD_Setup, LCD_Write_Message, clear_LCD, line2_shift, LCD_Write_Message_direct, LCD_Send_Byte_D, LCD_delay_ms

psect	udata_acs   ; named variables in access ram
LCD_cnt_l:	ds 1   ; reserve 1 byte for variable LCD_cnt_l
LCD_cnt_h:	ds 1   ; reserve 1 byte for variable LCD_cnt_h
LCD_cnt_ms:	ds 1   ; reserve 1 byte for ms counter
LCD_tmp:	ds 1   ; reserve 1 byte for temporary use
LCD_counter:	ds 1   ; reserve 1 byte for counting through nessage

	LCD_E	EQU 5	; LCD enable bit
    	LCD_RS	EQU 4	; LCD register select bit

psect	lcd_code,class=CODE
    
LCD_Setup:
	clrf    LATB, A
	
	movlw   11000000B	    ; RB0:5 all outputs
	movwf	TRISB, A
	movlw   40
	call	LCD_delay_ms	; wait 40ms for LCD to start up properly
	movlw	00110000B	; Function set 4-bit
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	movlw	00101000B	; 2 line display 5x8 dot characters
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	movlw	00101000B	; repeat, 2 line display 5x8 dot characters
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	movlw	00001111B	; display on, cursor on, blinking on
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	;movlw	00000001B	; display clear
	;call	LCD_Send_Byte_I
	;movlw	2		; wait 2ms
	;call	LCD_delay_ms
	call	clear_LCD
	movlw	00000110B	; entry mode incr by 1 no shift
	call	LCD_Send_Byte_I
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	return

LCD_Write_Message:	    ; Message stored at FSR2, length stored in W
	movwf   LCD_counter, A
LCD_Loop_message:
	movf    POSTINC2, W, A
	movwf	LCD_tmp, A  ; store next character temporarily
	movlw	0x0d	    ; compare character to 0x0d
	cpfseq	LCD_tmp, A  ; skip next line if next character is 0x0d
	bra	print_character
	bra	move_to_line2
print_character:
	movf	LCD_tmp, W, A	; release character from temporary byte
	call    LCD_Send_Byte_D	; send chracter to LCD
skip_character:
	decfsz  LCD_counter, A
	bra	LCD_Loop_message
	return
move_to_line2:
	call    line2_shift
	bra     skip_character
	
LCD_Write_Message_direct:
	movwf   LCD_counter, A	; load LCD counter
direct_loop:
	tblrd*+			; one byte from PM to TABLAT, increment TBLPRT
	movf	TABLAT, W, A	; move data to W
	movwf	LCD_tmp, A  ; store next character temporarily
	movlw	0x0d	    ; compare character to 0x0d
	cpfseq	LCD_tmp, A  ; skip next line if next character is 0x0d
	bra	print_character_direct
	bra	move_to_line2_direct
print_character_direct:
	movf	LCD_tmp, W, A	; release character from temporary byte
	call    LCD_Send_Byte_D	; send characrter to LCD
skip_character_direct:
	decfsz  LCD_counter, A	; count down to 0
	bra	direct_loop
	return
move_to_line2_direct:
	call    line2_shift
	bra     skip_character_direct

LCD_Send_Byte_I:	    ; Transmits byte stored in W to instruction reg
	movwf   LCD_tmp, A
	swapf   LCD_tmp, W, A   ; swap nibbles, high nibble goes first
	andlw   0x0f	    ; select just low nibble
	movwf   LATB, A	    ; output data bits to LCD
	bcf	LATB, LCD_RS, A	; Instruction write clear RS bit
	call    LCD_Enable  ; Pulse enable Bit 
	movf	LCD_tmp, W, A   ; swap nibbles, now do low nibble
	andlw   0x0f	    ; select just low nibble
	movwf   LATB, A	    ; output data bits to LCD
	bcf	LATB, LCD_RS, A	; Instruction write clear RS bit
        call    LCD_Enable  ; Pulse enable Bit 
	return

LCD_Send_Byte_D:	    ; Transmits byte stored in W to data reg
	movwf   LCD_tmp, A
	swapf   LCD_tmp, W, A	; swap nibbles, high nibble goes first
	andlw   0x0f	    ; select just low nibble
	movwf   LATB, A	    ; output data bits to LCD
	bsf	LATB, LCD_RS, A	; Data write set RS bit
	call    LCD_Enable  ; Pulse enable Bit 
	movf	LCD_tmp, W, A	; swap nibbles, now do low nibble
	andlw   0x0f	    ; select just low nibble
	movwf   LATB, A	    ; output data bits to LCD
	bsf	LATB, LCD_RS, A	; Data write set RS bit	    
        call    LCD_Enable  ; Pulse enable Bit 
	movlw	10	    ; delay 40us
	call	LCD_delay_x4us
	return

LCD_Enable:	    ; pulse enable bit LCD_E for 500ns
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	bsf	LATB, LCD_E, A	    ; Take enable high
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	bcf	LATB, LCD_E, A	    ; Writes data to LCD
	return
    
; ** a few delay routines below here as LCD timing can be quite critical ****
LCD_delay_ms:		    ; delay given in ms in W
	movwf	LCD_cnt_ms, A
lcdlp2:	movlw	250	    ; 1 ms delay
	call	LCD_delay_x4us	
	decfsz	LCD_cnt_ms, A
	bra	lcdlp2
	return
    
LCD_delay_x4us:		    ; delay given in chunks of 4 microsecond in W
	movwf	LCD_cnt_l, A	; now need to multiply by 16
	swapf   LCD_cnt_l, F, A	; swap nibbles
	movlw	0x0f	    
	andwf	LCD_cnt_l, W, A ; move low nibble to W
	movwf	LCD_cnt_h, A	; then to LCD_cnt_h
	movlw	0xf0	    
	andwf	LCD_cnt_l, F, A ; keep high nibble in LCD_cnt_l
	call	LCD_delay
	return

LCD_delay:			; delay routine	4 instruction loop == 250ns	    
	movlw 	0x00		; W=0
lcdlp1:	decf 	LCD_cnt_l, F, A	; no carry when 0x00 -> 0xff
	subwfb 	LCD_cnt_h, F, A	; no carry when 0x00 -> 0xff
	bc 	lcdlp1		; carry, then loop again
	return			; carry reset so return

clear_LCD:			; clear LCD display
	movlw	00000001B	; set rb0 to 0
	call	LCD_Send_Byte_I	; send instrucion to LCD
    	movlw	2		; wait 2 ms (>1.52ms)
	call	LCD_delay_ms	
	return
	
line2_shift:
	movlw	0x40
	addlw	0x80
	call	LCD_Send_Byte_I
	movlw	10
	call	LCD_delay_x4us
	return
	

    
    end



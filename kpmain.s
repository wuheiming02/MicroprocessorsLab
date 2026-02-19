#include <xc.inc>

extrn  KeyPad_Init, KeyPad_Read
extrn  LCD_Setup, LCD_Send_Byte_D, clear_LCD, LCD_delay_ms

psect udata_acs

DB_inner:   ds 1
DB_outer:   ds 1
DB_temp:    ds 1
    
    
    
psect  code, abs

org 0x0000
goto    setup

org 0x0100

setup:
        call    LCD_Setup         ; Initialise LCD
        call    KeyPad_Init       ; Initialise keypad
        goto    main_loop
	dly1	EQU 0x20
	dly2	EQU 0x30
	dummy	EQU 0x40


; ============================================================
; MAIN LOOP
; Continuously read keypad and display ASCII on LCD
; ============================================================
	call	clear_LCD
main_loop:
	
	
	call    KeyPad_Read       ; Read key
        movwf   dummy, A              ; ASCII returned in W

        xorlw   0xFF              ; Check invalid
        bz      main_loop         ; If no key, then keep looping
	
	;call	Debounce_Delay
	;call	Debounce_Delay
	;call	Debounce_Delay
	;call	Debounce_Delay
	
	movlw	80
        call	LCD_delay_ms
	
	call	KeyPad_Read
	
	
	xorwf	dummy, W, A
	bnz	main_loop
	
	
	movlw	'F'
	cpfseq	dummy, A
	bra	print
	bra	clear

print:
	movf	dummy, W, A
	call	LCD_Send_Byte_D
	bra	main_loop
	
clear:
	call	clear_LCD
	bra	main_loop
    
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

end	main_loop


#include <xc.inc>

extrn	UART_Setup, UART_Transmit_Message  ; external subroutines
extrn	LCD_Setup, LCD_Write_Message, clear_LCD, line2_shift, LCD_Write_Message_direct
	
psect	udata_acs   ; reserve data space in access ram
counter:    ds 1    ; reserve one byte for a counter variable
delay_count:ds 1    ; reserve one byte for counter in the delay routine
    
psect	udata_bank4 ; reserve data anywhere in RAM (here at 0x400)
myArray:    ds 0x80 ; reserve 128 bytes for message data

psect	data    
	; ******* myTable, data in programme memory, and its length *****
myTable:
	db	'H','e','l','l','o',' ','W','o','r','l','d','!', 0x0d
	db	'G','o','o','d',' ','N','i','g','h','t', 0x0d
					; message, plus carriage return
	myTable_l   EQU	24	; length of data
	align	2
    
psect	code, abs	
rst: 	org 0x0
 	goto	setup

	; ******* Programme FLASH read Setup Code ***********************
setup:	
	bcf	CFGS	; point to Flash program memory  
	bsf	EEPGD 	; access Flash program memory
	call	UART_Setup	; setup UART
	call	LCD_Setup	; setup LCD
	
	clrf	LATA, A	; setup port A as button press
	movlw	0x01	; RA0 is input to be read later
	movwf	TRISA, A
	
	goto	start
	
	; ******* Main programme ****************************************
start: 	
	movlw	low highword(myTable)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(myTable)	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(myTable)	; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	
	call	copy_PM_to_RAM
	call	send_UART
	call	send_LCD
		
	goto	$		; goto current line in code

	
copy_PM_to_RAM:
	lfsr	0, myArray	; Load FSR0 with address in RAM	
	movlw	myTable_l	; bytes to read
	movwf 	counter, A	; our counter register
loop: 	
	tblrd*+			; one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0; move data from TABLAT to (FSR0), inc FSR0	
	decfsz	counter, A	; count down to zero
	bra	loop		; keep going until finished
	return
	
send_UART:
	movlw	myTable_l	; output message to UART
	lfsr	2, myArray
	call	UART_Transmit_Message
	return
	
send_LCD:			; different outputting method if button is pushed
	btfsc	PORTA, 0, A	; check RA0 (conected to button)
	bra	use_direct_loop	; send characters directly if button is pressed
use_indirect_loop:
	movlw	myTable_l	; output message to LCD
	lfsr	2, myArray
	call	LCD_Write_Message
	return
use_direct_loop:		; reset TBLRT
	movlw	low highword(myTable)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(myTable)	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(myTable)	; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	movlw   myTable_l
	call	LCD_Write_Message_direct	
	return
	
	
; a delay subroutine if you need one, times around loop in delay_count
delay:	decfsz	delay_count, A	; decrement until zero
	bra	delay
	return
	end	rst
	#include <xc.inc>
	
psect	code, abs
main:
	org 0x0
	goto	setup
	
	org 0x100		    ; Main code starts here at address 0x100

	; ******* Programme FLASH read Setup Code ****  
setup:	
	bcf	CFGS	; point to Flash program memory  
	bsf	EEPGD 	; access Flash program memory
	goto	start
	; ******* My data and where to put it in RAM *
myTable:
	; define values in table such that 8 LEDs in port C light up sequencially
	db	0x01,0x03,0x05,0x09,0x11,0x21,0x41,0x81 
	;db	0x40,0x20,0x10,0x08,0x04,0x02
	counter EQU 0x10	; Address of counter variable
	dly1	EQU 0x20	; set up outer counter
	dly2	EQU 0x30	; set up inner counter
	align	2		; ensure alignment of subsequent instructions 
	; ******* Main programme *********************
start:	
	;clrf	LATC, A		; turn off all LEDs in port C
	movlw	0x00
	movwf	LATC, A
	;clrf	TRISC, A	; set port C to output
	movlw	0x00
	movwf	TRISC, A
	movlw	low highword(myTable)	; address of data in PM
	movwf	TBLPTRU, A	; load upper bits to TBLPTRU
	movlw	high(myTable)	; address of data in PM
	movwf	TBLPTRH, A	; load high byte to TBLPTRH
	movlw	low(myTable)	; address of data in PM
	movwf	TBLPTRL, A	; load low byte to TBLPTRL
	movlw	8		; 14 bytes to read
	movwf 	counter, A	; our counter register
	
loop:
        tblrd*+			; move one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, LATC	; move read data from TABLAT to LATC
	call	delay
	decfsz	counter, A
	bra	loop		; keep going until finished
	goto	0
	
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
	
	end	main
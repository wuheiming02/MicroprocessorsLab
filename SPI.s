	#include <xc.inc>

psect	code, abs
	
main:
	org	0x0
	goto	start

	org	0x100	    ; Main code starts here at address 0x100
	
start:
	max	EQU 0x10    ; count up to counter
	counter	EQU 0X15    ; starting value 
	dly1	EQU 0x20
	dly2	EQU 0x30
	movlw	0xFF	    ; count to 0xFF 
	movwf	max, A
	movlw	0x00	    ; starting value 0x00
	movwf	counter, A
	call	SPI_MasterInit
	bcf	TRISD, 2, A
	bsf	LATD, 2, A  ; set RD2 to high and outputs to MR in SPI
loop:
	bcf	LATD, 2, A
	NOP
	NOP
	bsf	LATD, 2, A
	movf	counter, W, A
	call	SPI_MasterTransmit
	call	delay
	movf	max, W, A
	cpfseq 	counter, A  ; compare counter with val, skip line if equal
	bra 	increment   ; Not yet finished goto start of loop again
	goto 	start	    ; Re-run program from start

SPI_MasterInit:		    ; Set Clock edge to negative
	bcf	CKE2	    ; CKE bit in SSP2STAT, 
	; MSSP enable; CKP=1; SPI master, clock=Fosc/64 (1MHz)
	movlw 	(SSP2CON1_SSPEN_MASK)|(SSP2CON1_CKP_MASK)|(SSP2CON1_SSPM1_MASK)
	movwf 	SSP2CON1, A; SDO2 output; SCK2 output	
	bcf	TRISD, PORTD_SDO2_POSN, A   ; SDO2 output	
	bcf	TRISD, PORTD_SCK2_POSN, A   ; SCK2 output	
	return 

SPI_MasterTransmit:	    ; Start transmission of data (held in W)
	bcf 	PIR2, 5	    ; clear interrupt flag
	movwf 	SSP2BUF, A  ; write data to output buffer
Wait_Transmit:		    ; Wait for transmission to complete
	btfss 	PIR2, 5	    ; check interrupt flag to see if data has been sent	
	bra 	Wait_Transmit	
	bcf 	PIR2, 5	    ; clear interrupt flag
	movf	SSP2BUF, W, A	; read the buffer to clear it
	return 

increment:
	incf 	counter, f, A	; increment val
	bra	loop	    ; loop again

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


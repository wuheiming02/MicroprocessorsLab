	#include <xc.inc>

psect	code, abs
	
main:
	org	0x0
	goto	start

	org	0x100	    ; Main code starts here at address 0x100
start:
	movlw	0x00
	movwf	TRISD, A    ; clear TRISD to output data
	movlw 	0x03
	movwf	LATD, A     ; set up to output WR and CS
	movlw	0x00
	movwf	TRISJ, A    ; clear TRISJ to output data
	movlw	0x00
	movwf	LATJ, A     ; clear LATJ to output data
	max	EQU 0x10    ; count up to counter
	counter	EQU 0X15    ; starting value 
	dly1	EQU 0x20
	dly2	EQU 0x30
	movlw	0xFF	    ; port J count to 0xFF 
	movwf	max, A
	movlw	0x00	    ; starting value 0x00
	movwf	counter, A

loop:
	movlw	0x02	    ; select DAC
	movwf	LATD, A
	movff	counter, LATJ	; output to port J
	
	call	delay

	movlw	0x00	    ; write to DAC
	movwf	LATD, A
	call	delay
	call	delay
	movlw	0x02	    ; set WR back to high
	movwf	LATD, A
	
	movf	max, W, A
	cpfseq 	counter, A  ; compare counter with val, skip line if equal
	bra 	increment   ; Not yet finished goto start of loop again
	goto 	start	    ; Re-run program from start

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
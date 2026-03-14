#include <xc.inc>
	
extrn	timer_counter
    
global	TimerSetup, TimerInterrupt
    
psect	timer_code, class=CODE
; use 500ms as a base unti of time for Morse code
TimerSetup:	
	movlw	0x85
	movwf	TMR0H, A
	movlw	0xEE 
	movwf	TMR0L, A
	
	movlw	10000111B
	movwf	T0CON, A
	
	bsf	TMR0IE
	bsf	GIE
	return
	
TimerInterrupt:
	btfss	TMR0IF
	retfie	f
	
	bcf	TMR0IF
	; clamp timer_counter at 10 to prevent accidentally overflowing to 0x00
	movlw	10
	cpfsgt	timer_counter, A
	incf	timer_counter, F, A
	
	movlw	0x85
	movwf	TMR0H, A
	movlw	0xEE
	movwf	TMR0L, A
	
	movlw	10000111B
	movwf	T0CON, A

	retfie	f
	
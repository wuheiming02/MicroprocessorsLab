#include <xc.inc>
	
extrn	timer_counter
    
global	TimerSetup, TimerInterrupt
    
psect	NokiaTimer, class=CODE
; use 250ms as a base unit of time    
TimerSetup:	
	movlw	0xC2
	movwf	TMR0H, A
	movlw	0xF7 
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
	; clamp timer_counter at 20 to prevent accidentally overflowing to 0x00
	movlw	20
	cpfsgt	timer_counter, A
	incf	timer_counter, F, A
	
	movlw	0xC2
	movwf	TMR0H, A
	movlw	0xF7
	movwf	TMR0L, A
	
	movlw	10000111B
	movwf	T0CON, A

	retfie	f
	
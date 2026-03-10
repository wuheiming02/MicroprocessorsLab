#include <xc.inc>
	
extrn	timer_counter
    
global	TimerSetup, TimerInterrupt
    
psect	timer_code, class=CODE
    
TimerSetup:	
	movlw	0x0B
	movwf	TMR0H, A
	movlw	0xDC 
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
	
	movlw	10
	cpfsgt	timer_counter, A
	incf	timer_counter, F, A
	
	movlw	0x0B
	movwf	TMR0H, A
	movlw	0xDC
	movwf	TMR0L, A
	
	movlw	10000111B
	movwf	T0CON, A

	retfie	f
	
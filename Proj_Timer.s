#include <xc.inc>
	
extrn	timer_counter
    
global	TimerSetup, TimerInterrupt
    
psect	dac_code, class=CODE
    
TimerSetup:	
	movlw	0xE7 
	movwf	TMR0H, A
	movlw	0x96 
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
	
	incf	timer_counter, F, A
	
	movlw	0xE7
	movwf	TMR0H, A
	movlw	0xF6
	movwf	TMR0L, A
	
	movlw	10000111B
	movwf	T0CON, A

	retfie	f
	
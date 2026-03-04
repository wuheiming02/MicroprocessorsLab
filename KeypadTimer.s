#include <xc.inc>
	
global	Timer_Setup, Timer_Interrupt
    
psect	udata_acs
timer_counter:	ds 1
    
psect	dac_code, class=CODE
    
Timer_Setup:
	clrf	timer_counter, A
	
	clrf	TRISD, A
	
	movlw	0xE7 ; F9
	movwf	TMR0H, A
	movlw	0xF6 ; E5
	movwf	TMR0L, A
	
	movlw	1000111B
	movwf	T0CON, A
	
	bsf	TMR0IE
	bsf	GIE
	return
	
Timer_Interrupt:
	btfss	TMR0IF
	retfie	f
	
	movlw	0xE7
	movwf	TMR0H, A
	movlw	0xF6
	movwf	TMR0L, A
	
	incf	timer_counter, F, A
	
	movlw	15
	cpfseq	timer_counter, A
	goto	not_15

yes_15:
	clrf	timer_counter, A
	movlw	0xFF
	movwf	LATD, A
	
not_15:
	bcf	TMR0IF
	clrf	LATD, A
	retfie	f
	
	end



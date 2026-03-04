#include <xc.inc>

extrn	Timer_Setup, Timer_Interrupt
    
psect	code, abs
	
rst:	
	org	0x0000	; reset vector
	goto	start

int_hi:	
	org	0x0008	; high vector, no low vector
	goto	Timer_Interrupt
	
start:	
	call	Timer_Setup
    
main_loop:
	
	goto	$	; Sit in infinite loop
	end	rst



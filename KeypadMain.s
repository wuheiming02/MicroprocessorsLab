#include <xc.inc>

extrn	Timer_Setup, Timer_Interrupt

extrn   KeyPad_Init, KeyPad_Read

extrn   LCD_Setup
extrn   LCD_Send_Byte_D
extrn   clear_LCD

extrn   TextEntry_Init
extrn   TextEntry_Run    

    
psect	code, abs
	
rst:	
	org	0x0000	; reset vector
	movlw	0X00
	movwf	TRISJ, A
	goto	start

int_hi:	
	org	0x0008	; high vector, no low vector
	goto	Timer_Interrupt
	
start:	
    
	movlw	0x00
	movwf	LATJ, A
	
	
	call    LCD_Setup
	call    KeyPad_Init
	call    Timer_Setup
    
	
	call    TextEntry_Init

	call    clear_LCD
main_loop:
	
	call	TextEntry_Run
	
	
	goto	main_loop
	end	rst



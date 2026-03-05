#include <xc.inc>

extrn KeyPad_Read
extrn LCD_Send_Byte_D
extrn LCD_Send_Byte_I

extrn Lookup_Char
extrn Lock_Character

extrn last_key
extrn tap_count
extrn current_char
extrn idle_timer
    
extrn Timer_Setup
    

global TextEntry_Run

psect keypad_run_code, class=CODE

; ==========================================================
; TEXT ENTRY MAIN ROUTINE
; Called repeatedly from main loop
; ==========================================================

TextEntry_Run:
	
	call	Timer_Setup
        call    KeyPad_Read
	
        movwf   WREG, A

        ;xorlw   0xFF
        ;bz      Check_Timeout      ; no key pressed

        movwf   PRODL, A              ; store key

        ; --------------------------------------
        ; Check if key is same as previous
        ; --------------------------------------

        movf    last_key, W, A
        cpfseq  PRODL, A
        bra     New_Key

Same_Key:

        ; same key pressed again
	
	bcf	GIE
	bcf	TMR0IE

        incf    tap_count, F, A

        call    Lookup_Char

        ; move cursor left to overwrite

        movlw   00010000B
        call    LCD_Send_Byte_I

        movf    current_char, W, A
        call    LCD_Send_Byte_D

        clrf    idle_timer, A

        return


; ==========================================================
; NEW KEY PRESSED
; ==========================================================

New_Key:
	
	bcf	GIE
	bcf	TMR0IE
    
        call    Lock_Character

        movff   PRODL, last_key

        clrf    tap_count, A

        call    Lookup_Char

        movf    current_char, W, A
        call    LCD_Send_Byte_D

        clrf    idle_timer, A

        return


; ==========================================================
; CHECK IDLE TIMER FOR 1.5 SECOND TIMEOUT
; ==========================================================

Check_Timeout:

        movlw   150
        cpfseq  idle_timer, A
        return

        call    Lock_Character
        clrf    idle_timer, A

        return

end
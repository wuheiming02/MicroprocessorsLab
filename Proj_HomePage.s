#include <xc.inc>
; from Proj_Timer
extrn	TimerSetup, TimerInterrupt

; from KeyPad
extrn   KeyPad_Init, KeyPad_Read

; from LCD
extrn   LCD_Setup
extrn	LCD_Send_Byte_I
extrn   LCD_Send_Byte_D
extrn   clear_LCD
extrn	LCD_delay_x4us
extrn	LCD_delay_ms
    
extrn	MorseStart
extrn	NokiaStart
    
global	timer_counter, current_state, last_state, current_key, decoded_char
global	shift_counter, clear_counter, LCD_decoded_char
global	table_index, dummy_counter
    
global	HomePageStart
    
psect	udata_acs
timer_counter:	ds 1 ; track amount of time a key is pressed
current_state:	ds 1 ; whether a button is pressed or not
last_state:	ds 1 ; whether a button was pressed or not in the last check
current_key:	ds 1 ; the key being pressed
decoded_char:	ds 1 ; decoded character
    
shift_counter:	ds 1 ; number of times the display is shifted
clear_counter:	ds 1 ; number of spaces to clear on line 2
LCD_decoded_char: ds 1 ; the decoded character used in LCD file
    
table_index:	ds 1 ; nokia_table index  or morse_table index of the character specifed in bit_buffer
dummy_counter:	ds 1 ; column number for nokia_table or loop counter to interpret all the dots and dahses in bit_buffer

psect	code, abs
	
rst:
    org	0x0000	; reset vector
    goto    HomePageStart

int_hi:
    org	0x0008	; high vector, no low vector
    goto    TimerInterrupt
	
HomePageStart:
    clrf    timer_counter, A
    clrf    current_key, A
    
    call    LCD_Setup
    call    clear_LCD
	
    call    KeyPad_Init
    
DisplayHomepage:
    movlw   0x80 ; display character on line 1
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movlw 'E' ; print 'ENCRYPTION: A' on line 2
    call LCD_Send_Byte_D
    movlw 'N'
    call LCD_Send_Byte_D
    movlw 'C'
    call LCD_Send_Byte_D
    movlw 'R'
    call LCD_Send_Byte_D
    movlw 'Y'
    call LCD_Send_Byte_D
    movlw 'P'
    call LCD_Send_Byte_D
    movlw 'T'
    call LCD_Send_Byte_D
    movlw 'I'
    call LCD_Send_Byte_D
    movlw 'O'
    call LCD_Send_Byte_D
    movlw 'N'
    call LCD_Send_Byte_D
    movlw ':'
    call LCD_Send_Byte_D
    movlw ' '
    call LCD_Send_Byte_D
    movlw 'A'
    call LCD_Send_Byte_D
    
    movlw   0x80 ; display character on line 2
    addlw   0x40
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movlw 'D' ; print 'DECRYPTION: B' on line 2
    call LCD_Send_Byte_D
    movlw 'E'
    call LCD_Send_Byte_D
    movlw 'C'
    call LCD_Send_Byte_D
    movlw 'R'
    call LCD_Send_Byte_D
    movlw 'Y'
    call LCD_Send_Byte_D
    movlw 'P'
    call LCD_Send_Byte_D
    movlw 'T'
    call LCD_Send_Byte_D
    movlw 'I'
    call LCD_Send_Byte_D
    movlw 'O'
    call LCD_Send_Byte_D
    movlw 'N'
    call LCD_Send_Byte_D
    movlw ':'
    call LCD_Send_Byte_D
    movlw ' '
    call LCD_Send_Byte_D
    movlw 'B'
    call LCD_Send_Byte_D
    
WaitForInput:
    call    KeyPad_Read
    movwf   current_key, A
    
    movf    current_key, W, A
    xorlw   'A'
    bz	    ExecA
    
    movf    current_key, A
    xorlw   'B'
    bz	    ExecB
    
    movf    current_key, A
    xorlw   'F'
    bz	    ExecF
    
    bra	    WaitForInput
    
ExecA:
    call    KeyPad_Read
    
    xorlw   0xFF
    bz	    GotoNokia
    
    bra	    ExecA
    
ExecB:
    call    KeyPad_Read
    
    xorlw   0xFF
    bz	    GotoMorse
    
    bra	    ExecB
    
ExecF:
    call    KeyPad_Read
    
    xorlw   0xFF
    bz	    HomePageStart
    
    bra	    ExecF
    
GotoNokia:
    call    clear_LCD
    goto    NokiaStart
    
GotoMorse:
    call    clear_LCD
    goto    MorseStart
    
    end	    rst
    
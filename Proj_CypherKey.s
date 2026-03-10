#include <xc.inc>
    
extrn	KeyPad_Read

extrn	clear_LCD
extrn	LCD_Send_Byte_D
    
global	KeyEntry, ParseCypherKey

psect	udata_acs     
key_buffer:	ds 8
key_index:	ds 1

sub_char1:	ds 1
sub_char2:	ds 1
caesar_shift:	ds 1
shift_interval:	ds 1
    
temp_key:	ds 1
temp_value:	ds 1

    
psect	cypher_key, class=CODE
	
KeyEntry:
    call    clear_LCD
    clrf    key_index, A
    
    movlw   'K'
    call    LCD_Send_Byte_D
    movlw   'E'
    call    LCD_Send_Byte_D
    movlw   'Y'
    call    LCD_Send_Byte_D
    movlw   'S'
    call    LCD_Send_Byte_D
    movlw   ':'
    call    LCD_Send_Byte_D
    movlw   ' '
    call    LCD_Send_Byte_D
    
KeyEntryLoop:
    call    KeyPad_Read
    movwf   temp_key, A
    
    movf    temp_key, W, A
    xorlw   'C'
    bz	    ConfirmKey
    
    movlw   8
    cpfseq  key_index, A
    bra	    StoreDigit
    
    bra	    KeyLoop
    
StoreDigit:
    movlw   low(key_buffer)
    addwf   key_index, W, A
    movwf   FSR0L, A
    
    movlw   high(key_buffer)
    movwf   FSR0H, A
    
    movf    temp_key, W, A
    movwf   INDF0, A
    
    movf    temp_key, W, A
    call    LCD_Send_Byte_D
    
    incf    key_index, F, A
    bra	    KeyLoop
    
ConfirmKey:
    movlw   8
    cpfseq  key_index, A
    bra	    KeyLoop
    call    ParseCypherKey
    call    clear_LCD
    
    return
    
ParseCypherKey:
    movlw   low(key_buffer)
    movwf   FSR0L, A
    movlw   high(key_buffer)
    movwf   FSR0H, A
    
    movf    INDF0, W, A
    sublw   '0'
    addlw   temp_value
    
    movlw   10
    mullw   temp_value
    movf    PRODL, W, A
    movwf   sub_char1

    
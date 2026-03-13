#include <xc.inc>

global	LCDPrintDecoded, ShiftCursorRight, LCDPrintOverflow, ShiftDisplayLeft, LCDClearLine2
global	shift_counter
    
extrn	LCD_Send_Byte_D
extrn	LCD_Send_Byte_I
extrn	LCD_delay_ms
extrn	LCD_delay_x4us
    
extrn	lock_counter

psect	udata_acs
decoded_char:	ds 1
shift_counter:	ds 1
clear_counter:	ds 1
    
psect	NokiaLCD, class=CODE

LCDPrintDecoded:
    movwf   decoded_char, A
    
    movlw   0x80
    addwf   lock_counter, W, A
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movf    decoded_char, W, A
    call    LCD_Send_Byte_D

    movlw   00010000B   
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    return
    
ShiftCursorRight:
    movlw   00010100B   
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movlw   16
    cpfslt  lock_counter, A
    call    ShiftDisplayRight    
    
    return
    
ShiftDisplayRight:
    movlw   00011000B	    
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    incf    shift_counter, F, A
    
    return
    
ShiftDisplayLeft:
    movlw   00011100B	    
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    decf    shift_counter, F, A
    
    return
    
LCDClearLine2:
    movlw   0x40
    addlw   0x80
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movlw   32
    movwf   clear_counter, A
    
ClearLoop:
    movlw   ' '
    call    LCD_Send_Byte_D
    decfsz  clear_counter, F, A
    bra	    ClearLoop
    
    return
    
LCDPrintOverflow:
    call    LCDClearLine2
    
    movlw   0x40
    addlw   0x80
    addwf   shift_counter, W, A
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movlw 'O'
    call LCD_Send_Byte_D
    movlw 'V'
    call LCD_Send_Byte_D
    movlw 'E'
    call LCD_Send_Byte_D
    movlw 'R'
    call LCD_Send_Byte_D
    movlw 'F'
    call LCD_Send_Byte_D
    movlw 'L'
    call LCD_Send_Byte_D
    movlw 'O'
    call LCD_Send_Byte_D
    movlw 'W'
    call LCD_Send_Byte_D
    
    movlw   250
    call    LCD_delay_ms
    movlw   250
    call    LCD_delay_ms
    movlw   250
    call    LCD_delay_ms
    movlw   250
    call    LCD_delay_ms

    call    LCDClearLine2
    
    return

    
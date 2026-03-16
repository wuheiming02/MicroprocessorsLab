#include <xc.inc>

; from LCD
extrn	LCD_Send_Byte_D
extrn	LCD_Send_Byte_I
extrn	LCD_delay_ms
extrn	LCD_delay_x4us

; from ReadNokia
extrn	lock_counter
    
; from HomePage
extrn	shift_counter
extrn	clear_counter
extrn	LCD_decoded_char
    
global	LCDPrintDecoded, ShiftCursorRight, LCDPrintOverflow, LCDClearLine2
    
psect	NokiaLCD, class=CODE

LCDPrintDecoded:
    movwf   LCD_decoded_char, A ; place character in LCD_decoded_char
    
    movlw   0x80 ; move cursor to line 1[lock_counter]
    addwf   lock_counter, W, A
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movf    LCD_decoded_char, W, A ; display character
    call    LCD_Send_Byte_D

    movlw   00010000B ; shift cursor left by 1
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    return
    
ShiftCursorRight:
    movlw   00010100B ; shift cursor right by 1
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movlw   16 ; if there are more than 16 characters stored in message buffer
    cpfslt  lock_counter, A
    call    ShiftDisplayRight ; shift display by 1
    
    return
    
ShiftDisplayRight:
    movlw   00011000B ; shift display by 1	    
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    incf    shift_counter, F, A ; increment shift_counter
    
    return
    
LCDClearLine2:
    movlw   0x40 ; move cursor to line 2
    addlw   0x80
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movlw   32 ; set clear_counter to 32
    movwf   clear_counter, A
    
ClearLoop:
    movlw   ' ' ; replace space with ' ' 32 times
    call    LCD_Send_Byte_D
    decfsz  clear_counter, F, A
    bra	    ClearLoop
    
    return
    
LCDPrintOverflow:
    call    LCDClearLine2 ; clear line 2 of LCD
    
    movlw   0x40 ; move the cursor to line 2
    addlw   0x80
    addwf   shift_counter, W, A ; align cursor with left most edge with display after shifting
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movlw 'O' ; print 'Overflow' on line 2
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
    
    return

    
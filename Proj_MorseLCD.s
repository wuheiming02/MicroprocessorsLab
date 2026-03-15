#include <xc.inc>

; from LCD
extrn	LCD_Send_Byte_D
extrn	LCD_Send_Byte_I
extrn	LCD_delay_ms
extrn	LCD_delay_x4us

; from DecodeMorseCode
extrn	temp_symbol, bit_length
    
; from HomePage
extrn	shift_counter
extrn	clear_counter
extrn	LCD_decoded_char
    
global	LCDPrintDecodedMorse
global	LCDPrintSymbolMorse
global	LCDPrintErrorMorse
global	LCDPrintOverflowMorse
global	LCDClearLine2Morse
    
global	decoded_counter

psect	udata_acs
decoded_counter:ds 1 ; number of characters decoded
    
psect	MorseLCD, class=CODE

LCDPrintDecodedMorse:
    movwf   LCD_decoded_char, A ; place character in LCD_decoded_char
    
    movlw   0x80 ; display character on line 1[decoded_counter]
    addwf   decoded_counter, W, A
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movf    LCD_decoded_char, W, A
    call    LCD_Send_Byte_D
    incf    decoded_counter, F, A ; increment decoded_counter
    
    movlw   16 ; check if decoded count is less than 17
    cpfsgt  decoded_counter, A
    bra	    NoShift ; if yes branch to NoShift
    
    movlw   00011000B ; if no shift display once
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    incf    shift_counter, F, A ; increment shift counter
    
NoShift:
    call    LCDClearLine2Morse ; clear LCD line 2
    return
    
LCDPrintSymbolMorse:    
    movlw   0x40 ; move the cursor to second line
    addlw   0x80
    addwf   shift_counter, W, A ; add shift_counter
    addwf   bit_length, W, A ; add bit_length
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movf    temp_symbol, W, A ; print dot or dash
    call    LCD_Send_Byte_D
    
    return
    
    
LCDClearLine2Morse:
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
    
    movlw   0x40 ; move the cursor back to line 2
    addlw   0x80
    addwf   shift_counter, W, A ; align cursor with left most edge with display after shifting
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    return
    
    
LCDPrintErrorMorse:
    call    LCDClearLine2Morse ; clear LCD line 2
    
    movlw   0x40 ; move the cursor back to line 2
    addlw   0x80
    addwf   shift_counter, W, A ; align cursor with left most edge with display after shifting
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movlw 'E' ; print 'ERROR' on line 2
    call LCD_Send_Byte_D
    movlw 'R'
    call LCD_Send_Byte_D
    movlw 'R'
    call LCD_Send_Byte_D
    movlw 'O'
    call LCD_Send_Byte_D
    movlw 'R'
    call LCD_Send_Byte_D

    return
    
LCDPrintOverflowMorse:
    call    LCDClearLine2Morse ; clear LCD line 2
    
    movlw   0x40 ; move the cursor back to line 2
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

    
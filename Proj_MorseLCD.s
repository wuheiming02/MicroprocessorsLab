#include <xc.inc>

; from LCD
extrn	LCD_Send_Byte_D
extrn	LCD_Send_Byte_I
extrn	LCD_delay_ms
extrn	LCD_delay_x4us

; from DecodeMorseCode
extrn	temp_symbol, bit_length
    
global	LCDPrintDecoded
global	LCDPrintSymbol
global	LCDPrintError
global	LCDClearLine2
    
global	decoded_counter
global	shift_counter

psect	udata_acs
decoded_counter:	ds 1 ; number of characters decoded
shift_counter:	ds 1 ; number of times the display is shifted
clear_counter:	ds 1 ; number of spaces to clear on line 2
decoded_char:	ds 1 ; decoded character (different from the one in ReadMorseCode)
    
psect	MorseLCD, class=CODE

LCDPrintDecoded:
    movwf   decoded_char, A ; place character in decoded_char
    
    movlw   32 ; check if there are already 32 decoded character
    cpfseq  decoded_counter, A
    bra	    PrintChar ; if no print to character on line 1
    
    clrf    decoded_counter, A ; set decoded_counter to 0
    clrf    shift_counter, A ; set shift_counter to 0
    
    call    LCDPrintError ; display error mesage on line 2
    return
    
PrintChar:
    movlw   0x80 ; display character on line 1[decoded_counter]
    addwf   decoded_counter, W, A
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movf    decoded_char, W, A
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
    call    LCDClearLine2 ; clear LCD line 2
    return
    
LCDPrintSymbol:    
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
    
    movlw   0x40 ; move the cursor back to line 2
    addlw   0x80
    addwf   shift_counter, W, A ; align cursor with left most edge with display after shifting
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    return
    
    
LCDPrintError:
    call    LCDClearLine2 ; clear LCD line 2
    
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

    
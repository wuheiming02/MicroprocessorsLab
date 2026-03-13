#include <xc.inc>

global	LCDPrintDecoded
global	LCDPrintSymbol
global	LCDPrintError
global	LCDClearLine2
global	LCDShiftDisplayLeft
    
global	decoded_count
global	shift_count
global	line2_pos
    
extrn	LCD_Send_Byte_D
extrn	LCD_Send_Byte_I
extrn	LCD_delay_ms
extrn	LCD_delay_x4us
    
extrn	temp_symbol

psect	udata_acs
decoded_count:	ds 1
shift_count:	ds 1
line2_pos:	ds 1
clear_counter:	ds 1
decoded_char:	ds 1
    
psect	MorseLCD, class=CODE

LCDPrintDecoded:
    movwf   decoded_char, A
    
    movlw   32
    cpfseq  decoded_count, A
    bra	    PrintChar
    
    clrf    decoded_count, A
    clrf    shift_count, A
    
    call    LCDPrintError
    return
    
PrintChar:
    movlw   0x80
    addwf   decoded_count, W, A
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movf    decoded_char, W, A
    call    LCD_Send_Byte_D
    incf    decoded_count, F, A
    
    movlw   16
    cpfsgt  decoded_count, A
    bra	    NoShift
    
    movlw   00011000B
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    incf    shift_count, F, A
    
NoShift:
    call    LCDClearLine2
    return
    
LCDPrintSymbol:    
    movlw   0x40
    addlw   0x80
    addwf   shift_count, W, A
    addwf   line2_pos, W, A
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movf    temp_symbol, W, A
    call    LCD_Send_Byte_D
    incf    line2_pos, F, A
    
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
    
    clrf    line2_pos, A
    
    movlw   0x40
    addlw   0x80
    addwf   shift_count, W, A
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    return
    
    
LCDPrintError:
    call    LCDClearLine2
    
    movlw   0x40
    addlw   0x80
    addwf   shift_count, W, A
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    movlw 'E'
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
    
LCDShiftDisplayLeft:
    movlw   00011100B	    
    call    LCD_Send_Byte_I
    movlw   10
    call    LCD_delay_x4us
    
    decf    shift_count, F, A
    
    return

    
#include <xc.inc>

extrn	TimerSetup, TimerInterrupt

extrn   LCD_Send_Byte_D
extrn	LCD_delay_ms
    
extrn	LCDPrintSymbol
extrn	LCDPrintDecoded
extrn	LCDPrintError
extrn	LCDClearLine2
    
global	DecodeLetter, StoreSymbol, ClearBuffer, MorseError
global	temp_symbol, bit_buffer, bit_length

psect	udata_acs 
bit_buffer:	ds 1
bit_length:	ds 1
tree_index:	ds 1
counter:	ds 1
temp_bits:	ds 1
temp_symbol:	ds 1
alignment_counter:  ds 1

    
psect	decode_morse_code, class=CODE
	
morse_table:
    db	    '?','?','E','T','I','A','N','M'
    db	    'S','U','R','W','D','K','G','O'
    db	    'H','V','F','?','L','?','P','J'
    db	    'B','X','C','Y','Z','Q','?','?'
    db	    '5','4','?','3','?','?','?','2'
    db	    '?','?','?','?','?','?','?','1'
    db	    '6','?','?','?','?','?','?','?'
    db	    '7','?','?','?','8','?','9','0'

StoreSymbol:
    movwf   temp_symbol, A
    bcf	    STATUS, 0, A
    rlcf    bit_buffer, f, A
    
    movf    temp_symbol, W, A
    call    LCDPrintSymbol
    
    movf    temp_symbol, W, A
    xorlw   '-'
    bnz	    StoreDot
    
    bsf	    bit_buffer, 0, A
    
StoreDot:
    incf    bit_length, F, A
    
    return
    
DecodeLetter:
    movlw   6
    cpfslt  bit_length, A
    bra	    MorseError
    
    movlw   1
    movwf   tree_index, A
    
    movff   bit_buffer, temp_bits
    call    AlignBits
    
    movff   bit_length, counter
    
DecodeLoop:
    bcf	    STATUS, 0, A
    rlcf    temp_bits, F, A
    btfsc   STATUS, 0, A
    goto    DashBranch
    
DotBranch:
    bcf	    STATUS, 0, A
    rlcf    tree_index, F, A
    goto    NextSymbol
    
DashBranch:
    bcf	    STATUS, 0, A
    rlcf    tree_index, F, A
    incf    tree_index, F, A

NextSymbol:
    decfsz  counter, F, A
    goto    DecodeLoop
    
    movlw   low(morse_table)
    movwf   TBLPTRL, A
    movlw   high(morse_table)
    movwf   TBLPTRH, A
    movlw   low highword(morse_table)
    movwf   TBLPTRU, A

    movf    tree_index, W, A
    addwf   TBLPTRL, F, A
    btfsc   STATUS, 0, A
    incf    TBLPTRH, F, A
    btfsc   STATUS, 0, A
    incf    TBLPTRU, F, A
    
    tblrd*
    movf    TABLAT, W, A
    goto    ClearBuffer

ClearBuffer:
    clrf    bit_buffer, A
    clrf    bit_length, A
    return  
    
MorseError:
    call    LCDPrintError
    call    ClearBuffer
    
    movlw   250
    call    LCD_delay_ms
    movlw   250
    call    LCD_delay_ms
    movlw   250
    call    LCD_delay_ms
    movlw   250
    call    LCD_delay_ms

    call    LCDClearLine2
    
    movlw   '?'
    
    return
    
AlignBits:
    movf    bit_length, W, A
    sublw   8
    movwf   alignment_counter, A
    
AlignLoop:
    bcf	    STATUS, 0, A
    rlcf    temp_bits, F, A
    decfsz  alignment_counter, F, A
    goto    AlignLoop
    return
    

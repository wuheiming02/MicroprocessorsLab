#include <xc.inc>

; from Timer
extrn	TimerSetup, TimerInterrupt

; from LCD
extrn   LCD_Send_Byte_D
extrn	LCD_delay_ms
    
; from MorseLCD
extrn	LCDPrintSymbol
extrn	LCDPrintDecoded
extrn	LCDPrintError
extrn	LCDClearLine2
    
global	DecodeLetter, StoreSymbol, ClearBuffer, MorseError
global	temp_symbol, bit_buffer, bit_length

psect	udata_acs 
bit_buffer:	ds 1 ; holds dots and dashes as 0s and 1s
bit_length:	ds 1 ; how many dots and dashes are stored
tree_index:	ds 1 ; morse_table index of the character specifed in bit_buffer
counter:	ds 1 ; loop counter to interpret all the dots and dahses in bit_buffer
temp_bits:	ds 1 ; dummy varaible to hold bit_buffer to align the dot and dashes to the left
temp_symbol:	ds 1 ; dummy variable to hold '.' or '-' 
alignment_counter:  ds 1 ; number of times temp_bits have to be shifted before decoding

    
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
    movwf   temp_symbol, A ; store '.' or '-' in temp_symbol
    bcf	    STATUS, 0, A
    rlcf    bit_buffer, f, A ; shift bit_buffer left
    
    movf    temp_symbol, W, A
    call    LCDPrintSymbol ; display '.' or '-' on LCD line 2
    
    movf    temp_symbol, W, A
    xorlw   '-'
    bnz	    StoreDot
    
    bsf	    bit_buffer, 0, A ; set the last bit on the right to 1 if '-'
    
StoreDot:
    incf    bit_length, F, A ; increment bit_length
    
    return
    
DecodeLetter:
    movlw   6 ; if there are more than 5 dots or dashes inputted
    cpfslt  bit_length, A
    bra	    MorseError ; branch to MorseError
    
    movlw   1 ; start with a base tree_index value of 1
    movwf   tree_index, A 
    
    movff   bit_buffer, temp_bits ; copy bit_buffer into temp_bits
    call    AlignBits ; align temp_bits to the left
    
    movff   bit_length, counter ; copy bit_length into counter
    
DecodeLoop:
    bcf	    STATUS, 0, A ; check if left-most bit in temp_bits is 0 or 1
    rlcf    temp_bits, F, A 
    btfsc   STATUS, 0, A
    bra	    DashBranch ; if 1 branch to DashBranch
    bra	    DotBranch ; if 0 branch to DotBranch
    
DotBranch:
    bcf	    STATUS, 0, A ; multiply tree_index by 2
    rlcf    tree_index, F, A
    bra	    NextSymbol ; branch to NextSymbol to continue to next bit
    
DashBranch:
    bcf	    STATUS, 0, A ; multiply tree_index by 2 then increment
    rlcf    tree_index, F, A
    incf    tree_index, F, A
    bra	    NextSymbol ; branch to NextSymbol to continue to next bit

NextSymbol:
    decfsz  counter, F, A ; decrement counter
    bra	    DecodeLoop
    
    movlw   low(morse_table) ; find characrter in morse_table after all symbols have been processed
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
    movf    TABLAT, W, A ; move decoded character to W
    bra	    ClearBuffer

ClearBuffer:
    clrf    bit_buffer, A ; clear bit_buffer
    clrf    bit_length, A ; set bit_length to 0
    return  
    
MorseError:
    call    LCDPrintError ; print error message
    call    ClearBuffer ; clear buffer
    
    movlw   250 ; wait 1 second 
    call    LCD_delay_ms
    movlw   250
    call    LCD_delay_ms
    movlw   250
    call    LCD_delay_ms
    movlw   250
    call    LCD_delay_ms

    call    LCDClearLine2 ; clear error message 
    
    movlw   '?' ; move '?' to W 
    
    return
    
AlignBits:
    movf    bit_length, W, A ; work out how many times temp_bits have to be shifted 
    sublw   8
    movwf   alignment_counter, A
    
AlignLoop:
    bcf	    STATUS, 0, A ; shift temp_bits left until dots and dashses are aligned to the left
    rlcf    temp_bits, F, A
    decfsz  alignment_counter, F, A
    goto    AlignLoop
    return
    

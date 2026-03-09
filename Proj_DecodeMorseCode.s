#include <xc.inc>

extrn	TimerSetup, TimerInterrupt
extrn	temp_symbol

extrn   LCD_Send_Byte_D
    
global	DecodeLetter, StoreSymbol, ClearBuffer

psect	udata_acs 
bit_buffer:	ds 1
bit_length:	ds 1
tree_index:	ds 1
counter:	ds 1
temp_bits:	ds 1
alignment_counter:  ds 1

    
psect	decode_morse_code, class=CODE
	
morse_table:
    db	    '?','?','E','T','I','A','N','M'
    db	    'S','U','R','W','D','K','G','O'
    db	    'H','V','F','?','L','?','P','J'
    db	    'B','X','C','Y','Z','Q','?','?'
    db	    '5','4','?','3','?','?','?','2'
    db	    '?','?','?','?','?','?','?','1'
    db	    '?','?','?','?','?','?','?','?'
    db	    '7','?','?','?','8','?','9','0'

StoreSymbol:
    movwf   temp_symbol, A
    rlncf   bit_buffer, f, A
    
    movf    temp_symbol, W, A
    xorlw   '-'
    bnz	    StoreDot
    
    bsf	    bit_buffer, 0, A
    
StoreDot:
    incf    bit_length, F, A
    return
    
DecodeLetter:
    movlw   1
    movwf   tree_index, A
    
    movff   bit_buffer, temp_bits
    call    AlignBits
    
    movff   bit_length, counter
    
DecodeLoop:
    rlcf    temp_bits, F, A
    btfsc   STATUS, 0, A
    goto    DashBranch
    
DotBranch:
    rlcf    tree_index, F, A
    goto    NextSymbol
    
DashBranch:
    rlcf    tree_index, F, A
    incf    tree_index, F, A

NextSymbol:
    decfsz  counter, F, A
    goto    DecodeLoop
    
    movlw   low(morse_table)
    movwf   FSR0L, A
    movlw   high(morse_table)
    movwf   FSR0H, A
    
    movf    tree_index, W, A
    addwf   FSR0L, F, A
    btfsc   STATUS, 0, A
    incf    FSR0H, F, A
    
    movf    INDF0, W, A
    call    LCDPrintDecoded
    
    goto    ClearBuffer

ClearBuffer:
    clrf    bit_buffer, A
    clrf    bit_length, A
    return   
    
AlignBits:
    movf    bit_length, W, A
    sublw   8
    movwf   alignment_counter, A
    
AlignLoop:
    rlcf    temp_bits, F, A
    decfsz  alignment_counter, F, A
    goto    AlignLoop
    return
    

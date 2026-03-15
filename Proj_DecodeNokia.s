#include <xc.inc>
    
; from ReadNokia
extrn	key_counter
extrn   current_key
    
global	DecodeChar

psect	udata_acs   
table_index:	ds 1 ; nokia_table index 
dummy_counter:	ds 1 ; column number for nokia_table

    
psect	DecodeNokia, class=CODE
	
nokia_table:
    db	    ' ','0',' ',' ',' '
    db	    '1',' ',' ',' ',' '
    db	    'A','B','C','2',' '
    db	    'D','E','F','3',' '
    db	    'G','H','I','4',' '
    db	    'J','K','L','5',' '
    db	    'M','N','O','6',' '
    db	    'P','Q','R','S','7'
    db	    'T','U','V','8',' '
    db	    'W','X','Y','Z','9'

DecodeChar:
    movff   key_counter, dummy_counter ; copy key_counter into dummy_counter
    decf    dummy_counter, F, A ; decrement dummy_counter because column number starts at 0
    
    movf    current_key, W, A 
    addlw   -'0' ; translate current_key from ASCII to number
    mullw   5 ; multiply by 5
    movf    PRODL, W, A
    addwf   dummy_counter, W, A ; add dummy_counter
    movwf   table_index, A ; store number in table_index
    
    movlw   low(nokia_table)
    movwf   TBLPTRL, A
    movlw   high(nokia_table)
    movwf   TBLPTRH, A
    movlw   low highword(nokia_table)
    movwf   TBLPTRU, A

    movf    table_index, W, A
    addwf   TBLPTRL, F, A
    movlw   0
    addwfc  TBLPTRH, F, A
    addwfc  TBLPTRU, F, A
    
    tblrd*
    movf    TABLAT, W, A ; move decoded character to W
    
    return
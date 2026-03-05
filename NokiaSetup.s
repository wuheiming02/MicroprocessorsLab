#include <xc.inc>

; ==========================================================
; Keypad Text Entry Setup
; Nokia-style multi-tap text entry system
; ==========================================================

global TextEntry_Init
global Lookup_Char
global Lock_Character
   
global last_key
global tap_count
global current_char
global idle_timer

; ==========================================================
; VARIABLES (ACCESS RAM)
; ==========================================================

psect udata_acs

last_key:       ds 1     ; previous key pressed
tap_count:      ds 1     ; number of presses of the same key
current_char:   ds 1     ; currently displayed character
idle_timer:     ds 1     ; counts time since last press
msg_index:      ds 1     ; index of message buffer

msg_buffer:     ds 32    ; final message storage (max 32)

; ==========================================================
; INITIALISATION ROUTINE
; ==========================================================

psect keypad_text_code, class=CODE

TextEntry_Init:

        ; Clear state variables
        clrf    last_key, A
        clrf    tap_count, A
        clrf    current_char, A
        clrf    idle_timer, A
        clrf    msg_index, A

        return


; ==========================================================
; CHARACTER LOCK ROUTINE
; Stores current_char into message buffer
; ==========================================================

Lock_Character:

        movf    last_key, W, A
        ;bz      Lock_End        ; if no key active, exit

        ; Calculate pointer to msg_buffer[msg_index]

        movf    msg_index, W, A
        addlw   low msg_buffer
        movwf   FSR0L, A

        movlw   high msg_buffer
        movwf   FSR0H, A

        ; Store character

        movf    current_char, W, A
        movwf   INDF0, A

        incf    msg_index, F, A

        ; reset typing state

        clrf    last_key, A
        clrf    tap_count, A

Lock_End:
        return


; ==========================================================
; MULTI-TAP LOOKUP TABLE
; ==========================================================

psect data

KeyTable:

        ; key2
        db 'A','B','C','2'

        ; key3
        db 'D','E','F','3'

        ; key4
        db 'G','H','I','4'

        ; key5
        db 'J','K','L','5'

        ; key6
        db 'M','N','O','6'

        ; key7
        db 'P','Q','R','S','7'

        ; key8
        db 'T','U','V','8'

        ; key9
        db 'W','X','Y','Z','9'

; ==========================================================
; LOOKUP CHARACTER BASED ON KEY + TAP COUNT
; ==========================================================

psect keypad_text_code

Lookup_Char:

        ; last_key contains ASCII key

        movf    last_key, W, A
        addlw   -'2'            ; convert ASCII to index
        mullw   4               ; each group length = 4

        movf    PRODL, W, A
        movwf   TBLPTRL, A

        movlw   high(KeyTable)
        movwf   TBLPTRH, A

        movlw   low(KeyTable)
        addwf   TBLPTRL, F, A

        ; add tap_count offset

        movf    tap_count, W, A
        andlw   0x03
        addwf   TBLPTRL, F, A

        tblrd*
        movff   TABLAT, current_char

        return

end



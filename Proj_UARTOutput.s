#include <xc.inc>

; ============================================================
; Proj_UARTOutput.s  -  Transmit message_buffer over UART
;
; Background
; ----------
; Encryption is now performed in-place directly into
; message_buffer (see Proj_Encrypt.s).  There is no separate
; enc_buffer any more.  Both the plaintext and encrypted
; transmissions therefore read from the same buffer;  they are
; distinguished only by the label prepended to the message.
;
; ACCESS RAM USAGE
; ----------------
; Previous version declared two access RAM variables:
;   UART_copy_count  (1 byte)
;   UART_total_len   (1 byte)
;
; Both are eliminated in this version:
;
;   UART_copy_count - replaced by using UART_counter from
;     Prj_UARTSetup.s, which is already in access RAM and is
;     idle between transmissions.  We declare it extrn here
;     and reuse it as our copy loop counter.
;
;   UART_total_len  - the total length (label + data + CRLF)
;     is computed once into W and passed directly to
;     UART_Transmit_Message without staging it in a variable.
;
; Net access RAM saving: 2 bytes.
;
; ============================================================
; Transmission format
; -------------------
; Both routines assemble the following sequence in myArray
; before handing off to UART_Transmit_Message:
;
;   Bytes 0-4  : label ("MSG: " or "ENC: ")
;   Bytes 5..N : message_buffer[0..lock_counter-1]
;   Byte  N+1  : 0x0D  (carriage return)
;   Byte  N+2  : 0x0A  (line feed)
;
;   Total length = 5 + lock_counter + 2 = lock_counter + 7
;
; UART_Transmit_Message (Proj_UARTSetup.s) expects:
;   FSR2 = pointer to first byte to send
;   W    = total byte count
; It reads via POSTINC2 (auto-increment) until count expires.
;
; ============================================================
; PUBLIC SYMBOLS
; ============================================================
global  UART_Out_Plain          ; transmit with "MSG: " label
global  UART_Out_Encrypted      ; transmit with "ENC: " label
global  UART_Out_Key            ; transmit with "KEY: " label + 8 key digits

; ============================================================
; EXTERNAL SYMBOLS
; ============================================================

; From Proj_UARTSetup.s
extrn   UART_Transmit_Message   ; FSR2 = ptr, W = length
extrn   UART_counter            ; 1-byte access RAM counter reused
                                ; here as copy loop counter

; From Proj_ReadNokia.s
extrn   message_buffer          ; 32-byte buffer (plain or encrypted)
extrn   lock_counter            ; number of valid bytes in buffer
				
; From Proj_Encrypt.s
extrn   key_digits              ; 8 raw ASCII digit bytes of the encryption key

; ============================================================
; CONSTANTS
; ============================================================
LABEL_LEN   EQU 5               ; "MSG: " or "ENC: " = 5 bytes
CRLF_LEN    EQU 2               ; CR + LF
OVERHEAD    EQU LABEL_LEN + CRLF_LEN   ; 7 bytes added to every message

; ============================================================
; RAM  (no access RAM declared here - see background above)
; ============================================================

; ---- Bank 4 staging array ----
; Placed at 0x400, matching the original Prj_UARTOutput.s so
; that no linker script changes are needed.
; Maximum content: 5 (label) + 32 (data) + 2 (CRLF) = 39 bytes.
; 128 bytes allocated to match the original file exactly.
psect   udata_bank4
myArray:    ds 0x80

; ============================================================
; CODE
; ============================================================
psect   uart_out_code, class=CODE

; ============================================================
; UART_Out_Plain
; ============================================================
; Prepend "MSG: ", copy message_buffer, append CR+LF, transmit.
; ============================================================
UART_Out_Plain:

        ; ---- Write label "MSG: " into myArray[0..4] ----
        lfsr    0, myArray          ; FSR0 = write pointer

        movlw   'M'
        movwf   POSTINC0, A         ; myArray[0] = 'M', FSR0++
        movlw   'S'
        movwf   POSTINC0, A
        movlw   'G'
        movwf   POSTINC0, A
        movlw   ':'
        movwf   POSTINC0, A
        movlw   ' '
        movwf   POSTINC0, A         ; myArray[4] = ' ', FSR0 -> [5]

        ; ---- Copy message_buffer into myArray[5..] ----
        call    UO_CopyBuffer

        ; ---- Append CR + LF ----
        movlw   0x0D
        movwf   POSTINC0, A
        movlw   0x0A
        movwf   POSTINC0, A

        ; ---- Transmit ----
        ; Total length = lock_counter + 7
        movf    lock_counter, W, A
        addlw   OVERHEAD            ; W = lock_counter + 7
        lfsr    2, myArray          ; FSR2 = start of staging buffer
        call    UART_Transmit_Message
        return

; ============================================================
; UART_Out_Encrypted
; ============================================================
; Identical flow to UART_Out_Plain but uses "ENC: " as label.
; message_buffer already holds the encrypted content after
; Encrypt_Run has completed, so no separate source is needed.
; ============================================================
UART_Out_Encrypted:

        ; ---- Write label "ENC: " into myArray[0..4] ----
        lfsr    0, myArray

        movlw   'E'
        movwf   POSTINC0, A
        movlw   'N'
        movwf   POSTINC0, A
        movlw   'C'
        movwf   POSTINC0, A
        movlw   ':'
        movwf   POSTINC0, A
        movlw   ' '
        movwf   POSTINC0, A         ; FSR0 -> myArray[5]

        ; ---- Copy message_buffer into myArray[5..] ----
        call    UO_CopyBuffer

        ; ---- Append CR + LF ----
        movlw   0x0D
        movwf   POSTINC0, A
        movlw   0x0A
        movwf   POSTINC0, A

        ; ---- Transmit ----
        movf    lock_counter, W, A
        addlw   OVERHEAD
        lfsr    2, myArray
        call    UART_Transmit_Message
        return

; ============================================================
; UART_Out_Key
; ============================================================
; Transmit the 8-digit encryption key with "KEY: " label.
; Sends the raw ASCII digits from key_digits[0..7] exactly
; as the user typed them (e.g. "KEY: 08130703\r\n").
; Fixed length: label(5) + key digits(8) + CRLF(2) = 15 bytes.
; ============================================================
UART_Out_Key:
 
        ; ---- Write label "KEY: " into myArray[0..4] ----
        lfsr    0, myArray
 
        movlw   'K'
        movwf   POSTINC0, A
        movlw   'E'
        movwf   POSTINC0, A
        movlw   'Y'
        movwf   POSTINC0, A
        movlw   ':'
        movwf   POSTINC0, A
        movlw   ' '
        movwf   POSTINC0, A         ; FSR0 -> myArray[5]
 
        ; ---- Copy key_digits[0..7] into myArray[5..12] ----
        ; Fixed 8 bytes: no lock_counter needed
        movlw   8
        movwf   UART_counter, A     ; loop counter = 8
 
        lfsr    1, key_digits       ; FSR1 = read pointer
 
UO_KeyCopyLoop:
        movf    POSTINC1, W, A      ; W = *FSR1, FSR1++
        movwf   POSTINC0, A         ; *FSR0 = W, FSR0++
        decfsz  UART_counter, F, A
        bra     UO_KeyCopyLoop
 
        ; ---- Append CR + LF ----
        movlw   0x0D
        movwf   POSTINC0, A
        movlw   0x0A
        movwf   POSTINC0, A
 
        ; ---- Transmit: 5 (label) + 8 (key) + 2 (CRLF) = 15 bytes ----
        movlw   15
        lfsr    2, myArray
        call    UART_Transmit_Message
        return	
	
; ============================================================
; UO_CopyBuffer  (private)
; ============================================================
; Copy lock_counter bytes from message_buffer into myArray
; starting at the current FSR0 position.
;
; On entry:  FSR0 points to the next free byte in myArray
;            (i.e. myArray[5] after the label has been written)
; On exit:   FSR0 points one past the last byte written
;
; Uses UART_counter (from Prj_UARTSetup.s) as the loop
; counter.  This is safe because UART_Transmit_Message is not
; called until after this routine returns, so UART_counter is
; idle while the copy runs.
;
; FSR1 is used as the read pointer into message_buffer.
; FSR2 is left untouched so it is clean for the subsequent
; UART_Transmit_Message call.
; ============================================================
UO_CopyBuffer:
        movf    lock_counter, W, A
        movwf   UART_counter, A     ; loop counter = lock_counter

        movf    UART_counter, W, A
        bz      UO_CopyDone         ; nothing to copy if buffer empty

        lfsr    1, message_buffer   ; FSR1 = read pointer

UO_CopyLoop:
        movf    POSTINC1, W, A      ; W = *FSR1, FSR1++
        movwf   POSTINC0, A         ; *FSR0 = W, FSR0++
        decfsz  UART_counter, F, A  ; UART_counter--; skip if zero
        bra     UO_CopyLoop

UO_CopyDone:
        return

        end

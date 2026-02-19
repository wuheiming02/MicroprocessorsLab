#include <xc.inc>

extrn  KeyPad_Init, KeyPad_Read
extrn  LCD_Setup, LCD_Send_Byte_D

psect  code, abs

org 0x0000
goto    setup

org 0x0100

setup:
        call    LCD_Setup         ; Initialise LCD
        call    KeyPad_Init       ; Initialise keypad
        goto    main_loop


; ============================================================
; MAIN LOOP
; Continuously read keypad and display ASCII on LCD
; ============================================================
main_loop:

        call    KeyPad_Read       ; Read key
        movwf   WREG              ; ASCII returned in W

        xorlw   0xFF              ; Check invalid
        bz      main_loop         ; If no key, then keep looping

        call    LCD_Send_Byte_D   ; Display character

        call    Long_Delay       

        goto    main_loop


; Simple delay
Long_Delay:
        movlw   0xFF
        movwf   0x20
LD1:    decfsz  0x20, F
        bra     LD1
        return

        end



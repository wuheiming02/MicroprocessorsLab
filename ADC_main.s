Main loop code: 
#include <xc.inc>

; Final
extrn   LCD_Setup
extrn   LCD_Send_Byte_D
extrn   LCD_Send_Byte_I
extrn   clear_LCD
extrn   LCD_delay_ms

extrn   Process_ADC     ; from adc_math.asm
extrn   ADC_Setup
extrn   ADC_Read

global  rst

psect code, abs

org 0x0000
rst:
    goto setup

setup:
    call    LCD_Setup
    call    ADC_Setup
    call    clear_LCD
    goto    main_loop

main_loop:

    call    ADC_Read          ; take measurement
    call    Process_ADC       ; convert to DIG3?DIG0

    call    clear_LCD

    ; Thousands
    movf    DIG3, W
    addlw   0x30
    call    LCD_Send_Byte_D

    ; Decimal point
    movlw   '.'
    call    LCD_Send_Byte_D

    ; Hundreds
    movf    DIG2, W
    addlw   0x30
    call    LCD_Send_Byte_D

    ; Tens
    movf    DIG1, W
    addlw   0x30
    call    LCD_Send_Byte_D

    ; Units
    movf    DIG0, W
    addlw   0x30
    call    LCD_Send_Byte_D

    movlw   200
    call    LCD_delay_ms      ; slow update

    goto    main_loop
    
end



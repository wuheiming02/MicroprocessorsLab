; Main loop code:
#include <xc.inc>

; Final
extrn   LCD_Setup
extrn   LCD_Send_Byte_D
extrn   LCD_Send_Byte_I
extrn   clear_LCD
extrn   LCD_delay_ms

extrn   Process_ADC    
extrn   ADC_Setup
extrn   ADC_Read
   
extrn   DIG3
extrn   DIG2
extrn   DIG1
extrn   DIG0

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

    ; Move the cursor to the start to avoid LCD flicker from clear_LCD
;    movlw   0x80
;    call    LCD_Send_Byte_I
    
    ; Thousands
    movf    DIG3, W, A
    addlw   0x30
    call    LCD_Send_Byte_D

    ; Decimal point
    movlw   '.'
    call    LCD_Send_Byte_D

    ; Hundreds
    movf    DIG2, W, A
    addlw   0x30
    call    LCD_Send_Byte_D

    ; Tens
    movf    DIG1, W, A
    addlw   0x30
    call    LCD_Send_Byte_D

    ; Units
    movf    DIG0, W, A
    addlw   0x30
    call    LCD_Send_Byte_D
   
    ; Space
    movlw   ' '
    ; call    LCD_Send_Byte_D
   
    ; Voltage unit V
    movlw   'V'
    ; call    LCD_Send_Byte_D
    
;    movf   ADRESL, W
;    call    LCD_Send_Byte_D
;    movf   ADRESH, W
;    call    LCD_Send_Byte_D
   
    ; Delay
    movlw   200
    call    LCD_delay_ms      ; slow update
    
  

    goto    main_loop
   
end



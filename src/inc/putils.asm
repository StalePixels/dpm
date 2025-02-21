;-----------------------------------------------------------------------------
; .DPM Utility procedures
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------

putil_PrintStringPointedAtHL:
        ei                          ; Incase we need to scroll the screen
.loop:
        ld a, (hl)                  ; Load character into A
        inc hl                      ; Shift pointer to next character
        and a                       ; And A with self, fast zero check
        jr z, .return               ; if zero(null), we're done
        rst $10                     ; m_PrintCharInA
        jr .loop                    ; And do it all again
.return:
        di                          ; Disable Interupts for paging, etc
        ret

; Output the hex value of the 16-bit number stored in HL
;   Uses A, C
putil_PrintHex16AtHL:
        ld      c,h                 ; Load the first byte (high-value)
        call    putil_PrintHex8
        ld      c,l                 ; Load the low-value
        ; Fall through for second byte

; Output the hex value of the 8-bit number stored in C
;   Uses A
putil_PrintHex8:
        ld      a,c
        rra
        rra
        rra
        rra
        ; First nybble
        call    putil_PrintIntNybbleAsHex
        ld      a,c
        ; Fall through for second nybble
putil_PrintIntNybbleAsHex:
        and     $0F                 ; Mask lower nybble
        add     a,$90               ;   Add constants
        daa                         ;   Adjust for BCD
        adc     a,$40               ;   Add second constant
        daa                         ;   Finish adjusting
        m_PrintCharInA              ; Show the value
        ret

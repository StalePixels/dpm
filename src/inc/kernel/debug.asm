;-----------------------------------------------------------------------------
; -- DPM Debugging helpers - not in production build
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FCB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------
    MODULE KERNEL_DEBUG
tm_a_loc0:
        push    hl
        ld      hl, 0*cellBytes
        jp tm_a_to_hl
tm_a_loc2:
        push    hl
        ld      hl, 2*cellBytes
        jp tm_a_to_hl
tm_a_loc4:
        push    hl
        ld      hl, 4*cellBytes
        jp tm_a_to_hl
tm_a_loc6:
        push    hl
        ld      hl, 6*cellBytes
        jp tm_a_to_hl
tm_a_loc8:
        push    hl
        ld      hl, 8*cellBytes
        jp tm_a_to_hl
tm_a_loc10:
        push    hl
        ld      hl, 10*cellBytes
        jp tm_a_to_hl
tm_a_loc12:
        push    hl
        ld      hl, 12*cellBytes
        jp tm_a_to_hl
tm_a_loc14:
        push    hl
        ld      hl, 14*cellBytes
        jp tm_a_to_hl
tm_a_loc16:
        push    hl
        ld      hl, 16*cellBytes
        jp tm_a_to_hl
tm_a_loc18:
        push    hl
        ld      hl, 18*cellBytes
        jp tm_a_to_hl
tm_a_loc20:
        push    hl
        ld      hl, 20*cellBytes
        jp tm_a_to_hl
tm_a_loc22:
        push    hl
        ld      hl, 22*cellBytes
        jp tm_a_to_hl
        
tm_a_loc24:
        push    hl
        ld      hl, 24*cellBytes
        jp tm_a_to_hl
tm_a_loc26:
        push    hl
        ld      hl, 26*cellBytes
        jp tm_a_to_hl
tm_a_loc28:
        push    hl
        ld      hl, 28*cellBytes
        jp tm_a_to_hl
tm_a_loc30:
        push    hl
        ld      hl, 30*cellBytes
        jp tm_a_to_hl
tm_a_loc32:
        push    hl
        ld      hl, 32*cellBytes
        jp tm_a_to_hl
tm_a_loc34:
        push    hl
        ld      hl, 34*cellBytes
        jp tm_a_to_hl
tm_a_loc36:
        push    hl
        ld      hl, 36*cellBytes
        jp tm_a_to_hl
tm_a_loc38:
        push    hl
        ld      hl, 38*cellBytes
        jp tm_a_to_hl
tm_a_loc40:
        push    hl
        ld      hl, 40*cellBytes
        jp tm_a_to_hl
tm_a_loc42:
        push    hl
        ld      hl, 42*cellBytes
        jp tm_a_to_hl
tm_a_loc44:
        push    hl
        ld      hl, 44*cellBytes
        jp tm_a_to_hl
tm_a_loc46:
        push    hl
        ld      hl, 46*cellBytes
        jp tm_a_to_hl
tm_a_loc48:
        push    hl
        ld      hl, 48*cellBytes
        jp tm_a_to_hl
tm_a_loc50:
        push    hl
        ld      hl, 50*cellBytes
        jp tm_a_to_hl
tm_a_loc52:
        push    hl
        ld      hl, 52*cellBytes
        jp tm_a_to_hl
tm_a_loc54:
        push    hl
        ld      hl, 54*cellBytes
        jp tm_a_to_hl
tm_a_loc56:
        push    hl
        ld      hl, 56*cellBytes
        jp tm_a_to_hl
tm_a_loc58:
        push    hl
        ld      hl, 58*cellBytes
        jp tm_a_to_hl
tm_a_loc60:
        push    hl
        ld      hl, 60*cellBytes
        jp tm_a_to_hl
tm_a_loc62:
        push    hl
        ld      hl, 62*cellBytes
        jp tm_a_to_hl
tm_a_loc64:
        push    hl
        ld      hl, 64*cellBytes
        jp tm_a_to_hl
tm_a_loc66:
        push    hl
        ld      hl, 66*cellBytes
        jp tm_a_to_hl
tm_a_loc68:
        push    hl
        ld      hl, 68*cellBytes
        jp tm_a_to_hl
tm_a_loc70:
        push    hl
        ld      hl, 70*cellBytes
        jp tm_a_to_hl
tm_a_loc72:
        push    hl
        ld      hl, 72*cellBytes
        jp tm_a_to_hl
tm_a_loc74:
        push    hl
        ld      hl, 74*cellBytes
        jp tm_a_to_hl
tm_a_loc76:
        push    hl
        ld      hl, 76*cellBytes
        jp tm_a_to_hl
tm_a_loc78:
        push    hl
        ld      hl, 78*cellBytes
        jp tm_a_to_hl

tm_a_to_hl:                     ; HL = the column's offset in display row 31
        push    af              ; Debug routines need to preserve everything
        push    bc
        push    de
        ld      c, a            ; Copy our debug value to C for later
        push    hl
        ld      a, 31
        call    KERNEL_TERM.display_row_addr
        pop     de
        add     hl, de
        pop     de
        call    KERNEL_TERM.map_graphics_mem
        ld      a, c
        rra : rra : rra : rra   ; First nybble now in Least Significant 4 bits
        
        call    nybble_to_ASCIIhex
        ld      (hl), a             ; Place Higher Nybble Hex onto tilemap
        inc     hl
        ld      (hl), defaultAttr
        
        ld      a,c                 ; Get original hex value back
        call    nybble_to_ASCIIhex
        inc     hl
        ld      (hl), a             ; Place Lower Nybble Hex in the next cell
        inc     hl
        ld      (hl), defaultAttr
        
        call    KERNEL_TERM.unmap_graphics_mem
        pop     bc
        pop     af
        pop     hl
        ret

; take a nybble in A, and turn it into an ASCII value
nybble_to_ASCIIhex:
        and     $0F
        add     a, $90               ;   Add constants
        daa                         ;   Adjust for BCD
        adc     a, $40               ;   Add second constant
        daa                         ;   Finish adjusting
        ret

; Print a CRLF, 
print_crlf:
        push    af
        ld      a, KERNEL_KEYBOARD.CR
        call    KERNEL_TERM.process
        ld      a, KERNEL_KEYBOARD.LF
        call    KERNEL_TERM.process
        pop     af
        ret
        
print_fcb:
        ret

print_esxdos_buffer:
        push    hl
        push    af
        ld      hl, KERNEL_BDOS.current_esxdos.filepath
        call    KERNEL.kr_print_string_hl
        ld      a, ' '
        call    KERNEL_TERM.process
        ld      hl, KERNEL_BDOS.current_esxdos.filename
        call    KERNEL.kr_print_string_hl
        call    KERNEL_DEBUG.print_crlf
        pop     af
        pop     hl
        ret

pause:
        push    hl
        push    af
        ; waste some time
        ld	hl,0
.loop:
        dec	    hl
        ld	    a,h
        or	    l
        jp      nz, .loop
        pop     af
        pop     hl
        ret

open__string:
        DB "OPEN:", 0
copy__string:
        DB "COPY:", 0
read__string:
        DB "READ:", 0
    ENDMODULE
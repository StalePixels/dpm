;-----------------------------------------------------------------------------
; -- DPM Keyboard Driver
; 
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FCB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------
    MODULE KERNEL_MATHS
; Generic routines to handle some of the more complex maths, in kernel memoryspace


;
;-----------------------------------------------------------------------------
; Pass in 32-bit number in BCDE, multiply by 128, and return answer in BCDE
;     (x128 can be computed as <<8 then >>1)
;-----------------------------------------------------------------------------
mul_bcde_by_128:
        ld      b, c
        ld      c, d
        ld      d, e
        ld      e, 0                        ; 8 place left shift complete
        srl     b
        rr      c
        rr      d
        rr      e                           ; And shift 1 back again
        ret
;
;-----------------------------------------------------------------------------
; Pass in 32-bit number in BCDE, increment, and return answer in BCDE.
;-----------------------------------------------------------------------------
inc_bcde:
        ld      a, 1
        add     a, e                        ; Add 1 to E
        ld      e, a                        ; Put the result back in E
        ld      a, 0                           ; Wipe A
        adc     a, d                        ; Add the Carry Flag to D
        ld      d, a                        ; Put the results back in D
        ld      a, 0                           ; Wipe A
        adc     a, c                        ; Add the Carry Flag to C
        ld      c, a                        ; Put the results back in C
        ld      a, 0                           ; Wipe A
        adc     a, b                        ; Add the Carry Flag to B
        ld      b, a                        ; Put the results back in B
        ret
        
    ENDMODULE
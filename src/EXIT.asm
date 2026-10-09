;-----------------------------------------------------------------------------
; EXIT.COM
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; Ends DP/M and returns to NextZXOS. DP/M closes every open file first.
;
; It calls function $00, exit, of DPM control, the BIOS jump table entry
; BIOS_CONTROL_OFS bytes past the BIOS warm boot entry, whose address is at
; $0001. The call does not return. Assembled on its own into EXIT.COM, a
; CP/M transient at TPA_A.
;-----------------------------------------------------------------------------
    DEVICE zxspectrumnext
    OPT reset --zxnext --syntax=abfw

    INCLUDE "inc/addresses.asm"                 ; TPA_A, REBOOT_A, BIOS_CONTROL_OFS

        ORG     TPA_A
exit_start:
        ld      hl, (REBOOT_A+1)        ; The BIOS warm boot entry
        ld      de, BIOS_CONTROL_OFS
        add     hl, de
        ld      c, 0                    ; Exit
        jp      (hl)                    ; Does not return
exit_end:

        SAVEBIN "../build/EXIT.COM",exit_start,exit_end-exit_start

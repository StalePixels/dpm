;-----------------------------------------------------------------------------
; EXIT.COM
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; Ends DP/M and returns to NextZXOS. DP/M closes every open file first.
;
; It calls DP/M's exit entry in the BIOS jump table, BIOS_EXIT_OFS bytes past
; the BIOS warm boot entry, whose address is at $0001. The entry does not
; return. Assembled on its own into EXIT.COM, a CP/M transient at TPA_A.
;-----------------------------------------------------------------------------
    DEVICE zxspectrumnext
    OPT reset --zxnext --syntax=abfw

    INCLUDE "inc/addresses.asm"                 ; TPA_A, REBOOT_A, BIOS_EXIT_OFS

        ORG     TPA_A
exit_start:
        ld      hl, (REBOOT_A+1)        ; The BIOS warm boot entry
        ld      de, BIOS_EXIT_OFS
        add     hl, de
        jp      (hl)                    ; Does not return
exit_end:

        SAVEBIN "../build/EXIT.COM",exit_start,exit_end-exit_start

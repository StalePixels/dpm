;-----------------------------------------------------------------------------
; .DPM CSpect Debugger Helper Stuff
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------


m_CSpect_BREAK MACRO
        DW  0x00FD
    ENDM

m_CSpect_EXIT MACRO
        DW  0x00DD
    ENDM
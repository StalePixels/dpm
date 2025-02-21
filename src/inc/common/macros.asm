;-----------------------------------------------------------------------------
; .DPM Helper Macros
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------

; Dirties HL
;
; Print a Message with ROM
m_PrintMsg  MACRO Address
        ld      hl, Address
        call    putil_PrintStringPointedAtHL
    ENDM
    
m_PrintCharInA MACRO
        rst $10
    ENDM

; Dirties BC 
; Leaves register result in A
;
; Reads a NextReg value pointed to by A
m_NextRegRead_c MACRO Register
        ld bc, TBBLUE_REGISTER_SELECT_P_243B
        ld a, Register
       
        out     (c), a
        inc     b
        in      a, (c)
    ENDM
    
; Dirties BC 
; Leaves register result in E
;
; Reads a NextReg value pointed to by E
m_NextRegRead_e MACRO Register
        ld bc, TBBLUE_REGISTER_SELECT_P_243B
        ld e, Register
       
        out     (c), e
        inc     b
        in      e, (c)
    ENDM

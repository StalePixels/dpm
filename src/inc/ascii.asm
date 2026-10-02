;-----------------------------------------------------------------------------
; .DPM ASCII control codes
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
; Shared by the kernel (DPM.asm) and the CCP (CCP.asm), which are assembled
; separately. The codes live in the KERNEL_KEYBOARD module, so both refer to
; them as KERNEL_KEYBOARD.CR and so on.
;-----------------------------------------------------------------------------
    MODULE KERNEL_KEYBOARD

ESC             EQU     $1b
CTR_C           EQU     $03     ;control-c
CTR_E           EQU     $05     ;control-e
BS              EQU     $08     ;backspace

TAB             EQU     $09     ;tab
LF              EQU     $0A     ;line feed
FF              EQU     $0C     ;form feed
CR              EQU     $0D     ;carriage return

CTR_P           EQU     $10     ;control-p
CTR_R           EQU     $12     ;control-r
CTR_S           EQU     $13     ;control-s
CTR_U           EQU     $15     ;control-u
CTR_X           EQU     $18     ;control-x
CTR_Z           EQU     $1A     ;control-z (end-of-file mark)
DEL             EQU     $7F     ;rubout

    ENDMODULE

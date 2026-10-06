;-----------------------------------------------------------------------------
; -- DPM kernel
; 
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------
    ORG     KERNEL_A;
    
KR_STACK_SIZE   EQU         $80
    DISPLAY "kernel ORG\t:\t",/H,$
kernel_start:
    INCLUDE "inc/kernel/ROM.asm"
    INCLUDE "inc/kernel/maths.asm"
    INCLUDE "inc/kernel/BIOS.asm"
    INCLUDE "inc/kernel/BDOS.asm"
    INCLUDE "inc/kernel/terminal.asm"
    INCLUDE "inc/kernel/keyboard.asm"
    
    INCLUDE "inc/kernel/debug.asm"
        ;; Must be last file in the included kernel parts
    INCLUDE "inc/kernel/data.asm"
kernel_end: ; Always the last thing in the kernel.
    DISPLAY "kernel END\t:\t",/H,$


    ORG     KERNEL_A+$4000-KR_STACK_SIZE
        
    MODULE KERNEL
stack_bottom:
        DS  KR_STACK_SIZE, $AA        ; 128bytes of stack set to $AA for to aide debugging
stack:                               ; becakse it grows downwards, and I always forget that
    ENDMODULE
    
    DISPLAY "kernel STACK\t:\t",/H,$
    
;-----------------------------------------------------------------------------
; -- Report size, export memory as binary
;-----------------------------------------------------------------------------
kernelBinSz    EQU     kernel_end-kernel_start
kernelBinPcHi  EQU     (100*kernelBinSz)/(1024*16)
kernelBinPcLo  EQU     ((100*kernelBinSz)%(1024*16))*10/(1024*16)

    DISPLAY "kernel LEN\t:\t",/D,kernelBinSz,"B\t(",/D,kernelBinPcHi,".",/D,kernelBinPcLo,"% of 16kiB)"
    
    SAVEBIN "../build/kernel",kernel_start,kernelBinSz
    DISPLAY "======================================================= <"
;-----------------------------------------------------------------------------
; .DPM main memory BIOS
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------

m_BIOSStackAndCall MACRO kernel_func
        ld      (BIOS.internal_TEARDOWN.SMC_exitstack), sp
        ld      sp, BIOS.stack
        push    hl
        ld      hl, kernel_func
        jp      internal_KERNEL_call
    ENDM
    
    ORG     BIOS_A
bios_start:
    DISPLAY "BIOS ORG\t:\t",/H,$
    
    MODULE  BIOS
        jp      entry_BOOT          ;00:-3: Cold start routine
WBOOTE
        jp      entry_WBOOT         ;01: 0: Warm boot - reload command processor
        jp      entry_CONST         ;02: 3: Console status
        jp      entry_CONIN         ;03: 6: Console input
        jp      entry_CONOUT        ;04: 9: Console output
        jp      entry_LIST          ;05:12: Printer output
        jp      entry_PUNCH         ;06:15: Paper tape punch output
        jp      entry_READER        ;07:18: Paper tape reader input
        jp      entry_HOME          ;08:21: Move disc head to track 0
        jp      entry_SELDSK        ;09:24: Select disc drive
        jp      entry_SETTRK        ;10:27: Set track number
        jp      entry_SETSEC        ;11:30: Set sector number
        jp      entry_SETDMA        ;12:33: Set DMA address
        jp      entry_READ          ;13:36: Read a sector
        jp      entry_WRITE         ;14;39: Write a sector
        jp      entry_LISTST        ;15:42: Status of list device
        jp      entry_SECTRAN       ;16:45: Sector translation for skewing
        ; ret : nop : nop             ;17:48: NOP
        ; ret : nop : nop             ;18:51: NOP
        ; ret : nop : nop             ;19:54: NOP
        ; ret : nop : nop             ;20:57: NOP
        ; ret : nop : nop             ;21:60: NOP
        ; ret : nop : nop             ;22:63: NOP
        ; ret : nop : nop             ;23:66: NOP
        ; ret : nop : nop             ;24:69: NOP
        ; ret : nop : nop             ;25:72: NOP
        ; ret : nop : nop             ;26:75: NOP
        ; ret : nop : nop             ;27:78: NOP
        ; ret : nop : nop             ;28:81: NOP
        ; jp      entry_USERF         ;29:84: User Function
        
// Private BIOS routine to call internal Kernel BDOS function
//  function address passed in hl, params in DE
internal_KERNEL_call:
.SMC_MMU4_kernel EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_kernel EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        
    IF DPM_DEBUG
            ld      a, l : call KERNEL_DEBUG.tm_a_loc76
            ld      a, h : call KERNEL_DEBUG.tm_a_loc78
    ENDIF
        
        ; Set our destination jump into kernel
        ld      (.internal_KERNEL_func), hl
        pop     hl              ; (WARNING: intentionall unbalanced) stack is now empty
.internal_KERNEL_func EQU $+1
        call    0xAAAA                      ; Kernel routine to call, was in HL, 0xAAAA is SMC.

; internal_TEARDOWN:
.SMC_MMU4_userland EQU $+3
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_userland EQU $+3
        nextreg	MMU5_A000_NR_55, 0xAA
        ;; return stack to original location
internal_TEARDOWN.SMC_exitstack EQU $+1
        ld      sp, 0xAAAA                  ; restore original stack pointer, as above 0xAAAA is SMC.

        ret

; Warm boot: the CCP comes back on the drive and user kept in USERDRIVE_A
reentry_BOOTROOM:
.SMC_MMU4_kernel EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_kernel EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        ld      sp, BIOS.stack
        call    KERNEL.BIOS_WBOOT
        ld      a, (USERDRIVE_A)        ; User in the high nibble, drive in the low
        jr      entry_BOOTROM.start_ccp

; Cold boot: the CCP starts on drive A, user 0
entry_BOOTROM:
        ld      sp, BIOS.stack
        call    KERNEL.BOOTROM
        xor     a                       ; Set the drive and user to 0
        ld      (USERDRIVE_A), a        ; Store them in base memory

.start_ccp:
.SMC_MMU4_userland EQU $+3
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_userland EQU $+3
        nextreg	MMU5_A000_NR_55, 0xAA

        ld      c, a                    ; The CCP takes the drive and user in C
        ld      hl, CCP_A+3             ;CCP_A+3 moves us past the first jump instruction
        jp      hl
        
entry_BOOT:                         ;-3: Cold start routine
entry_WBOOT:                        ; 0: Warm boot - reload command processor
        jr      reentry_BOOTROOM    
        
entry_CONST:                        ; 3: Console status
        m_BIOSStackAndCall KERNEL.BIOS_CONST

entry_CONIN:                        ; 6: Console input
        m_BIOSStackAndCall KERNEL.BIOS_CONIN

entry_CONOUT:                     ; 9: Console output - Write the character in C to the screen
        m_BIOSStackAndCall KERNEL.BIOS_CONOUT
        
entry_LIST:                         ;12: Printer output
        jr entry_CONOUT             ; Just use the console

entry_PUNCH:                        ;15: Paper tape punch output
        jr entry_CONOUT             ; Just use the console

entry_READER:                       ;18: Paper tape reader input
        m_BIOSStackAndCall KERNEL.BIOS_READER
        
entry_HOME:                         ;21: Move disc head to track 0
        m_BIOSStackAndCall KERNEL.BIOS_HOME

entry_SELDSK:                       ;24: Select disc drive
        m_BIOSStackAndCall KERNEL.BIOS_SELDSK

entry_SETTRK:                       ;27: Set track number
        m_BIOSStackAndCall KERNEL.BIOS_SETTRK

entry_SETSEC:                       ;30: Set sector number
        m_BIOSStackAndCall KERNEL.BIOS_SETSEC

entry_SETDMA:                       ;33: Set DMA address
        m_BIOSStackAndCall KERNEL.BIOS_SETDMA

entry_READ:                         ;36: Read a sector
        m_BIOSStackAndCall KERNEL.BIOS_READ

entry_WRITE:                        ;39: Write a sector
        m_BIOSStackAndCall KERNEL.BIOS_WRITE

entry_LISTST:                       ;42: Status of list device
        m_BIOSStackAndCall KERNEL.BIOS_LISTST

entry_SECTRAN:                      ;45: Sector translation for skewing
        m_BIOSStackAndCall KERNEL.BIOS_SECTRAN
        
; entry_USERF:                      ;82: User Functions (aka machine specific)
;         m_BIOSStackAndCall KERNEL.USERF

kr_stack:
    DW  0xAAAA                  ; This is what the stack was when the kernel passed control to CP/M

start_stack:
    ds  64, $AA                  ; 64bytes of stack set to $AA for to aide debugging
stack:                                 ; because it grows downwards, and I always forget that

    ENDMODULE

bios_end:
    DISPLAY "BIOS END\t:\t",/H,$


;-----------------------------------------------------------------------------
; -- Report size, export memory as binary
;-----------------------------------------------------------------------------
biosBinPcHi  EQU     (100*biosBinSz)/(256*2)
biosBinSz   EQU     bios_end-bios_start      ; Shamelessly stolen clever reporting code from .DISPLAYEDGE by Ped7g

biosBinPcLo  EQU     ((100*biosBinSz)%(256*2))*10/(256*2)
    DISPLAY "BIOS LEN\t:\t",/D,biosBinSz,"B\t(",/D,biosBinPcHi,".",/D,biosBinPcLo,"% of 0.5kiB)"
    
    SAVEBIN "../build/BIOS",bios_start,biosBinSz
    DISPLAY "======================================================= <"
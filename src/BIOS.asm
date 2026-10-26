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

; The same through bios_call, in fewer bytes and a little slower: for the
; entries whose speed does not matter.
m_BIOSCompactCall MACRO kernel_func
        ld      (BIOS.bios_call.SMC_hl), hl
        ld      hl, kernel_func
        jr      bios_call
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
        ; Entries 17 to 28 return at once. Entry 29 is DP/M's own, DPM
        ; control: DP/M's functions, the function number in C ($00 ends DP/M
        ; and returns to NextZXOS). It sits in the slot kept for the user
        ; function, WBOOTE+BIOS_CONTROL_OFS, where EXIT.COM and the CCP's EXIT
        ; find it from the warm boot address at $0001.
        ret : nop : nop             ;17:48: NOP
        ret : nop : nop             ;18:51: NOP
        ret : nop : nop             ;19:54: NOP
        ret : nop : nop             ;20:57: NOP
        ret : nop : nop             ;21:60: NOP
        ret : nop : nop             ;22:63: NOP
        ret : nop : nop             ;23:66: NOP
        ret : nop : nop             ;24:69: NOP
        ret : nop : nop             ;25:72: NOP
        ret : nop : nop             ;26:75: NOP
        ret : nop : nop             ;27:78: NOP
        ret : nop : nop             ;28:81: NOP
CONTROLE
        jp      entry_CONTROL       ;29:84: DPM control, function in C
        ASSERT  CONTROLE-WBOOTE == BIOS_CONTROL_OFS
        
// Private BIOS routine to call internal Kernel BDOS function
//  function address passed in hl, params in DE
internal_KERNEL_call:
        di                                  ; The kernel runs with interrupts off
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

.teardown:                                  ; Back to the CP/M program
.SMC_MMU4_userland EQU $+3
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_userland EQU $+3
        nextreg	MMU5_A000_NR_55, 0xAA
        ;; return stack to original location
internal_TEARDOWN.SMC_exitstack EQU $+1
        ld      sp, 0xAAAA                  ; restore original stack pointer, as above 0xAAAA is SMC.
        ei                                  ; Back in the CP/M program, the cursor blinks
        ret

; Warm boot: the CCP comes back on the drive and user kept in USERDRIVE_A
reentry_BOOTROOM:
        di
.SMC_MMU4_kernel EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_kernel EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        ld      sp, BIOS.stack
        call    KERNEL.BIOS_WBOOT
        ld      a, (USERDRIVE_A)        ; User in the high nibble, drive in the low
        ld      hl, CCP_PROMPT_A        ; Past the first jump: the CCP shows its prompt
        jr      entry_BOOTROM.start_ccp

; Cold boot: the CCP starts on drive A, user 0, and runs the command line from
; the dot command's arguments if there is one
entry_BOOTROM:
        ld      sp, BIOS.stack
        call    KERNEL.BOOTROM
        call    KERNEL.autocmd_to_ccp   ; A = length of the line put in the CCP's buffer
        ld      hl, CCP_PROMPT_A        ; No line: the CCP shows its prompt
        or      a
        jr      z, .user_drive
        ld      hl, CCP_RUN_A           ; A line: the first jump runs it
.user_drive:
        xor     a                       ; Set the drive and user to 0
        ld      (USERDRIVE_A), a        ; Store them in base memory

.start_ccp:                             ; HL = the CCP entry
.SMC_MMU4_userland EQU $+3
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_userland EQU $+3
        nextreg	MMU5_A000_NR_55, 0xAA

        ld      c, a                    ; The CCP takes the drive and user in C
        ei
        jp      hl
        
entry_BOOT:                         ;-3: Cold start routine
entry_WBOOT:                        ; 0: Warm boot - reload command processor
        jr      reentry_BOOTROOM    
        
; BIOS CONST and CONIN with CON: on BAT: and RDR: on a UART, the way the
; IOBYTE terminal programs poll the line, answered here in slot 7 without
; the kernel, and CONST on the keyboard. Anything else, and a CONIN that has
; to wait, goes on to the kernel (kernel_CONST, kernel_CONIN). The results
; are those of KERNEL.BIOS_CONST and KERNEL.BIOS_CONIN.
entry_CONST:                        ; 3: Console status
        di
        ld      a, (IOBYTE_A)
        xor     %00000010                   ; CON: BAT: gives 0 in bits 1:0
        ld      c, a
        and     %00000011
        jr      nz, .keyboard               ; Not BAT:
        ld      a, c
        call    BLINK.bat_uart.rdr
        jr      c, kernel_CONST             ; RDR: is not a UART
        jr      nz, .ready                  ; Bytes in the ring, A = $FF
        in      a, (c)
        and     %00000001                   ; A byte in the Rx buffer?
        jr      z, .ready                   ; ...No, A = 0
.key:
        ld      a, $FF
.ready:
        ei
        ret
; Not CON: BAT:, the keyboard: KERNEL.keyboard_status, with the same results
; (A, B, HL and the flags), read with only the kernel's slot 5 page mapped.
.keyboard:
    ASSERT  (KERNEL.dynamic_data.console_head >> 13) == 5 && (KERNEL.dynamic_data.console_tail >> 13) == 5
.SMC_MMU5_kernel EQU $+3:
        nextreg MMU5_A000_NR_55, $AA
        ld      a, (KERNEL.dynamic_data.console_head)
        ld      hl, KERNEL.dynamic_data.console_tail
        cp      (hl)                        ; Is a byte waiting?
.SMC_MMU5_userland EQU $+3:
        nextreg MMU5_A000_NR_55, $AA
        ld      b, 0
        jr      nz, .key                    ; ...Yes, ready
        xor     a                           ; ...No, not ready
        ei
        ret

entry_CONIN:                        ; 6: Console input
        di
        call    BLINK.bat_uart
        jp      c, kernel_CONIN
        jr      nz, .ring                   ; Bytes in the ring
        in      a, (c)
        rrca                                ; A byte in the Rx buffer?
        jp      nc, kernel_CONIN            ; ...No, the kernel waits for it
        inc     b                           ; $143B
        in      a, (c)
        ei
        ret
.ring:
        call    BLINK.ring_take             ; The oldest byte
        ei
        ret

kernel_CONST:                       ; 3: Console status, after entry_CONST
        m_BIOSCompactCall KERNEL.BIOS_CONST

kernel_CONIN:                       ; 6: Console input, after entry_CONIN
        m_BIOSCompactCall KERNEL.BIOS_CONIN

; As m_BIOSStackAndCall and internal_KERNEL_call, with the kernel routine
; called directly
entry_CONOUT:                     ; 9: Console output - Write the character in C to the screen
        ld      (internal_TEARDOWN.SMC_exitstack), sp
        ld      sp, stack
        di                                  ; The kernel runs with interrupts off
.SMC_MMU4_kernel EQU $+3:
        nextreg MMU4_8000_NR_54, $AA
.SMC_MMU5_kernel EQU $+3:
        nextreg MMU5_A000_NR_55, $AA
        call    KERNEL.BIOS_CONOUT
        jp      internal_KERNEL_call.teardown
        
entry_LIST:                         ;12: Printer output
        m_BIOSStackAndCall KERNEL.BIOS_LIST

entry_PUNCH:                        ;15: Paper tape punch output
        m_BIOSStackAndCall KERNEL.BIOS_PUNCH

entry_READER:                       ;18: Paper tape reader input
        m_BIOSStackAndCall KERNEL.BIOS_READER
        
; The caller's HL in SMC_hl, the kernel routine in HL: on to
; internal_KERNEL_call as m_BIOSStackAndCall goes
bios_call:
        ld      (internal_TEARDOWN.SMC_exitstack), sp
        ld      sp, stack
        push    hl
.SMC_hl EQU $+1
        ld      hl, $AAAA                   ; The caller's HL, $AAAA replaced by the entry
        ex      (sp), hl
        jp      internal_KERNEL_call

entry_HOME:                         ;21: Move disc head to track 0
        m_BIOSCompactCall KERNEL.BIOS_HOME

entry_SELDSK:                       ;24: Select disc drive
        m_BIOSCompactCall KERNEL.BIOS_SELDSK

entry_SETTRK:                       ;27: Set track number
        m_BIOSCompactCall KERNEL.BIOS_SETTRK

entry_SETSEC:                       ;30: Set sector number
        m_BIOSCompactCall KERNEL.BIOS_SETSEC

entry_SETDMA:                       ;33: Set DMA address
        m_BIOSCompactCall KERNEL.BIOS_SETDMA

entry_READ:                         ;36: Read a sector
        m_BIOSCompactCall KERNEL.BIOS_READ

entry_WRITE:                        ;39: Write a sector
        m_BIOSCompactCall KERNEL.BIOS_WRITE

entry_LISTST:                       ;42: Status of list device
        m_BIOSStackAndCall KERNEL.BIOS_LISTST

entry_SECTRAN:                      ;45: Sector translation for skewing
        m_BIOSCompactCall KERNEL.BIOS_SECTRAN
        
entry_CONTROL:                      ;84: DPM control, function in C
        m_BIOSCompactCall KERNEL.BIOS_CONTROL

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
    ASSERT  bios_end <= $10000                  ; The BIOS ends at the top of memory
    
    SAVEBIN "../build/BIOS",bios_start,biosBinSz
    DISPLAY "======================================================= <"
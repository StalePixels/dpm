;-----------------------------------------------------------------------------
; .DPM
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------
    DEVICE zxspectrumnext   ; ZX Spectrum Next (8 slots, 224 pages, slot size 0x2000 = 1.75MiB RAM)
                ; default pages map: 14, 15, 10, 11, 4, 5, 0, 1 -- default slot: 7 0xE000..0xFFFF
    OPT reset --zxnext --syntax=abfw
    CSPECTMAP DPM.map

;-------------------------------

                                        ; None of these are actual code, just metastuff
    INCLUDE "inc/version.asm"                   ; Our version details
    INCLUDE "inc/addresses.asm"                 ; Various hard coded addresses (ORGs, etc)
    INCLUDE "inc/constants.asm"                 ; ZX Next constants
    INCLUDE "inc/esxdos.asm"                    ; ESXDOS macros and functions parameters
    INCLUDE "inc/ascii.asm"                     ; ASCII control codes, shared with CCP.asm
    INCLUDE "inc/structs.asm"                   ; Application specific structures
    INCLUDE "inc/common/macros.asm"             ; Macros - all macros starting with m_
        
    INCLUDE "inc/common/debug.asm"              ; CSpect Debugging - all macros starting with m_CSpect_
        
                                        ; Generate our dependencies, which are appended to the dot
    INCLUDE "BIOS.asm"                          ; BIOS main mem
    INCLUDE "BDOS.asm"                          ; BDOS main mem
    INCLUDE "kernel.asm"                        ; Main kernel @ 0x8000 
                                        ; The CCP is CCP.asm, assembled on its own into CCP.COM


    ORG     ESX_A
DOT_STACK_SIZE   EQU         $80
dot_start:
    DISPLAY "dot ORG\t:\t",/H,$
        jr      init
    ;; Version fingerprint to allow external version tracking
        DB DPMname, "@", DPMversion, 0   
init:
        ld      a, i                        ; P/V = IFF2: interrupts on or off at entry
        jp      pe, .iff_read
        ld      a, i                        ; Again: an interrupt taken just after the first read clears P/V
.iff_read:
        di                                  ; Disable interrupts for safe paging
        ld      a, $FB                      ; EI at exit, as interrupts were on
        jp      pe, .iff_kept
        xor     a                           ; NOP at exit, as they were off
.iff_kept:
        ld      (ei_exit.SMC_iff), a
        ld      (state.argsPtr),hl          ; preserve pointer to arguments
        call    save_args                   ; Keep them while BASIC's memory is still paged in
        m_PrintMsg DotMsg.Startup           ; Display our own startup message

        ; ld      hl, DotMsg.Startup
        ; RST $18
    ;;check_for_next:                       ; detect running environment (bail out if it's not Z80N)
        xor     a                           ; Fast reset carry flag==normal exit 
        inc     a                           ; A=1, Fc=0
        mirror  a : nop : nop               ; $01 -> $80 on Z80N CPU, maybe "inc h" on Z80
                                            ; something else on Z380 and similar (but not mirror A)
        cp      $80
        jr      z, backup_state             ; Hardware check passed
        ld      hl, DotErr.NextRequired     ; Point at error message
        xor     a                           ; Fast reset carry flag==normal exit 
        scf                                 ; Set carry flag, to signify error condition
        jp      ei_exit                     ; Exit

backup_state:
        push    ix                          ; Save BASIC's current setup to the stack,
        push    iy                          ; so we can restore them later when we quit
        ld      a, i                        ; Copy the Interrupt Register into a
        ld      c, a                        ; We can't push A without copying flags too, and we pop
                                            ; this later, without the flags, so we'll use C instead.
        push    bc                          ; Store C, which contains I - we don't care about B
        ld      (state_exit.SMC_stack), sp  ; Stash the stack pointer into the SMC exit routine.
        
        
        m_NextRegRead_c CPU_SPEED_NR_07     ; Read CPU speed
        ld      (state_exit.SMC_cpu), a     ; Save current speed so it can be restored on exit
        or %11                              ; Set speed to 28Mhz
        nextreg CPU_SPEED_NR_07, %11        ; Write back to CPU Speed register

        ld      a,   (SYSVAR_BORDCR_5C48)   ; save SYSVAR SYSB (border colour) so we can
        ld      (state_exit.SMC_border), a  ; restore it later at exit
        xor     a : out     (ULA_P_FE), a   ; Set the border black

        m_NextRegRead_c MMU2_4000_NR_52     ; Save MMU slots 2-7, so memmap_exit
        ld      (memmap_exit.SMC_slot2), a  ; puts back the pages NextZXOS had there
        m_NextRegRead_c MMU3_6000_NR_53
        ld      (memmap_exit.SMC_slot3), a
        m_NextRegRead_c MMU4_8000_NR_54
        ld      (memmap_exit.SMC_slot4), a
        m_NextRegRead_c MMU5_A000_NR_55
        ld      (memmap_exit.SMC_slot5), a
        m_NextRegRead_c MMU6_C000_NR_56
        ld      (memmap_exit.SMC_slot6), a
        m_NextRegRead_c MMU7_E000_NR_57
        ld      (memmap_exit.SMC_slot7), a

    ;;check_freemem:
        call    zxn_AvailablePages          ; Number of pages available returned in A
        ;; Check how many free memory available - error out if less than 96KB
        and     a                           ; Clear carry flag, leave A intact
        sub     13                          ; Minus 13, the number of pages we need
        jr      nc, allocate_memory:        ; Sufficent memory found, jump to next stage
        
        xor     a                           ; Wipe A, also wipes carry flag... so set it again
        scf
        ld      hl, DotErr.NotEnoughMemory  ; Point at error message
        jp      state_exit                  ; Exit after restoring machine state
        
        ;; Now we know there's enough free memory, we can just allocate without checking... :-O
allocate_memory:                        ; Last 16k, 96k total - save the bank numbers for later
        ;; Allocate 8k bank, preserve ULA and SYSVARS (5,0)                     (1)     0+8=8
        call    zxn_AllocatePageInA            ; Leaves result in A
        ld      (state.mmu2backup), a
        ld      (mem_exit.SMC_bank2), a
        
                                        ; backup Sysvars, ULA, etc.
        nextreg	MMU4_8000_NR_54, a          ; Page in .SMC_bank1 
        ld      hl, $4000;                  ; Copy From
        ld      de, $8000;                  ; Copy To
        ld      bc, $2000;                  ; Length of Copy
        ldir                                ; ldi repeat. Go.

        ;; Allocate 8k bank, make space for tiles and map (5,1)                 (2)     8+8=16
        call    zxn_AllocatePageInA            ; Leaves result in A
        ld      (state.mmu3backup), a
        ld      (mem_exit.SMC_bank3), a
        
                                        ; backup Contents of what will be tilemap area
        nextreg	MMU5_A000_NR_55, a          ; Page in .SMC_bank1 
        ld      hl, $6000;                  ; Copy From
        ld      de, $A000;                  ; Copy To
        ld      bc, $2000;                  ; Length of Copy
        ldir                                ; ldi repeat. Go.

        ;; Allocate BIOS/BDOS/File System Emulator "kernel" memory space        (2?)    80+?16=?96
        call    zxn_AllocatePageInA         ; Leaves result in A
        nextreg	MMU4_8000_NR_54, a          ; Page in .SMC_kernel0 (0x8000)
        ld      (state.kernel0), a
        ld      (mem_exit.SMC_kernel0), a
        
        call    zxn_AllocatePageInA         ; Leaves result in A
        nextreg	MMU5_A000_NR_55, a          ; Page in .SMC_kernel1 (0xA000)
        ld      (state.kernel1), a
        ld      (mem_exit.SMC_kernel1), a
        
        ;; Allocate 8x8k banks for CP/M memory space                            (8)     16+64=80
        call    zxn_AllocatePageInA
        ld      (state.mmu0), a
        ld      (mem_exit.SMC_mmu0), a
        
        call    zxn_AllocatePageInA
        ld      (state.mmu1), a
        ld      (mem_exit.SMC_mmu1), a
        
        call    zxn_AllocatePageInA
        ld      (state.mmu2), a
        ld      (mem_exit.SMC_mmu2), a
        
        call    zxn_AllocatePageInA
        ld      (state.mmu3), a
        ld      (mem_exit.SMC_mmu3), a
        
        call    zxn_AllocatePageInA
        ld      (state.mmu4), a
        ld      (mem_exit.SMC_mmu4), a
        
        call    zxn_AllocatePageInA
        ld      (state.mmu5), a
        ld      (mem_exit.SMC_mmu5), a
        
        call    zxn_AllocatePageInA
        ld      (state.mmu6), a
        ld      (mem_exit.SMC_mmu6), a
        nextreg	MMU6_C000_NR_56, a          ; Page in Userland6 (0xC000, to load BIOS+BDOS)
        
        call    zxn_AllocatePageInA
        ld      (state.mmu7), a
        ld      (mem_exit.SMC_mmu7), a
        nextreg	MMU7_E000_NR_57, a          ; Page in Userland7 (0xE000, to load BIOS+BDOS)
        
        ;; We've finished using NextZXOS, move stack 
        ld      (exit_kernel.SMC_dotstack), sp  ; Stash the stack pointer for return from kernel.
        
        ;; Move the stack pointer into DivMMC RAM, so we can load stuff up high for the OS...
        ; ld      sp, dot_stack
        ld      sp, CCP_A-1
                
        ;; Load our kernel, which is out main memory space, made of "bootROM", stored at end of dotcommand
        m_esxdos M_GETHANDLE                    ; Get handle of current dot in A
        push    af                              ; Keep it safe for later
        ld      hl, kernel_start                ; Destination address, our kernel pages prev-mapped via MMU
        ld      bc, kernelBinSz                 ; Size of bootROM
        m_esxdos F_READ
        // Reset A so we can read again
        pop     af                              ; Load that file handle again, but keep stashed copy of it
        dec sp : dec sp                         ; we lower the stack pointer (cheaper than push af) 
        ld      hl, bios_start                  ; Destination address, our userland BIOS prev-mapped via MMU
        ld      bc, biosBinSz                   ; Size of BIOS
        m_esxdos F_READ
        // Reset A so we can read again
        pop     af                              ; And... we load that file handle again
        dec sp : dec sp                         ; we lower the stack pointer again
        ld      hl, bdos_start                  ; Destination address, our userland BDOS prev-mapped via MMU
        ld      bc, bdosBinSz                   ; Size of BDOS
        m_esxdos F_READ
        pop     af                              ; Load that file handle again
        m_esxdos F_CLOSE
        
        ;; Copy our state object into the kernel, so we can use it when DivMMC RAM is paged out
        ld      hl, @state
        ld      de, KERNEL.dynamic_data.state
        ld      bc, STATE_SIZE                  ; Length of Copy
        ldir
        ;; Copy the command line from the arguments into the kernel, for the CCP at cold boot
        ld      hl, autocmd
        ld      de, KERNEL.dynamic_data.autocmd
        ld      bc, AUTOCMD_SIZE
        ldir
        ;; Call "bootrom" entrypoint (copy fonts, setup tilemap, etc. start emulator, etc)
        call    KERNEL.setup
        
;; DEBUGGING - DEBUGGING - DEBUGGING - DEBUGGING - DEBUGGING - DEBUGGING
;; vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv

        ;; Quick hack to see if BIOS is loading correctly
        ; ld      hl, BDOS.greeting;            ; Copy From
        ; call    KERNEL.print_string_hl
        
        ; ld      c, '!'  : call BIOS.entry_CONOUT; 
        ; ld      c, 13  : call BIOS.entry_CONOUT; 
                
;; ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
;; DEBUGGING - DEBUGGING - DEBUGGING - DEBUGGING - DEBUGGING - DEBUGGING

start:
        jp      BIOS.entry_BOOTROM
        
        ld      a, 0x0F
pause:
        push    af
        call    KERNEL_DEBUG.pause
        pop     af
        dec     a
        jp      nz, pause
        m_CSpect_BREAK


;-----------------------------------------------------------------------------
; -- Exit to NextZXOS from the kernel with an error report. Entered with the
;    kernel paged in and KERNEL.enable_esxdos_rom done, so this dot command's
;    RAM is at $2000-$3FFF. HL = the message, in this dot command's RAM, its
;    last character with bit 7 set.
;-----------------------------------------------------------------------------
kernel_error_exit:
        ld      sp, dot_stack               ; A stack that stays mapped while the MMUs are restored
        ld      (mem_exit.SMC_error), hl    ; The message, given back to NextZXOS at the end of mem_exit
        scf                                 ; Carry flag signifies the error
        jr      bootrom_exit

;-----------------------------------------------------------------------------
; -- Exit to NextZXOS from the kernel with no error. Entered as
;    kernel_error_exit is, with no message.
;-----------------------------------------------------------------------------
kernel_exit:
        ld      sp, dot_stack               ; A stack that stays mapped while the MMUs are restored
        jr      clean_exit

exit_kernel:
.SMC_dotstack EQU $+1
        ld      sp, 0xAAAA                  ; restore original stack pointer, as above 0xAAAA is SMC.
        
;-----------------------------------------------------------------------------
; -- This is the (long winded) exit routine, with various entry points
;-----------------------------------------------------------------------------
clean_exit:
        xor     a                           ; Fast reset carry flag==normal exit 
                                            ; & fallow through
        
bootrom_exit:
        ld      a, (state.kernel0)
        nextreg	MMU4_8000_NR_54, a          ; Page in kernel0 (0x8000)
        ld      a, (state.kernel1)
        nextreg	MMU5_A000_NR_55, a          ; Page in kernel1 (0xA000)
        
        call KERNEL.exit                        ; All the hardware cleanup+exit code
        
memmap_exit:
                                        ; Restore first half to rightful MMU slots
        nextreg	MMU0_0000_NR_50, 0xFF
        nextreg	MMU1_2000_NR_51, 0xFF
.SMC_slot2 EQU $+3
        nextreg	MMU2_4000_NR_52, 0xAA       ; 0xAA replaced at startup with the page NextZXOS had
.SMC_slot3 EQU $+3
        nextreg	MMU3_6000_NR_53, 0xAA
                                        ; Restore the stuff we backed up
        ld      a, (state.mmu2backup)     ; Backup of Sysvars, ULA, etc.
        nextreg	MMU4_8000_NR_54, a          ; Page in .SMC_bank1 
        ld      hl, $8000;                  ; Copy From
        ld      de, $4000;                  ; Copy To
        ld      bc, $2000;                  ; Length of Copy
        ldir                                ; ldi repeat. Restore to original location

        ld      a, (state.mmu3backup)     ; Back up of tilemap area
        nextreg	MMU5_A000_NR_55, a          ; Page in .SMC_bank1 
        ld      hl, $A000;                  ; Copy From
        ld      de, $6000;                  ; Copy To
        ld      bc, $2000;                  ; Length of Copy
        ldir                                ; ldi repeat. Restore to original location
                                        ; Restore second half to rightful MMU slots
.SMC_slot4 EQU $+3
        nextreg	MMU4_8000_NR_54, 0xAA       ; 0xAA replaced at startup with the page NextZXOS had
.SMC_slot5 EQU $+3
        nextreg	MMU5_A000_NR_55, 0xAA
.SMC_slot6 EQU $+3
        nextreg	MMU6_C000_NR_56, 0xAA
.SMC_slot7 EQU $+3
        nextreg	MMU7_E000_NR_57, 0xAA
        
mem_exit:
        push    af                          ; Preserve the flags, and A, for exit routine
        
                                        ; DPM's BIOS/BDOS memory space, 16k of "kernel"
.SMC_kernel0 EQU $+1
        ld      e, 0xAA                     ; DPM "kernel", outside main memory space pt1
        call zxn_FreePage
.SMC_kernel1 EQU $+1
        ld      e, 0xAA                     ; DPM "kernel", outside main memory space pt2
        call zxn_FreePage
        
                                        ; DPM's CP/M memory space, 64k of "userland"
.SMC_mmu0 EQU $+1
        ld      e, 0xAA                     ; CP/M "userland" main memory space, part 1 of 8
        call zxn_FreePage
.SMC_mmu1 EQU $+1
        ld      e, 0xAA                     ; CP/M "userland" main memory space, part 2 of 8
        call zxn_FreePage
.SMC_mmu2 EQU $+1
        ld      e, 0xAA                     ; CP/M "userland" main memory space, part 3 of 8
        call zxn_FreePage
.SMC_mmu3 EQU $+1
        ld      e, 0xAA                     ; CP/M "userland" main memory space, part 4 of 8
        call zxn_FreePage
.SMC_mmu4 EQU $+1
        ld      e, 0xAA                     ; CP/M "userland" main memory space, part 5 of 8
        call zxn_FreePage
.SMC_mmu5 EQU $+1
        ld      e, 0xAA                     ; CP/M "userland" main memory space, part 6 of 8
        call zxn_FreePage
.SMC_mmu6 EQU $+1
        ld      e, 0xAA                     ; CP/M "userland" main memory space, part 7 of 8
        call zxn_FreePage
.SMC_mmu7 EQU $+1
        ld      e, 0xAA                     ; CP/M "userland" main memory space, part 8 of 8
        call zxn_FreePage

        ;; Page in .SMC_bank3 and copy whatever was originally in the tilemap space
.SMC_bank3 EQU $+1
        ld      e, 0xAA                     ; Top BANK5 cache, 0xAA replaced at startup for SMC.
        call zxn_FreePage
        
        ;; Page in .SMC_bank2 and copy whatever was originally in the tiles space
.SMC_bank2 EQU $+1
        ld      e, 0xAA                     ; Bottom BANK5 cache, 0xAA replaced at startup for SMC.
        call zxn_FreePage
        ; call esxDOS.fClose
        pop     af                          ; So we have the correct exit states again.
        jr      nc, state_exit
                                        ; Carry: kernel_error_exit came this way
.SMC_error EQU $+1
        ld      hl, 0xAAAA                  ; Its message, 0xAAAA replaced by kernel_error_exit
        ld      a, 0                        ; A=0 with carry: HL is the error message (keeps the flags)
                                            ; & fallow through
state_exit:                             ; slightly inefficent if following through, but good enough
        push    af                          ; Preserve the flags, and A, for exit routine
        push    hl
.SMC_border EQU $+1
        ld      a, 0xAA                     ; Old border colour, 0xAA replaced at startup for SMC.
        ld      (SYSVAR_BORDCR_5C48), a     ; load the user's border
        rrc a : rrc a : rrc a
        and     a, 0b00000111
        out     (ULA_P_FE), a               ; and restore it
        pop     hl                          ; So we have the correct error message, if there is one,
        pop     af                          ; and the correct exit states...
                                            ; & fallow through
.SMC_stack EQU $+1
        ld      sp, 0xAAAA                  ; restore original stack pointer, as above 0xAA is SMC.
        ld      e, a                        ; Keep A, the exit code, while I is restored
        pop     bc                          ; Get our stored I, in C, off the stack.
        ld      a, c                        ; Copy C back into A
        ld      i, a                        ; And move A back into I, for original Interrupts
        ld      a, e                        ; The exit code again (no flags change)
        pop     iy                          ; these were the only values we pushed onto the stack
        pop     ix                          ; at startup before we switched to our own stack
                                            ; & fallow through
.SMC_cpu EQU $+3:
        nextreg CPU_SPEED_NR_07, 0xAA       ; Restore original CPU speed using the SMC trick again.
        jp      c, ei_exit                  ; Skip the exit message if we have a carryflag set
        m_PrintMsg DotMsg.Shutdown          ; Graceful exit message
                                            ; & fallow through
ei_exit:
.SMC_iff:
        ei                                  ; Interrupts as they were at entry: EI, or NOP set by init
        ret                                 ; and finally exit gracefully

;-----------------------------------------------------------------------------
; -- Keep the dot command's arguments in autocmd as a CCP command line: the
;    length, then the text in upper case, ending in 0. Leading spaces are
;    skipped. The arguments end at $00, $0D or ':'. When they start with '"',
;    the line is the text up to the next '"', or to $00 or $0D, without the
;    quotes, and ':' is part of it. At most CCP_CMD_MAX characters are kept.
;    HL = the arguments, 0 if there are none. Dirties AF, BC, DE, HL
;-----------------------------------------------------------------------------
save_args:
        ld      de, autocmd+1               ; The text
        ld      b, CCP_CMD_MAX              ; Room left
        ld      c, ':'                      ; The character that ends the line
        ld      a, h
        or      l
        jr      z, .end                     ; No arguments
.skip:
        ld      a, (hl)
        cp      ' '
        jr      nz, .first
        inc     hl
        jr      .skip
.first:
        cp      '"'
        jr      nz, .next
        ld      c, a                        ; Quoted: only the closing '"' ends the line
        inc     hl
.next:
        ld      a, (hl)
        or      a
        jr      z, .end
        cp      KERNEL_KEYBOARD.CR
        jr      z, .end
        cp      c
        jr      z, .end
        cp      'a'
        jr      c, .keep
        cp      'z'+1
        jr      nc, .keep
        and     %11011111                   ; Fold lower case to upper
.keep:
        ld      (de), a
        inc     de
        inc     hl
        djnz    .next
.end:
        xor     a
        ld      (de), a                     ; The 0 after the text
        ld      a, CCP_CMD_MAX
        sub     b                           ; Characters kept
        ld      (autocmd), a
        ret

    ;; Include handy/generic utility procedures - all functions starting with putil_
    INCLUDE "inc/putils.asm"
    
    ;; BIOS to NextZXOS bridge - all functions starting with zxn_
    INCLUDE "inc/nextzxos.asm"   

;; Data "segment"
strings:
    INCLUDE "inc/dot/strings.asm"

start_state:
state:      S_STATE
end_state:

autocmd:                                ; Command line from the arguments: length, text, 0
    DS  AUTOCMD_SIZE, $00

command_buffer:
    DS  262, $AA                            ; 128bytes of stack set to $AA for to aide debugging

error_report:                           ; Error report built by the kernel: a DotErr prefix and a path
    DS  DotErr.PrefixMax+ESXDOS_MAX_PATH_LENGTH, $00
    
dot_end:                                   ; after last machine code byte which should be part of the binary
;; Meta stuffs for build
    DISPLAY "dot END\t:\t",/H,$

        ORG     ESX_A+$2000-DOT_STACK_SIZE
start_dot_stack:
; dot_stack_bottom:                          ; Move the stack into the DivMMC RAM, so we bank in CPM
    DS  DOT_STACK_SIZE, $AA                  ; 128bytes of stack set to $AA for to aide debugging
dot_stack:                                 ; because it grows downwards, and I always forget that
esxdos_stack:
    DISPLAY "dot STACK\t:\t",/H,$

;-----------------------------------------------------------------------------
; -- Report size, export memory as binary
;-----------------------------------------------------------------------------
dotBinSz   EQU     dot_end-dot_start      ; Shamelessly stolen clever reporting code from .DISPLAYEDGE by Ped7g
dotBinPcHi EQU     (100*dotBinSz)/(1024*8)
dotBinPcLo EQU     ((100*dotBinSz)%(1024*8))*10/(1024*8)
    DISPLAY "dot LEN\t:\t",/D,dotBinSz,"B\t(",/D,dotBinPcHi,".",/D,dotBinPcLo,"% of dot command 8kiB)"

    SAVEBIN "../build/DPM.dot",dot_start,$2000
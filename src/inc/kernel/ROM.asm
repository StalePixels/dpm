;-----------------------------------------------------------------------------
; .DPM bootROM/kernel helper functions
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------

m_kr_unimplimented MACRO func_name
        call    kr_print_unimplimented
        ld      hl, func_name
        call    kr_print_string_hl
        m_CSpect_BREAK
        jr $
    ENDM
m_kr_fatal MACRO func_name
        call    kr_print_error
        ld      hl, func_name
        call    kr_print_string_hl
        m_CSpect_BREAK
        jr      $
    ENDM
;
m_kr_esxdos    MACRO   func
        call    KERNEL.enable_esxdos_rom
        ld      (.SMC_kernel_stack), sp
        ld      sp, dot_stack
        ; nextreg	MMU6_C000_NR_56, 0x00
        ; nextreg	MMU7_E000_NR_57, 0x01
        
        m_esxdos func
        
        ; push    af
        ; ld      a, (dynamic_data.state.mmu6)
        ; nextreg	MMU6_C000_NR_56, a
        ; ld      a, (dynamic_data.state.mmu7)
        ; nextreg	MMU7_E000_NR_57, a
        ; pop     af
.SMC_kernel_stack EQU $+1
        ld      sp, $AAAA
        call    KERNEL.disable_esxdos_rom
    ENDM

    MODULE KERNEL
    
;

;; Setup VM environment, colours, etc. - take over from NextZXOS
setup:                                   ; DPM starting up - initialise hardware & drives for the VM

.load_config:
        /* 
        ;; remember to check path ends with '/'
        
        dec     hl
        ld      a, (hl)
        cp      '/'
        jr      z, .append_drive_letter
        inc     hl
        ld      (hl), '/'
 .append_drive_letter:
        inc     hl
 ;         */
        m_PrintMsg KERNEL.strings.path  ; Display our own startup message
        ld      de, config.install_path
        ld      hl, dynamic_data.working_path
        call    KERNEL.strcpy
        
        push    hl                      ; Stack now: RETADDR, A ptr
        ld      (hl), 'A'
        inc     hl
        ld      (hl), '/'
        inc     hl 
        push    hl                      ; Keep EoString safe, we'll want it again later
                                        ; Stack now: RETADDR, A ptr, User# ptr
        
        ld      a, 'A' : m_PrintCharInA             ; Print "A"
        
        ld      a, '0'                              ; First user number, in ASCII
.a_test_usernumber
        push af                         ; Stack now: RETADDR, A ptr, User# ptr, ASCII User#
        ld      (hl), a                             ; Append to drive string
        inc     hl                                  ; Move pointer
        ld      (hl), 0                             ; Null terminate complete path
        
        m_PrintCharInA             ; Print Next drive letter
        
        ld      hl, dynamic_data.working_path       ; Point to start of path
        ld      a, '*'                              ; This doesn't matter, pathspec overrides it
        m_esxdos F_OPENDIR                          ; Call ESXDOS without any wrappers (ROM already mapped)
        jp      c, .config_error
        ;; Path found, move to next usernumber, stop when we reach 9
        m_esxdos F_CLOSE                            ; Call ESXDOS without any wrappers (ROM already mapped)
        pop     af                                  ; Get the user number ASCII back
        cp      '9'
        jr      z, .a_tenplus_usernumber
        inc     a                                   ; Move to next usernumber, 0 thru 9
        pop     hl : push hl                        ; Restore end of string cache, and resave it
        jr      .a_test_usernumber
        
.a_tenplus_usernumber
        pop     hl                                  ; Restore end of string pointer
        ld      (hl), '1'
        inc     hl
        push    hl                                  ; Keep new EoString safe, so we can use it again
        ld      a, '0'                              ; First user number, in ASCII
.a_test_tenplus_usernumber
        push    af
        ld      (hl), a                             ; Append to drive string
        inc     hl                                  ; Move pointer
        ld      (hl), 0                             ; Null terminate complete path
        
        add     a, $11
        m_PrintCharInA             ; Print Next drive letter
        
        ld      hl, dynamic_data.working_path       ; Point to start of path
        ld      a, '*'                              ; This doesn't matter, pathspec overrides it
        m_esxdos F_OPENDIR                          ; Call ESXDOS without any wrappers (ROM already mapped)
        jr      c, .config_error
        ;; Path found, move to next usernumber, stop when we reach 9
        m_esxdos F_CLOSE                            ; Call ESXDOS without any wrappers (ROM already mapped)
        pop     af                                  ; Get the user number ASCII back
        cp      '5'
        jr      z, .a_done
        inc     a                                   ; Move to next usernumber, 0 thru 9
        pop     hl : push hl                        ; Restore end of string cache, and resave it
        jr      .a_test_tenplus_usernumber
        
.a_done 
        pop     hl                              ; Old position of User Number
        pop     hl                              ; Position of Drive letter
        push    hl                              ; We don't need this, it's for stack balancing at exit

        ;; Build the path for virtual B drives
        ld      (hl), 'B'
        inc     hl
        ld      (hl), '/'
        inc     hl 
        push    hl                      ; Keep EoString safe, we'll want it again later
        
        ld      a, 0x0D : m_PrintCharInA             ; Print newline
        ld      a, ' ' : m_PrintCharInA             ; Print space
        ld      a, 'B' : m_PrintCharInA             ; Print "B"
        
        ld      a, '0'                              ; First user number, in ASCII
.b_test_usernumber
        push af
        ld      (hl), a                             ; Append to drive string
        inc     hl                                  ; Move pointer
        ld      (hl), 0                             ; Null terminate complete path
        
        m_PrintCharInA             ; Print Next drive letter
        
        ld      hl, dynamic_data.working_path       ; Point to start of path
        ld      a, '*'                              ; This doesn't matter, pathspec overrides it
        m_esxdos F_OPENDIR                          ; Call ESXDOS without any wrappers (ROM already mapped)
        jr      c, .config_error
        ;; Path found, move to next usernumber, stop when we reach 9
        m_esxdos F_CLOSE                            ; Call ESXDOS without any wrappers (ROM already mapped)
        pop     af                                  ; Get the user number ASCII back
        cp      '9'
        jr      z, .b_tenplus_usernumber
        inc     a                                   ; Move to next usernumber, 0 thru 9
        pop     hl : push hl                        ; Restore end of string cache, and resave it
        jr      .b_test_usernumber
        
.b_tenplus_usernumber
        pop     hl                                  ; Restore end of string pointer
        ld      (hl), '1'
        push    hl                                  ; Keep new EoString safe, so we can use it again
        ld      a, '0'                              ; First user number, in ASCII
.b_test_tenplus_usernumber
        push    af
        ld      (hl), a                             ; Append to drive string
        inc     hl                                  ; Move pointer
        ld      (hl), 0                             ; Null terminate complete path
        
        add     a, $11
        m_PrintCharInA             ; Print Next drive letter
        
        ld      hl, dynamic_data.working_path       ; Point to start of path
        ld      a, '*'                              ; This doesn't matter, pathspec overrides it
        m_esxdos F_OPENDIR                          ; Call ESXDOS without any wrappers (ROM already mapped)
        jr      c, .config_error
        ;; Path found, move to next usernumber, stop when we reach 9
        m_esxdos F_CLOSE                            ; Call ESXDOS without any wrappers (ROM already mapped)
        pop     af                                  ; Get the user number ASCII back
        cp      '5'
        jr      z, .b_done
        inc     a                                   ; Move to next usernumber, 0 thru 9
        pop     hl : push hl                        ; Restore end of string cache, and resave it
        jr      .b_test_tenplus_usernumber
.b_done
        pop hl : pop hl
        
        
        ld      hl, dynamic_data.currdir            ; Realpath to use when DPM wants the C drive
        ld      a, '$'                              ; This doesn't matter, pathspec overrides it
        m_esxdos F_GETCWD                           ; Call ESXDOS without any wrappers (ROM already mapped)
        
        jr .setup_hardware

.config_error:
        ; pop     af : pop hl : pop hl
        ld a, 0x0D : m_PrintCharInA
        m_PrintMsg KERNEL.strings.error            ; Display "ERROR"
        m_CSpect_BREAK;jr $
        
.setup_hardware:
        ld      (KERNEL.dynamic_data.dot_stack), sp ;Preserve dotcommand stack pointer for exit of kernel
        ld      sp, stack                ; Use the stack internal to our kernel 
        
        ;; Patch DPM -- all these routintes are based around Dynamic MMU allocation
        ;; As such these Page and Unpage the "out of userland" memory
        ld      a, (KERNEL.dynamic_data.state.mmu0)         ; Get MMU0(userland0) and patch the following
        ld      (disable_esxdos_rom.SMC_MMU0), a
        
        ld      a, (KERNEL.dynamic_data.state.mmu1)         ; Get MMU0(userland0) and patch the following
        ld      (disable_esxdos_rom.SMC_MMU1), a
        
        ld      a, (KERNEL.dynamic_data.state.mmu2)         ; Get MMU1(userland1) and patch the following
        ld      (KERNEL_TERM.unmap_graphics_mem.SMC_MMU2), a
        
        ld      a, (KERNEL.dynamic_data.state.mmu3)         ; Get MMU2(userland2) and patch the following
        ld      (KERNEL_TERM.unmap_graphics_mem.SMC_MMU3), a
        
        ld      a, (KERNEL.dynamic_data.state.mmu4)         ; Get MMU3(userland3) and patch the following
        ld      (BIOS.entry_BOOTROM.SMC_MMU4_userland), a
        ld      (BIOS.internal_KERNEL_call.SMC_MMU4_userland), a
        ld      (BDOS.cache_current_fcb_for_kernel.SMC_MMU4_userland), a
        ld      (BDOS.restore_current_fcb_for_kernel.SMC_MMU4_userland), a
        ld      (BDOS.copy_dma_out_kernel.SMC_MMU4_userland), a
        
        ld      a, (KERNEL.dynamic_data.state.mmu5)         ; Get MMU4(userland5) and patch the following
        ld      (BIOS.entry_BOOTROM.SMC_MMU5_userland), a
        ld      (BIOS.internal_KERNEL_call.SMC_MMU5_userland), a
        ld      (BDOS.cache_current_fcb_for_kernel.SMC_MMU5_userland), a
        ld      (BDOS.restore_current_fcb_for_kernel.SMC_MMU5_userland), a
        ld      (BDOS.copy_dma_out_kernel.SMC_MMU5_userland), a
        
        ;ld      a, (KERNEL.dynamic_data.state.mmu6)         ; Get MMU6(userland6) and patch the following
        
        ;ld      a, (KERNEL.dynamic_data.state.mmu7)         ; Get MMU7(userland7) and patch the following
        
        ld      a, (KERNEL.dynamic_data.state.kernel0)      ; Get MMU3(kernel0) and patch the following
        ld      (BIOS.reentry_BOOTROOM.SMC_MMU4_kernel), a
        ld      (BIOS.internal_KERNEL_call.SMC_MMU4_kernel), a
        ld      (BDOS.cache_current_fcb_for_kernel.SMC_MMU4_kernel), a
        ld      (BDOS.restore_current_fcb_for_kernel.SMC_MMU4_kernel), a
        ld      (BDOS.copy_dma_out_kernel.SMC_MMU4_kernel), a
        ld      (BDOS.copy_dma_in_kernel.SMC_MMU4_kernel), a
        
        ld      a, (KERNEL.dynamic_data.state.kernel1)      ; Get MMU4(kernel1) and patch the following
        ld      (BIOS.reentry_BOOTROOM.SMC_MMU5_kernel), a
        ld      (BIOS.internal_KERNEL_call.SMC_MMU5_kernel), a
        ld      (BDOS.cache_current_fcb_for_kernel.SMC_MMU5_kernel), a
        ld      (BDOS.restore_current_fcb_for_kernel.SMC_MMU5_kernel), a
        ld      (BDOS.copy_dma_out_kernel.SMC_MMU5_kernel), a
        ld      (BDOS.copy_dma_in_kernel.SMC_MMU5_kernel), a
        
        ;; Store the DivMMC RAM control port so we can map/unmap it
        in      a, DIVMMC_CONTROL_P_E3          ; Get the current DivMMC mapping
        ld      (enable_esxdos_rom.SMC_conmem_ret), a ; And write to SMC code for later undo

        ;; Copy the STATE structure from DivMMC memory to the kernel
        ld      hl, @state;                 ; Copy From
        ld      de, dynamic_data.state;     ; Copy To
        ld      bc, end_state-start_state;  ; Length of Copy
        ldir                                ; ldi repeat. Go. 
        
        ;; Disable the DivMMC conmem, and set MMUs to FF
        nextreg	MMU0_0000_NR_50, 0xFF
        nextreg	MMU1_2000_NR_51, 0xFF 
        xor     a                           ; set a to 0
        out     DIVMMC_CONTROL_P_E3, a      ; Turn off DivMMC mapping
        
        ;; Copy font ASCII out of ROM
        ld      hl, $3D00;                  ; Copy From
        ld      de, $5D00;                  ; Copy To
        ld      bc, $0300;                  ; Length of Copy
        ldir                                ; ldi repeat. Go. 
        
        ; ;; Copy font CP437-2 out of ROM
        ld      hl, cp437_font;             ; Copy From
        ld      de, $6000;                  ; Copy To
        ld      bc, $0400;                  ; Length of Copy
        ldir                                ; ldi repeat. Go. 
        
        ;; Wipe the ULA Pixel area
        ld hl, 16384                        ;pixels
        ld de, 16385                        ;pixels + 1
        ld bc, 6144                         ;pixel area
        ld (hl), l                          ;set first byte to '0' as HL = 16384 = $4000  therefore L = 0
        ldir                                ;copy bytes 

        ;; Wipe the ULA Attribute area
        ld a, 56                            ;attributte
        ld bc, 768                          ;attribute area length - 1
        ld (hl), 0                          ;set first byte to attribute value
        ldir                                ;copy bytes 
        
        call KERNEL_TERM.clear                ; Clear entire tilemap
        
        ;;  Setup textmodes, graphics settings, colours, transparency, etc.
        m_NextRegRead_c CPU_SPEED_NR_07       ; Read current tilemap base address
        ld      (exit.SMC_tilemap_base_adr), a; Save current address
        nextreg TILEMAP_BASE_ADR_NR_6E, tilemapHiByte; Tilemap base address high byte
        
        m_NextRegRead_c TILEMAP_GFX_ADR_NR_6F ; Read current tilemap base address
        ld      (exit.SMC_tilemap_gfx_adr), a; Save current address
        nextreg TILEMAP_GFX_ADR_NR_6F, 0x5C ; Tile dataaddress at 0x6C00, ASCII @ 0x5D00
        
        m_NextRegRead_c GLOBAL_TRANSPARENCY_NR_14; Read current tilemap base address
        ld      (exit.SMC_global_transparency), a; Save current address
        nextreg GLOBAL_TRANSPARENCY_NR_14, 0x00; Confirm that the transparency is E3
        
        m_NextRegRead_c TRANSPARENCY_FALLBACK_COL_NR_4A; Read currenrt fallback colour
        ld      (exit.SMC_fallback_colour), a; Save current fallback colour
        nextreg TRANSPARENCY_FALLBACK_COL_NR_4A, 0x00; Set the fallback colour to black
        
        m_NextRegRead_c TILEMAP_CONTROL_NR_6B; Read tilemap control
        ld      (exit.SMC_tilemap_ctrl), a; Save tilemap control
        nextreg TILEMAP_CONTROL_NR_6B, 0b11101010; Set tilemap control
        /*                               | | | | bit 0 = Tilemap on top of ULA
                                         | | | +-bit 1 = 512 tile mode
                                         | | |   bit 2 = Reserved, must be 0
                                         | | +---bit 3 = Select textmode
                                         | |     bit 4 = Palette select 
                                         | +-----bit 5 = Eliminate attribute entry in tilemap
                                         |       bit 6 = 0 for 40x32, 1 for 80x32
                                         +-------bit 7 = 1 Enable the tilemap                   */
        
        nextreg     PALETTE_CONTROL_NR_43, 0x30; Tilemap primary palette
        nextreg     PALETTE_INDEX_NR_40, 0; Set palette place to first entry
        
        m_NextRegRead_c   PALETTE_VALUE_NR_41
        ld      (exit.SMC_tilemap_palette_0), a; Save current colour 0
        m_NextRegRead_c   PALETTE_VALUE_NR_41
        ld      (exit.SMC_tilemap_palette_1), a; Save current colour 1
        
        nextreg     PALETTE_INDEX_NR_40, 0; Reset palette place to first entry
        nextreg     PALETTE_VALUE_NR_41, 0x00       ;     Set new colour 0: Black
        nextreg     PALETTE_VALUE_NR_41, 0b00011100 ;     Set new colour 1: Green
        
        ld          (BIOS.kr_stack), sp ; Tell the BIOS where the kernel stack currently is
        
        ;; Print the bootROM banner
        ld      hl, KERNEL.strings.greeting
        call    kr_print_string_hl
        
        ;; "poke" standard CP/M setup into "Low Storage"
        ld      a, (dynamic_data.state.mmu0)
        nextreg	MMU0_0000_NR_50, a          ; Page in kernel0 (0x8000)
        ld      a, (dynamic_data.state.mmu1)
        nextreg	MMU1_2000_NR_51, a          ; Page in kernel0 (0x8000)
            ; JP BIOS-warm-boot, 0,   0,   JP BDOS
            ; $C3, $03, $FA,     $00, $00, $C3, $00, $E0
        ld      a, $C3                  ; $C3  == JP instruction
        ld      (REBOOT_A), a           ; BIOS jump
        ld      ($0005), a              ; BDOS jump
        ld      hl, BIOS.WBOOTE         ; BIOS warm boot entry point (not jump table)
        ld      ($0001), hl             ; Undocumented instruction! Copy HL to addr.
        ld      a, $00                  ; $00
        ld      ($0003), a              ; 
        ld      ($0004), a              ; User Number in Top Nybble, Disk in Low Nybble
        ld      hl, BDOS.entry          ; BDOS entry point
        ld      (BDOSPTR_A), hl         ; Undocumented instruction! Copy HL to addr.
        
.setup_exit
        ;; Finish the Kernel/ROM handler, return back to DotCommand - which will exit to NextZXOS
        call    enable_esxdos_rom
        
        ;; Restore the stack pointer
        ld      sp, (dynamic_data.dot_stack)
        
        ret                                 ; Return to the DOT command memory
        
;; Shutdown kernel services, revert hardware to NextZXOS settings
exit:                                    ; DPM exiting - safely shut down the VM changes
.SMC_tilemap_base_adr EQU $+3:
        nextreg TILEMAP_BASE_ADR_NR_6E, 0xAA; Restore original CPU speed using the SMC trick again.
        
.SMC_tilemap_gfx_adr EQU $+3:
        nextreg TILEMAP_GFX_ADR_NR_6F, 0xAA; Restore original CPU speed using the SMC trick again.
        
.SMC_global_transparency EQU $+3:
        nextreg GLOBAL_TRANSPARENCY_NR_14, 0xAA; Restore global transparency.
        
.SMC_fallback_colour EQU $+3:
        nextreg TRANSPARENCY_FALLBACK_COL_NR_4A, 0xAA; Restore fallback colour.
        
.SMC_tilemap_ctrl EQU $+3:
        nextreg TILEMAP_CONTROL_NR_6B, 0xAA; Restore tilemap control
        
        nextreg     PALETTE_CONTROL_NR_43, 0x30; Tilemap primary palette
        nextreg     PALETTE_INDEX_NR_40, 0; First Entry
.SMC_tilemap_palette_0 EQU $+3:
        nextreg     PALETTE_VALUE_NR_41, 0xAA       ;     Black
.SMC_tilemap_palette_1 EQU $+3:
        nextreg     PALETTE_VALUE_NR_41, 0xAA       ;     Green
        ret

;-----------------------------------------------------------------------------
;-- Kernel Internal Functions
;-----------------------------------------------------------------------------

enable_esxdos_rom:
        nextreg	MMU0_0000_NR_50, 0xFF
        nextreg	MMU1_2000_NR_51, 0xFF
        push    af
.SMC_conmem_ret EQU $+1
        ld      a, $AA
        out     DIVMMC_CONTROL_P_E3, a
        pop     af
        ret
disable_esxdos_rom:
        push    af
        xor     a                           ; set a to 0
        out     DIVMMC_CONTROL_P_E3, a      ; Turn off DivMMC mapping
        pop     af
.SMC_MMU0 EQU $+3:
        nextreg	MMU0_0000_NR_50, 0xAA
.SMC_MMU1 EQU $+3:
        nextreg	MMU1_2000_NR_51, 0xAA
        ret
        
;-----------------------------------------------------------------------------
;-- Kernel VDU functions
;-----------------------------------------------------------------------------

kr_print_string_hl:
        push    af
.string_print
        ld      a, (hl)                     ; Get character
        cp      0                           ; Compare to zero, Z flag if matched
        jp      z, .string_done;
        call    KERNEL_TERM.process
        inc     hl
        jr      .string_print
.string_done:
        pop     af
        ret
        
;-----------------------------------------------------------------------------
;-- Kernel debug routines from BIOS
;-----------------------------------------------------------------------------
kr_print_unimplimented:
        ld      hl, KERNEL.strings.unimplimented
        jp      kr_print_string_hl
kr_print_error:
        ld      hl, KERNEL.strings.error
        jp      kr_print_string_hl

kr_print_called:
        ld      hl, KERNEL.strings.called
        jp      kr_print_string_hl

kr_PrintHex16AtHL:
        push    af
        ld      a, '[' : call KERNEL_TERM.process
        push    bc
        ld      c, h                 ; Load the first byte (high-value)
        call    kr_PrintHex8
        ld      c, l                 ; Load the low-value
        call    kr_PrintHex8
        pop     bc
        ld      a, ']' : call KERNEL_TERM.process
        pop     af
        ret

; Output the hex value of the 8-bit number stored in C
;   Uses A
kr_PrintHex8:
        ld      a,c
        rra
        rra
        rra
        rra
        ; First nybble
        call    kr_PrintIntNybbleAsHex
        ld      a,c
        call    kr_PrintIntNybbleAsHex
        ret
        
        ; Fall through for second nybble
kr_PrintIntNybbleAsHex:
        and     $0F                 ; Mask lower nybble
        add     a,$90               ;   Add constants
        daa                         ;   Adjust for BCD
        adc     a,$40               ;   Add second constant
        daa                         ;   Finish adjusting
        call    KERNEL_TERM.process     ; Show the value
        ret
;-----------------------------------------------------------------------------
;-- Helper routines used by BDOS
;-----------------------------------------------------------------------------

; copy string pointed to by DE to HL
; DE to be null terminated, leaves HL null terminated
; Dirties both A, DE and HL, both pointing at null values of original strings
strcpy:
        ld      a, (de)
        ld      (hl), a
        cp      0
        jr      z, .done
        inc     de
        inc     hl
        jr      strcpy
.done
        ret

;-----------------------------------------------------------------------------
;-- BDOS file handler helpers
;-----------------------------------------------------------------------------

;
; Pass in de -> fcb
; Transfer all the filename from fcb to the filename_buffer.
; Skip NULLs spaces and add in the ".", and terminate with NULL.
; Preserves de.
; kr_copy_fcb_to_buffers_preserving_spaces:
;         push    de
;         ex      de, hl                  ; hl = fcb
;         ld      de, cache.filename ; de = address of filename_buffer
;         ld      a, (hl)                 ; First byte in FCB is 0 or 1-16. We want 0=>A, 15=>P
;         cp      0                       ; Is requested drive 0, if so it means "current", don't change
;         jr      nz, .buffer1
;         ld      a, (BDOS.current_disk)  ; Select current drive, as FCB was zero.
;         inc     a                       ; Adjust 0-15 to 1-16
; .buffer1:
;         add     a, 'A'-1
;                                         ; Chance to selected drive letter
;         ld      (de), a
;         inc     de
;         ld      a, '/'
;         ld      (de), a
;         inc de
;         inc hl
;         push hl
;         ld b, 8
; .copy_fcb1_ps:
;         ld a, (hl)
;         inc hl
;         cp 0
;         jr z, .copy_fcb2_ps
;         ld (de), a
;         inc de
;         djnz .copy_fcb1_ps
; .copy_fcb2_ps:
;         ld a, '.'                   ; Put in the dot
;         ld (de), a
;         inc de

;         pop hl
;         ld bc, 8
;         add hl, bc                   ; Move along to extension
;         ld b, 3
; .copy_fcb3_ps:
;         ld a, (hl)
;         inc hl
;         cp 0
;         jr z, .copy_fcb4_ps
;         ld (de), a
;         inc de
;         djnz .copy_fcb3_ps
; .copy_fcb4_ps:
;         xor a
;         ld (de),a
;         pop de
;         ret


;-----------------------------------------------------------------------------
;-- Kernel routine used during handing control from BOOTROM to BIOS
;-----------------------------------------------------------------------------
BOOTROM:
        call    disable_esxdos_rom
        ;; Map the remainder of the MMUs
        ld      a, (dynamic_data.state.mmu0)
        nextreg	MMU0_0000_NR_50, a
        ld      a, (dynamic_data.state.mmu1)  
        nextreg	MMU1_2000_NR_51, a
        ld      a, (dynamic_data.state.mmu2)  
        nextreg	MMU2_4000_NR_52, a
        ld      a, (dynamic_data.state.mmu3)  
        nextreg	MMU3_6000_NR_53, a
        ;; 4 and 5 are the kernel, we do them from the BIOS
        
        ;; Copy the CCP into upper memory
        ld      hl, ccp_image;              ; Copy From
        ld      de, CCP_A;                  ; Copy To
        ld      bc, ccpBinSz;               ; Length of Copy
        ldir                                ; ldi repeat. Go. 
        
        call    KERNEL_TERM.init
        ld      a, $ff                      ; To make sure there's no pending keys
        ld      (KERNEL.dynamic_data.console_cache), a; We write FF to the console_cache
        
        ret
        
;
;-----------------------------------------------------------------------------
;-- Kernel entrypoints from BIOS
;-----------------------------------------------------------------------------
BIOS_BOOT:
BIOS_WBOOT:
        call      KERNEL.BOOTROM
        
;
; Returns status in A; 0 if no character is ready, 0FFh if one is.
BIOS_CONST:
        call    KERNEL_KEYBOARD.read_char_a ; Read matrix, process all combos
        cp      $FF                         ; Is it a valid key?
        jp      z, KERNEL.ret0_in_a         ; ...$ff, invalid, return zero
        ld      (KERNEL.dynamic_data.console_cache), a; Valid, cache key
        jp      KERNEL.ret255_in_a

;
; Wait until the keyboard is ready to provide a character, and return it in A.
BIOS_CONIN:
        ld      a, (KERNEL.dynamic_data.console_cache); Get any pending key
        jr      .valid_key_check            ; Check if it's a valid key first
.read_keyboard
        call    KERNEL_KEYBOARD.read_char_a ; Read matrix, process all combos
.valid_key_check:
        cp      $FF                         ; Is it a valid key?
        jr      z, .read_keyboard           ; ...$ff, invalid, so get new key
        ld      hl, KERNEL_KEYBOARD.prevkey ; Pointer to previous key
        cp      (hl)                        ; Compare to current key
        jr      z, .read_keyboard           ; ...Same, get a new key
        ld      (KERNEL_KEYBOARD.prevkey), a; Not same, save key
        ld      a, $ff                      ; There's no keys pending now
        ld      (KERNEL.dynamic_data.console_cache), a; so save that state
        ld      a, (KERNEL_KEYBOARD.prevkey); Get the saved pressed key
        ret
        
        
BIOS_CONOUT:
        push    af
        ld      a, c
.print_char_a
        call    KERNEL_TERM.process
        pop     af
        ret
        
BIOS_LIST:
        m_kr_unimplimented LIST_string
LIST_string:
        DB "BIOS_LIST", 0
        
BIOS_PUNCH:
        m_kr_unimplimented PUNCH_string
PUNCH_string:
        DB "BIOS_PUNCH", 0
        
BIOS_READER:
        m_kr_unimplimented READER_string
READER_string:
        DB "BIOS_READER", 0
        
BIOS_HOME:
        m_kr_unimplimented HOME_string
HOME_string:
        DB "BIOS_HOME", 0
        
BIOS_SELDSK:
        m_kr_unimplimented SELDSK_string
SELDSK_string:
        DB "BIOS_SELDSK", 0
        
BIOS_SETTRK:
        m_kr_unimplimented SETTRK_string
SETTRK_string:
        DB "BIOS_SETTRK", 0
        
BIOS_SETSEC:
        m_kr_unimplimented SETSEC_string
SETSEC_string:
        DB "BIOS_SETSEC", 0
        
BIOS_SETDMA:
        m_kr_unimplimented SETDMA_string
SETDMA_string:
        DB "BIOS_SETDMA", 0
        
BIOS_READ:
        m_kr_unimplimented READ_string
READ_string:
        DB "BIOS_READ", 0
        
BIOS_WRITE:
        m_kr_unimplimented WRITE_string
WRITE_string:
        DB "BIOS_WRITE", 0
        
BIOS_LISTST:
        m_kr_unimplimented LISTST_string
LISTST_string:
        DB "BIOS_LISTST", 0
        
BIOS_SECTRAN:
        m_kr_unimplimented SECTRAN_string
        
SECTRAN_string:
        DB "BIOS_SECTRAN", 0
;
USERF
        m_kr_unimplimented USERF_string
USERF_string:
        DB "BIOS_USERF", 0


;
;-----------------------------------------------------------------------------
;-- Kernel entrypoints from BDOS
;-----------------------------------------------------------------------------

; Entered with C=0. Does not return.
BDOS_P_TERMCPM:     ; Function 0
        ; Quit the current program, return to command prompt. 
        ; Hardly ever used since the RST 0 instruction does same & saves 4 bytes.
        call    KERNEL_BDOS.clear_current_fcb   ; Clear the Current_fcb
        ld      hl, KERNEL.strings.restarting
        call    KERNEL.kr_print_string_hl
        jp      $0000
        ; jp      BIOS.entry_BOOTROM

; Read a key from the keyboard, if none wait until key pressed
; Echo it to screen, and obey things like Tab, Backspace etc
; Entered with C=1. Returns A=character, $FF=No Char
BDOS_C_READ:        ; Function 1
        call    BIOS_CONIN
        cp      32                          ; Is it a control character?
        ret     c                           ; ...Yes, just return
        cp      KERNEL_KEYBOARD.DEL         ; Is it the DEL character?
        ret     z                           ; ...Yes, just return
        call    KERNEL_TERM.process             ; ...No, print character
        ret
;
; Entered with C=2, E=ASCII character.
BDOS_C_WRITE:       ; Function 2
        push    af
        ld      a, e
        jp      BIOS_CONOUT.print_char_a
        
BDOS_A_READ:; Function 3
        ; Note that this call can hang if the auxiliary input never sends data.
            m_kr_unimplimented BDOS_A_READ_string
BDOS_A_READ_string:
        DB "BDOS_C_WRITE", 0
        jp ret255_in_a

BDOS_A_WRITE:
            m_kr_unimplimented BDOS_A_WRITE_string
BDOS_A_WRITE_string:
        DB "BDOS_C_WRITE", 0

entry_List_Output:
        jp ret255_in_a

; Direct Console IO. E==$FF means read, else write char in E to screen
BDOS_C_RAWIO:
        ld      a, e
        cp      $FF
        jr      nz, .write_console
        call    KERNEL_KEYBOARD.read_char_a
        ; ld      b, 1
        call    KERNEL_DEBUG.tm_a_loc74
        cp      $FF
        jr      z, .set_zero
        or      a
        jr      z, .set_zero
        ret
.set_zero:
        xor     a
        ret
.write_console
        call    KERNEL_TERM.process
        jp      ret0_in_a
        
        
BDOS_L_WRITE:
        jp      BDOS_C_RAWIO.write_console

BDOS_IO_GET:
            m_kr_unimplimented BDOS_IO_GET_string
BDOS_IO_GET_string:
        DB "BDOS_IO_GET", 0
        jp ret0_in_a

BDOS_IO_SET:
            m_kr_unimplimented BDOS_IO_SET_string
BDOS_IO_SET_string:
        DB "BDOS_IO_SET", 0
        ; call show_entry_message
        ; call CORE_message
        ; db 'Set_IO_Byte',13,10,0
        jp ret1_in_a

BDOS_C_WRITESTR:     ; Print the string at "de" until we see a "$"
        ld      a, (de)
        inc     de
        cp      '$'
        jr      z, .done
        ld      c, a
        call    BIOS_CONOUT
        jp      BDOS_C_WRITESTR
.done
        jp ret0_in_a

; Read a line of input from the keyboard into a buffer pointed to by DE
; The first two bytes of the buffer contain its max length and final length.
; Read in keys and put them into the buffer until the max length is reached,
; or the user presses Enter. Obey chars like Tab and Backspace.
BDOS_C_READSTR:
        ex      de, hl                  ; Read destination pointer now in HL
        ld      d, (hl)                 ; d = max buffer length
        inc     hl
        ld      (hl), 0                 ; reset the "final length" byte.
        ld      c, l                    ;  c == lowbyte of len
        ld      b, h                    ;  b == hibyte of len
        ld      e, 0
        inc     hl
        ex      de, hl                  ; DE points to start of buffer space
        push    hl                      ; Fake an "ex hl, bc" so that we end 
        push    bc                      ;  up with the HL pointing at the
        pop     hl                      ; "final length" byte, and now BC
        pop     bc                      ; contains the max buffer length
.read_to_buffer:
        push    hl
        push    de
        push    bc
        call    BDOS_C_READ             ; Get a char and echo it
        pop     bc
        pop     de
        pop     hl
        
        cp      KERNEL_KEYBOARD.CR      ; CR==13==Done
        jr      z, .done
        
        cp      KERNEL_KEYBOARD.BS      ; Ctrl-H key?
        jr      z, .backspace
        
        cp      KERNEL_KEYBOARD.DEL     ; Backspace
        jr      z, .backspace
        
        cp      24                      ; ctrl-x -> empty line / cancel
        jr      z,.read_clear_line
        
        cp      21                      ; ctrl-u -> empty line / cancel
        jr      z,.read_clear_line
        
        cp      3
        jr      z,.read_clear_line      ; ctrl-c -> reset line
        
        cp      32
        jr      c, .read_to_buffer
        ld      (de), a                 ; Store the char in the buffer
        inc     (hl)                    ; Increase the final-chars-count
        inc     de                      ; Move on to next place in buffer
        
        djnz   .read_to_buffer          ; dec the maxchars and continue if !full
.done:
        ld      b, 0
        ret
.reboot_if_start_of_line:
        push    af
        ld      a,(hl)
        cp      0
        jr      z, .reboot
        pop     af
        jp      .read_clear_line
.reboot:
        pop     af
        jp      $0000
.read_clear_line:
        ld      (hl), 0               ; zero characters entered
        inc     hl
        ld      (hl), 0               ; first character is a null
        ld      b, 0
        ret
.backspace:
        ld      a, (hl)                     ; If final-chars is zero we can't go back any more
        cp      0
        jr      z, .read_to_buffer
        ld      a, ' '                      ; Otherwise continue...
        dec     de
        ld      (de), a                     ; Clear out most recent char
        dec     (hl)                        ; Decrease final-chars-count
        ld      a, 8
        call    KERNEL_TERM.process             ; Print it to go back one space
        ld      a, ' '
        call    KERNEL_TERM.process             ; Cover over most recent char with space
        ld      a, 8
        call    KERNEL_TERM.process             ; Print it to go back one space
        inc     b                           ; Increase max-chars-counter
        jr      .read_to_buffer
        
;        
; Entered with C=0Bh. Returns A=L=status
BDOS_C_STAT:
        call    BIOS_CONST
        ld      l, a
        ret

BDOS_S_BDOSVER:
        ld a, $22                   ; This is CP/M v2.2
        ld b, 0
        ret

BDOS_DRV_ALLRESET:
        call    KERNEL_BDOS.clear_current_fcb          ; Clear out current FCB
        ld      e, 0
        call    BDOS_DRV_SET                           ; Choose disk A:

        ld      hl, $0080
        ld      (BDOS.dma_address), hl                 ; Set standard DMA location
        
        ret

;
; Change to drive letter in a, 0=A,etc.  C set on error 
; Doesn't actually change set the drive letter on NextZXOS, but uses a change and back to detect it.
BDOS_DRV_SET:
        push    de
        call    KERNEL_BDOS.close_file              ; If we are changing disks, close any files
        pop     de
        push    de
        ld      a, e                                ; Disk is in E, copy to A.   0 = A:, 15 = P:

        cp      16                                  ; Make sure desired disk is in range 0..15
        jp      nc, .error

        cp      2
        jp      c, .virtual_drive                   ; A and B (0 and 1) alias to a folder structure
        
        ;; Check if drive exists in NextZXOS
        rlc a : rlc a : rlc a                       ; Shift left 3, drive# in bits 7 thru 3 now.
        inc a                                       ; Ensure first bit is set so that A drive !=0
        m_kr_esxdos M_GETSETDRV
        jp      c, .error
        ;; And since it does put us back on the drive we started from...
        and     a, 0b00011001                       ; Active drive is always C for us
        m_kr_esxdos M_GETSETDRV
        ; Fall through to virtual_drive, so that it can create the path in the cache.

.virtual_drive:                                 ; Handle ESXDOS folder-as-a-drive, a is 0 or 1
        pop     de : push de                        ; restore E
        ld      b, e                                ; Disk is in E, copy to B.   0 = A:, 15 = P:
        ld      a, (BDOS.current_user)
        ld      c, a                                ; User number copied to C.   0 thru 15
        ld      hl, KERNEL_BDOS.current_esxdos.filepath; Destination pointer for path in HL
        call    KERNEL_BDOS.drive_and_user_to_path
        
.done:
        pop     de
        ld      a, e
        ld      (BDOS.current_disk), a              ; Store disk
        
        call    KERNEL_BDOS.clear_current_fcb       ; Clear out current FCB
        
        xor     a                                   ; Wipe A
        ld      b, a                                ; ...and B
        
        ret

.error:
            ; push    af : ld a, 'E' : call KERNEL_TERM.process : pop af

        pop     de
        ld      hl, msg.error_on
        call    kr_print_string_hl
        ld      a, e
        add     a, 'A'
        call    KERNEL_TERM.process
        ld      a, ':'
        call    KERNEL_TERM.process
        // set carry
        ret

;
; Open file referenced by FCB, passed in DE - with A=0 for reset to start, A=1 to resume offset
; The FCB that was passed in gets copied into the Current_FCB so we know which file is open.
;  Return a = 0 for success, a = 255 for error.
BDOS_F_OPEN:
        call    BDOS.cache_current_fcb_for_kernel ; Userland call, cache FCB for use in kernel
.kernel_entry:
        xor     a                                   ; Wipe A
.resume:
        push    de                                  ; Preserve the incoming settings
        push    af                                  ; DE and A are the ones that matter
        ld      a, (KERNEL_BDOS.current_esxdos.file_handle); Get the existing cached file handle
        cp      0                                   ; Was it Zero, aka not valid
        jr      z, .nothing_to_close                ; ...Nope! do nothing
        call    KERNEL_BDOS.close_file              ; ...Yep - shut it down!
.nothing_to_close
        pop     af
        pop     de                                  ; Now use FCB to open the file
        cp      0                                   ; Were we called with A==0?
        jr      nz, .open_file                      ; ...Yes! Open the file next
        ex      de, hl                              ; ...No! Reset offset.  So move FCB now in HL(!!)
        ld      bc, 0                               ; Wipe the file blocks offset which will be...
        ld      de, 0                               ; ...passed into set_block_num_in_fcb in BCDE
        call    KERNEL_BDOS.set_block_num_in_fcb    ; Reset the file pointer params in S2, EX and CD
        ex      de, hl                              ; FCB now back in DE, as "normal"
.open_file:
        push    de                                  ;
        call    KERNEL_BDOS.copy_fcb_to_buffers     ; Parse the relevent filedir and filename out of the FCB
        ld      a, 0                                ; Flag to denote source of filename. 0==buffer
        call    KERNEL_BDOS.copy_buffers_to_fullpath; And join them together for an ESXDOS file call
        
        ld      a, '*'                              ; This doesn't matter, pathspec overrides it
        ld      hl, KERNEL_BDOS.current_esxdos.fullpath; Full drive/path/filename combi, by copy_buffers_to_fullpath
        ld      b, esx_mode_read + esx_mode_write + esx_mode_open_exist ; Open Read+Write, if file exists
        m_kr_esxdos  F_OPEN
        jr      nc, .open_file_success
        pop     de
        call    KERNEL_BDOS.clear_current_fcb       ; No open file, no Current FCB - wipe it
        jp      ret255_in_a                         ; Jump to error setting return helper
.open_file_success:
        ld      (KERNEL_BDOS.current_esxdos.file_handle), a
        pop     de
        call    KERNEL_BDOS.copy_fcb_to_current_fcb ; File is now open, so copy FCB to Current FCB

        jp      restore_fcp_ret0_in_a
        
;
; Pass in de -> FCB - return 0 for success, 255 for fail
BDOS_F_CLOSE:
        ;; Since we backend this to a pure ESXDOS close, and then just wipe the current FCB, 
        ;; we don't need to do anything with the FCB passed in.... this is here as a reminder
        ;; if and when we start to support multiple open files, then we will need to use the 
        ;; FCB passed in to find the right file to close.
        ; call BDOS.cache_current_fcb_for_kernel      ; cache FCB for use in kernel (mutate DE)
        call KERNEL_BDOS.close_file
        call KERNEL_BDOS.clear_current_fcb          ; Clear out current FCB
        jp ret0_in_a

;
; Input is DE -> FCB with drive & filename/wildcards
; Returns A=$FF if nothing or A=0, and directory entry in DMA location.
; The drive can be 0 to 15 for A to P, or '?' to mean current drive, leaves disk
; so that "search_for_next" get the next entry.
BDOS_F_SFIRST:
        ld      a, 0
        ld      (file_counter), a
        ld      a, (KERNEL_BDOS.current_esxdos.dir_handle)
        push    de
        m_kr_esxdos F_CLOSE
        pop     de
        
        call    KERNEL_BDOS.copy_fcb_to_buffers
        
        ld      a, '*'                  ; Not super important, spec filedir overrides this
        ld      b, esx_mode_short_only + esx_mode_use_wildcards + esx_mode_sf_enable
        ld      c, esx_sf_exclude_dirs + esx_sf_exclude_dots
        
        ld      hl, KERNEL_BDOS.current_esxdos.filepath
            ; push af : push bc : push de : push hl : call KERNEL.kr_print_string_hl : pop hl : pop de : pop bc : pop af
        ld      de, KERNEL_BDOS.current_esxdos.filename
            ; push af : push bc : push de : push hl : push hl : pop de : call KERNEL.kr_print_string_hl : pop hl : pop de : pop bc : pop af
            
        m_kr_esxdos F_OPENDIR
        jr      c, .error
        
        ld      (KERNEL_BDOS.current_esxdos.dir_handle), a; Save the opened directory handle
        ; ld      hl, KERNEL_BDOS.current_esxdos.dir_depth; Pointer to word containing how many files down we are
        ; ld      (hl), 0                 ; Set to zero, as new directory
        
        jr      BDOS_F_SNEXT
        
.error
        ;; Do proper error stuffs here
        m_kr_fatal BDOS_F_SFIRST_error
BDOS_F_SFIRST_error:
        DB "Failed to open drive", 0

file_counter:
        db      0
        
BDOS_F_SNEXT:
        ld      a, (KERNEL_BDOS.current_esxdos.dir_handle)
        
        ; ld      b, esx_mode_short_only + esx_mode_use_wildcards
        ; ld      c, esx_sf_exclude_dirs + esx_sf_exclude_dots
        ld      hl, KERNEL_BDOS.current_esxdos.entry; buffer to write result into
        ld      de, KERNEL_BDOS.current_esxdos.filename; Wildcard string to match files against
        m_kr_esxdos F_READDIR
        cp      0
        jr      z, .not_found
        
        ld      a, (file_counter)
        inc     a
        ld      (file_counter), a
; .found:
        ld      hl, KERNEL_BDOS.current_esxdos.entry; the first time around the copyloop skips a byte
        ld      de, BDOS.dma_cache                  ; Both of these are one too low, so that
        call    KERNEL_BDOS.esxdos_to_FCB
        call    BDOS.copy_dma_out_kernel
        jp      ret0_in_a                           ; Something Found!
.not_found:
        ld      a, (KERNEL_BDOS.current_esxdos.dir_handle)               ; (not sure if I should be doing this here)
        m_kr_esxdos F_CLOSE                         ; But since we exhausted the dir-search, close dir.
        jp      ret255_in_a                         ; Found nothing
;
; Delete file in DE's FCB. Return's 0 for success, 255 otherwise
;     Uses a lot of the same routines as DIR under the hood, to find files to delete.
BDOS_F_DELETE:
        ld      a, 255                              
        ld      (KERNEL_BDOS.current_esxdos.delete_flag), a; Store the result
        
        ld      a, (de)                             ; Pop Drive Name into A
        ld      (KERNEL.dynamic_data.store_source), a; And then write it to somewhere safe

        push    de
        call    KERNEL_BDOS.clear_current_fcb            ; Clear out current FCB
        pop     de

.loop:
        push    de                                  ; Put FCB pointer back on stack

        ld      a, (BDOS.current_user)
        call    BDOS_F_SFIRST
        
        push    af
        ld      a, (KERNEL_BDOS.current_esxdos.dir_handle); (not sure if I should be doing this here)
        m_kr_esxdos F_CLOSE                         ; Close directory, start from scratch if required.
        pop     af
        
        cp      255
        jr      z, .done

        xor     a
        ld      (KERNEL_BDOS.current_esxdos.delete_flag), a; Store a success reult

        ld      de, BDOS.dma_cache                  ; SFIRST leaves a copy of the FCB in the dma_cache
        call    KERNEL_BDOS.copy_fcb_to_buffers     ; Convert it to ESXDOS paths
        ld      a, 0                                ; Flag to denote source of filename. 0==buffer
        call    KERNEL_BDOS.copy_buffers_to_fullpath; Join ESXDOS paths together
        
        ld      a, '*'                              ; Not important, filepath overrides it.
        ld      hl, KERNEL_BDOS.current_esxdos.fullpath; Full path to file to delete
        m_kr_esxdos F_UNLINK
        jr      c, .error
        pop     de                                  ; Get original FCB back
        jr      .loop
.done:
        pop     de
        ld      a, (KERNEL_BDOS.current_esxdos.delete_flag)
        ld      b, 0
        ret
.error:
        pop     de
        jp      ret255_in_a
;
; Read 128bytes from a FCB to DMA address, Returns a non-zero value on error.
;     When <128 bytes, remainder is padded with NULLs, updates Current_FCB
;     pointer values with every read.
BDOS_F_READ:
        call    BDOS.cache_current_fcb_for_kernel ; Userland call, cache FCB for use in kernel (mutate DE)
        push    de                                  ; Keep the DE
                        ; call KERNEL_DEBUG.print_crlf
                        ; ld hl, KERNEL_DEBUG.read__string : call KERNEL.kr_print_string_hl
                        ; inc     de : push de : pop hl : call KERNEL.kr_print_string_hl : call KERNEL_DEBUG.print_crlf
        pop de: push de
                        ; ld      a, '[' : call KERNEL_TERM.process
        call    KERNEL_BDOS.match_current_fcb       ; Is this the same as we already have open?
        jr      z, .file_match                      ; ...Yes (read attempt follows matching open)
                        ; ld      a, '!' : call KERNEL_TERM.process
        call    KERNEL_BDOS.close_file              ; ...No. Close existing file.
        ld      a, 1                                ; Open new file but don't update file pointer
        call    KERNEL.BDOS_F_OPEN.resume           ; Open using existing file pointer in A
        pop     de
        push    de
.file_match:
    ; Now jump to the right place in the file
        call    KERNEL_BDOS.get_block_num_from_fcb; Calculate file blocks in BCDE
            ld      a, b : call KERNEL_DEBUG.tm_a_loc18
            ld      a, c : call KERNEL_DEBUG.tm_a_loc20
            ld      a, d : call KERNEL_DEBUG.tm_a_loc22
            ld      a, e : call KERNEL_DEBUG.tm_a_loc24
        call    KERNEL_MATHS.mul_bcde_by_128; BCDE now byte offset into file
        push    de                          ; calculate the offset didn't exceed length
        push    bc                          ; We need to preserve the offset, so that we can...
            ld      a, b : call KERNEL_DEBUG.tm_a_loc28
            ld      a, c : call KERNEL_DEBUG.tm_a_loc30
            ld      a, d : call KERNEL_DEBUG.tm_a_loc32
            ld      a, e : call KERNEL_DEBUG.tm_a_loc34
        ld      a, (KERNEL_BDOS.current_esxdos.file_handle); Get the file handle of the open file
        ld      l, esx_seek_set             ; Tell seek to use absolute positioning.
        m_kr_esxdos F_SEEK                          ; Seek to our byte offset, still in BCDE
            ld      a, b : call KERNEL_DEBUG.tm_a_loc38
            ld      a, c : call KERNEL_DEBUG.tm_a_loc40
            ld      a, d : call KERNEL_DEBUG.tm_a_loc42
            ld      a, e : call KERNEL_DEBUG.tm_a_loc44

        pop     hl
        ld      a, b
        cp      h
        jr      nz, .seek_fail              ; Not requested seek value, bail after balancing stack
        ld      a, c
        cp      l
        jr      nz, .seek_fail              ; Not requested seek value, bail after balancing stack
        pop     hl
        ld      a, d
        cp      h
        jr      nz, .read_fail              ; Not requested seek value, bail
        ld      a, e
        cp      l
        jr      nz, .read_fail              ; Not requested seek value, bail
        call    KERNEL_BDOS.read_128_bytes_to_dma
        jr      nz, .read_fail                      ; Read failed!
        pop     de                                  ; Get original FCB back again
        push    de                                  ; But still keep it safe for later
        call    KERNEL_BDOS.get_block_num_from_fcb  ; And get the block pointer again
        call    KERNEL_MATHS.inc_bcde               ; Increment 32bit BCDE by 1
        pop     hl                                  ; Restore FCB into HL
            ld      a, b : call KERNEL_DEBUG.tm_a_loc48
            ld      a, c : call KERNEL_DEBUG.tm_a_loc50
            ld      a, d : call KERNEL_DEBUG.tm_a_loc52
            ld      a, e : call KERNEL_DEBUG.tm_a_loc54
        call    KERNEL_BDOS.set_block_num_in_fcb    ; Store BCDE blocknum in FCB
        ex      de, hl                              ; FCB back in DE now
        call    KERNEL_BDOS.copy_fcb_to_current_fcb ; Make a note of the state of the currently open file
        
        jp restore_fcp_ret0_in_a                      ; Success
.seek_fail:
        pop     de                                  ; Balance remainder of pushed BC/DE
.read_fail:
        pop     de                                  ; Restore DE from stack
        ld a, 1                                     ; 1 = seek to unwritten extent
        ld b, 0
        ret

BDOS_F_WRITE:
    ; Pass in de -> FCB
    ; Return a = 0 on success, or a = 255 on error
    ; We need to write 128 bytes from the current DMA address to the
    ; current position of the file referenced in FCB.
    ; Start by checking that the FCB equals the Current FCB.
    ; If not, close the current file and open the new one, jumping to the right place.
    ; If so just proceed.
    ; Then increase the pointer in the FCB and copy it to Current_FCB.

;    push de
;    call disk_activity_start
dont_turn_on:
;    call match_current_fcb
;    jr z, entry_Write_Sequential1
;    ; Need to close existing file and open the new one.
;    ld a, 1                                     ; Open new file but don't update file pointer
;    call BDOS_F_OPEN.actual
;    pop de
;    push de
    ; Now jump to the right place in the file
;    call get_block_num_from_fcb              ; bcde = file pointer
;    call multiply_bcde_by_128                   ; bcde = byte location in file
;    call CORE_move_to_file_pointer              ; move to that location
;    cp USB_INT_SUCCESS
;    jr nz, entry_Write_Sequential_fail
entry_Write_Sequential1:
;    ld de, (dma_address)
;    call CORE_write_to_file
;    call CORE_disk_off
;    pop de                                      ; Get the FCB location back
;    push de
;    call get_block_num_from_fcb              ; bcde = file pointer
;    call KERNEL_MATHS.inc_bcde
;    pop hl
;    call set_file_pointer_in_fcb
;    ex de, hl
;    call copy_fcb_to_current_fcb                ; Make a note of the state of the currently open file
        jp ret0_in_a

entry_Write_Sequential_fail:
;    pop de
;    call CORE_message
;    db 'BDOS write error!',13,10,0
;    call CORE_disk_off
;    jr ret255_in_a

BDOS_F_MAKE:
    ; Make File passes in DE->FCB
    ; Returns a = 0 for success and a = 255 for failure
;    push de
;
;    call KERNEL_BDOS.close_file                                 ; just in case another file is open
;
;    pop de
;    push de
;    call copy_fcb_to_filename_buffer
;
;    call CORE_disk_on
;    call CORE_connect_to_disk
;    call CORE_mount_disk
;
;    call open_cpm_disk_directory
;
;    ld de, filename_buffer+2            ; Specify filename
;    call CORE_create_file
;
;    jr z, make_file_success
;
;    call CORE_disk_off
;    pop de
;    call clear_current_fcb                          ; Clear out current FCB because of fail.
;    jr ret255_in_a                              ; error
make_file_success:
;    call CORE_disk_off
;    pop de
;    call copy_fcb_to_current_fcb                    ; This is now the currently open file
        jp ret0_in_a

BDOS_F_RENAME:
    ; DE points to a FCB with the
    ; SOURCE filename at FCB+0 and
    ; TARGET filename at FCB+16.
    ; The disk drive must be the same in both names, or else error.
    ; Check if the target file already exists. If so return with error.
    ; Success a = 0
    ; Error a = 255

   ld (dynamic_data.store_source), de                  ; Store source FCB pointer for now
   push de
   call KERNEL_BDOS.close_file                         ; just in case there is an open one.
   pop de

   ld hl, 16
   add hl, de
   ld (BDOS.store_target), hl                               ; And store the target FCB for now
   ex de, hl                                           ; target is now in de

            m_kr_unimplimented BDOS_F_RENAME_string
BDOS_F_RENAME_string:
        DB "BDOS_F_RENAME", 0

    ; Check if target drive is "default", if so, copy from source.
;    ld hl, (store_target)                           ; retrieve pointer to target file
;    ld a, (hl)                                      ; Target file drive letter
;    cp 0                                            ; Is the target of the default drive?
;    jr nz, entry_Rename_target_not_default           ; This indicates it should be the same as the source
;    ld de, (store_source)
;    ld a, (de)
;    ld (hl), a                                      ; Copy drive from source to target

entry_Rename_target_not_default:
    ; Check if both drives are the same. If not return error.
;    ld hl, (store_target)
;    ld a, (hl)                                      ; Get target drive
;    ld hl, (store_source)                           ; retrieve source fcb
;    cp (hl)                                         ; Are drive letters the same?
;    jr nz, entry_Rename_File_different_drives

    ; Try opening target file. If we can then return an error.
;    ld de, (store_target)
;    call copy_fcb_to_filename_buffer
;    call open_cpm_disk_directory
;    ld hl, filename_buffer+2                        ; Specify filename
;    call CORE_open_file
;    jr z, entry_Rename_File_exists

entry_Rename_File_same_drives:
    ; Open the source file.
;    call KERNEL_BDOS.close_file
;    ld de, (store_source)
;    call copy_fcb_to_filename_buffer
;    call open_cpm_disk_directory
;    ld hl, filename_buffer+2                        ; Specify source filename
;    call CORE_open_file
;    jp nz, entry_Rename_File_no_source

    ; Read in the P_FAT_DIR_INFO
;    call CORE_dir_info_read
;    jr nz, entry_Rename_File_no_source

    ; Update the name of the target file by copying the name from target to source
;    ld hl, (store_target)
;    inc hl
;    ld de, disk_buffer
;    ld bc, 11
;    ldir

    ; Write it back again.
;    call CORE_dir_info_write

    ; Close the file.
;    call KERNEL_BDOS.close_file

;    call clear_current_fcb                          ; Clear out current FCB
        jp ret0_in_a                                ; success
entry_Rename_File_exists:
    ;call CORE_message
    ;db '[EXISTS]',13,10,0
        jp ret255_in_a
entry_Rename_File_different_drives:
    ;call CORE_message
    ;db '[DIFF]',13,10,0
        jp ret255_in_a

entry_Rename_File_no_source:
    ;call CORE_message
    ;db '[NONE]',13,10,0
        jp ret255_in_a

BDOS_DRV_LOGINVEC:
        m_kr_unimplimented BDOS_DRV_LOGINVEC_string
BDOS_DRV_LOGINVEC_string:
        DB "BDOS_DRV_LOGINVEC", 0
    ;call show_entry_message
	;call CORE_message
	;db 'Ret_Log_Vec',13,10,0
        ld hl, $FFFF ; All drives are always logged in
        ld a, l
        ld b, h
        ret

; Get the currently selected drive number, return it in A, reset B to zero at same time
BDOS_DRV_GET:                                                                   ;EQU 25       $19
        ld      a, (BDOS.current_disk)
        and     %00001111                       ; Make sure it is 0-15
        ld      b, 0
        ret

; Set's a new DMA address (passed in DE) to the pointer address in the BDOS RAM
BDOS_F_DMAOFF:                                                                  ;EQU 26       $1A
        ; Pass in de -> DMA Address
        ld (BDOS.dma_address), de
        jp ret0_in_a

BDOS_DRV_ALLOCVEC:
        ld hl, BDOS.diskalloc
        ld a, l
        ld b, h
        ret

BDOS_DRV_SETRO:
        m_kr_unimplimented BDOS_DRV_SETRO_string
BDOS_DRV_SETRO_string:
        DB "BDOS_DRV_SETRO", 0
        jp ret1_in_a

BDOS_DRV_ROVEC:
        m_kr_unimplimented BDOS_DRV_ROVEC_string
BDOS_DRV_ROVEC_string:
        DB "BDOS_DRV_ROVEC", 0
    ;call show_entry_message
    ;call CORE_message
    ;db 'Get_RO_Vect',13,10,0
        jp ret1_in_a

BDOS_F_ATTRIB:
        m_kr_unimplimented BDOS_F_ATTRIB_string
BDOS_F_ATTRIB_string:
        DB "BDOS_F_ATTRIB", 0
        jp ret1_in_a

BDOS_DRV_DPB:
        m_kr_unimplimented BDOS_DRV_DPB_string
BDOS_DRV_DPB_string:
        DB "BDOS_DRV_DPB", 0
    ; Returns address in HL
;    ld hl, dpblk
;    ld a, l
;    ld b, h
        ret

BDOS_F_USERNUM:                   ;EQU 32       $20
    ; The user to set is passed in E. This is a value from 0 to 15.
    ; If the value is 255 then we are asking for the current user to be returned in a.
        ld      a, e
        cp      255
        jr      z, .get
.set:
        and     %00001111                           ; Make sure it is 0-15
        ld      (BDOS.current_user), a      ; Store new value
        ld      a, (BDOS.current_disk)
        ld      e, a
        
        call    BDOS_DRV_SET                ; Change to the appropriate folder, or real drive
        ret
.get:
        ld a, (BDOS.current_user)
            ; call KERNEL_DEBUG.tm_a_loc0
        ld b, 0
        ret
        
BDOS_F_READRAND:
        m_kr_unimplimented BDOS_F_READRAND_string
BDOS_F_READRAND_string:
        DB "BDOS_F_READRAND", 0
;    push de                                         ; store FCB for now
;    call disk_activity_start
;    call get_random_pointer_from_fcb                ; random is in hl
;    call convert_random_pointer_to_normal_pointer   ; Normal pointer is in bcde
;    pop hl                                          ; hl -> fcb
;    push hl
;    call set_file_pointer_in_fcb                    ; FCB is now up-to-date

;    pop de                                          ; de -> FCB
;    push de
    ; Need to close any existing open file and open the new one.
;    ld a, 1                                         ; Open new file but don't update file pointer
;    call BDOS_F_OPEN.actual
;    pop de
    ; Now jump to the right place in the file
;    call get_block_num_from_fcb                  ; bcde = file pointer
;    call multiply_bcde_by_128                       ; bcde = byte location in file
;    call CORE_move_to_file_pointer                  ; move to that location
;    ld de, (dma_address)
;    call CORE_read_from_file
;    jr nz, entry_Read_Random2                        ; If fail to read, return error code
;    call KERNEL_BDOS.close_file
;    call clear_current_fcb
;    call CORE_disk_off
        jp ret0_in_a                                ; success
entry_Read_Random2:
;    call KERNEL_BDOS.close_file
;    call clear_current_fcb
;    ld a, 4                                         ; "Seek to unwritten extent" error if we try to read
;    ld b, 0                                         ; past the end of the file.
        ret

BDOS_F_WRITERAND:
        m_kr_unimplimented BDOS_F_WRITERAND_string
BDOS_F_WRITERAND_string:
        DB "BDOS_F_WRITERAND", 0
;    push de                                         ; store FCB for now
;    call disk_activity_start
;    call get_random_pointer_from_fcb                ; random is in hl
;    call convert_random_pointer_to_normal_pointer   ; Normal pointer is in bcde
;    pop hl                                          ; hl -> fcb
;    push hl
;    call set_file_pointer_in_fcb                    ; FCB is now up-to-date

;    pop de                                          ; de -> FCB
;    push de
    ; Need to close any existing open file and open the new one.
;    ld a, 1                                     ; Open new file but don't update file pointer
;    call BDOS_F_OPEN.actual
;    pop de
    ; Now jump to the right place in the file
;    call get_block_num_from_fcb              ; bcde = file pointer
;    call multiply_bcde_by_128                   ; bcde = byte location in file
;    call CORE_move_to_file_pointer                   ; move to that location
;    cp USB_INT_SUCCESS
;    jr nz, entry_Write_Random_fail

;    ld de, (dma_address)
;    call CORE_write_to_file
;    call KERNEL_BDOS.close_file                             ; Need to close the file to flush the data out to disk
;    call clear_current_fcb

;    call CORE_disk_off
        jp ret0_in_a                                ; success

entry_Write_Random_fail:
        ; call KERNEL_BDOS.close_file                             ; Need to close the file to flush the data out to disk
        ; call clear_current_fcb
        ; call CORE_disk_off
        ; ld a, 1                                         ; Return error code TODO: 255???
        ; ld b, 0
        ret

convert_random_pointer_to_normal_pointer:
    ; Pass in random pointer in hl
    ; Returns normal pointer in bcde
        ; ex de, hl
        ; ld bc, 0
        ret

; Set the random record count bytes of n FCB, pointed at by DE, to number of 128b records in file.
; Returns A=0 if successful, or 255 if an error occured.
BDOS_F_SIZE:
        push    de                                          ; Stash FCB
        call    KERNEL_BDOS.close_file                      ; just in case there is an open one.
        call    KERNEL_BDOS.copy_fcb_to_buffers             ;  Copy drivepath and drive name out of FCB
        call    KERNEL_BDOS.copy_buffers_to_fullpath        ; Create an ESXDOS access path
        ld      a, '*'                                      ; Not important, filepath overrides it.
        ld      hl, KERNEL_BDOS.current_esxdos.fullpath     ; Full path of file to get stats
        m_kr_esxdos F_OPEN
        jr      c, .not_exist
        push    af                                          ; Preserve file-handle
        ld      hl, KERNEL_BDOS.current_esxdos.stats        ; 11byte stats buffer
        m_kr_esxdos F_FSTAT
        pop     af                                          ; Restore file-handle
        push    bc
        push    de
        m_kr_esxdos F_CLOSE
        pop     de
        pop     bc

        ex      de, hl                                      ; 32-bit filesize now in bchl

        ; Divide by 128
        sla l                                               ; Shift all left by 1 bit
        rl h
        rl c
        rl b

        ld l, h
        ld h, c
        ld c, b
        ld b, 0                                             ; Shift 8 bits right == divide by 128

        pop de                                              ; Get the FCB back
        
        call KERNEL_BDOS.set_random_pointer_in_fcb             ; store hl in FCB random pointer (bc is thrown away!)


        ; m_kr_unimplimented BDOS_F_SIZE_string
        
        jp ret1_in_a
.not_exist:
        pop de
        jr ret255_in_a
BDOS_F_SIZE_string:
        DB "BDOS_F_SIZE", 0

BDOS_F_RANDREC:
        m_kr_unimplimented BDOS_F_RANDREC_string
BDOS_F_RANDREC_string:
        DB "BDOS_F_RANDREC", 0
    ; Set the random record count bytes of the FCB to the number of the last record read/written by the sequential I/O calls.
    ; FCB is in DE
;    push de
;    call get_block_num_from_fcb          ; gets sequential pointer into bcde
;    ex de, hl                               ; Lowest 16 bits of pointer go into hl
;    pop de
;    call CORE_set_random_pointer_in_fcb     ; Store hl into random pointer
        jp ret1_in_a

BDOS_DRV_RESET:
        m_kr_unimplimented BDOS_DRV_RESET_string
BDOS_DRV_RESET_string:
        DB "BDOS_DRV_RESET", 0
;    call clear_current_fcb                          ; Clear out current FCB
        jp ret0_in_a

BDOS_38:
        jp ret1_in_a

BDOS_39:
        jp ret1_in_a

BDOS_F_WRITEZF:
        jp BDOS_F_WRITERAND

BDOS_41:
BDOS_42:
BDOS_43:
BDOS_44:
        ret

BDOS_F_ERRMODE:
        ret

BDOS_46:
BDOS_47:
BDOS_48:
        ret

;-----------------------------------------------------------------------------
;-- Size reducing utility methods - for common >3byte things we do
;-----------------------------------------------------------------------------

restore_fcp_ret0_in_a:
        call BDOS.restore_current_fcb_for_kernel
ret0_in_a:
        xor a                                           ; a = 0
        ld b, a
        ret
    
ret1_in_a:
        ld a, 1
        ld b, 0
        ret
        
ret255_in_a:
        ld a, 255
        ld b, 0
        ret


;-----------------------------------------------------------------------------
;-- BDOS Messages
;-----------------------------------------------------------------------------
msg:
.error_on:
        db 'BDOS Error on ',0

    ENDMODULE
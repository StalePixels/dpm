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
        ld      hl, $00FF                   ; Unimplemented calls return A=L=$FF, B=H=0
        jp      ret255_in_a
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

        ;; Save every NextReg that setup changes, before anything can fail,
        ;; so exit puts back the values NextZXOS had however DP/M ends
        m_NextRegRead_c TILEMAP_BASE_ADR_NR_6E; Read current tilemap base address
        ld      (exit.SMC_tilemap_base_adr), a; Save current address
        m_NextRegRead_c TILEMAP_GFX_ADR_NR_6F ; Read current tile definitions address
        ld      (exit.SMC_tilemap_gfx_adr), a; Save current address
        m_NextRegRead_c GLOBAL_TRANSPARENCY_NR_14; Read current global transparency
        ld      (exit.SMC_global_transparency), a; Save current transparency
        m_NextRegRead_c TRANSPARENCY_FALLBACK_COL_NR_4A; Read current fallback colour
        ld      (exit.SMC_fallback_colour), a; Save current fallback colour
        m_NextRegRead_c TILEMAP_CONTROL_NR_6B; Read tilemap control
        ld      (exit.SMC_tilemap_ctrl), a; Save tilemap control
        m_NextRegRead_c PALETTE_CONTROL_NR_43; Read palette control
        ld      (exit.SMC_palette_ctrl), a; Save palette control
        m_NextRegRead_c PALETTE_INDEX_NR_40 ; Read palette index
        ld      (exit.SMC_palette_index), a; Save palette index
        
        nextreg PALETTE_CONTROL_NR_43, 0x30 ; Tilemap first palette
        nextreg PALETTE_INDEX_NR_40, 0      ; Colour 0, all 9 bits ($41 reads bits 8-1, $44 bit 0)
        m_NextRegRead_c PALETTE_VALUE_NR_41
        ld      (exit.SMC_tilemap_palette_0), a
        m_NextRegRead_c PALETTE_VALUE_9BIT_NR_44
        ld      (exit.SMC_tilemap_palette_0_lsb), a
        nextreg PALETTE_INDEX_NR_40, 1      ; Colour 1, a read does not move the index
        m_NextRegRead_c PALETTE_VALUE_NR_41
        ld      (exit.SMC_tilemap_palette_1), a
        m_NextRegRead_c PALETTE_VALUE_9BIT_NR_44
        ld      (exit.SMC_tilemap_palette_1_lsb), a

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
        ld      (hl), 0                         ; Null terminate the drive folder's path
        call    .ensure_folder                  ; Open it, or make it if it is missing
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
        
        call    .ensure_folder                      ; Open the folder, or make it if it is missing
        ;; Folder found, move to next usernumber, stop when we reach 9
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
        
        call    .ensure_folder                      ; Open the folder, or make it if it is missing
        ;; Folder found, move to next usernumber, stop when we reach 9
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
        ld      (hl), 0                         ; Null terminate the drive folder's path
        call    .ensure_folder                  ; Open it, or make it if it is missing
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
        
        call    .ensure_folder                      ; Open the folder, or make it if it is missing
        ;; Folder found, move to next usernumber, stop when we reach 9
        pop     af                                  ; Get the user number ASCII back
        cp      '9'
        jr      z, .b_tenplus_usernumber
        inc     a                                   ; Move to next usernumber, 0 thru 9
        pop     hl : push hl                        ; Restore end of string cache, and resave it
        jr      .b_test_usernumber
        
.b_tenplus_usernumber
        pop     hl                                  ; Restore end of string pointer
        ld      (hl), '1'
        inc     hl
        push    hl                                 ; Keep new EoString safe, so we can use it again
        ld      a, '0'                              ; First user number, in ASCII
.b_test_tenplus_usernumber
        push    af
        ld      (hl), a                             ; Append to drive string
        inc     hl                                  ; Move pointer
        ld      (hl), 0                             ; Null terminate complete path
        
        add     a, $11
        m_PrintCharInA             ; Print Next drive letter
        
        call    .ensure_folder                      ; Open the folder, or make it if it is missing
        ;; Folder found, move to next usernumber, stop when we reach 9
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

        ;; Open the folder at working_path, and close it again. A missing
        ;; folder is made with F_MKDIR; one that cannot be made goes to
        ;; .config_error, so a missing install folder, whose drive folders
        ;; cannot be made, stops the boot there. Preserves HL, dirties AF
.ensure_folder:
        push    hl
        ld      hl, dynamic_data.working_path       ; Point to start of path
        ld      a, '*'                              ; This doesn't matter, pathspec overrides it
        m_esxdos F_OPENDIR                          ; Call ESXDOS without any wrappers (ROM already mapped)
        jr      c, .make_folder
        m_esxdos F_CLOSE                            ; A = the handle F_OPENDIR returned
        pop     hl
        ret
.make_folder:
        ld      hl, dynamic_data.working_path
        ld      a, '*'                              ; This doesn't matter, pathspec overrides it
        m_esxdos F_MKDIR                            ; Call ESXDOS without any wrappers (ROM already mapped)
        jr      c, .config_error                    ; Resets the stack, so HL need not be popped
        pop     hl
        ret

        ;; A drive folder is missing and cannot be made: DP/M ends and
        ;; NextZXOS shows "Missing folder " and its path as the dot command's error
.config_error:
        ld      hl, @error_report
        ld      de, @DotErr.MissingFolder
        call    strcpy
        ld      de, dynamic_data.working_path
        call    strcpy
        dec     hl                          ; Last character of the path
        set     7, (hl)                     ; marks the end of the message
        ld      hl, @error_report
        jp      @kernel_error_exit          ; Resets the stack
        
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
        ld      (BDOS.entry.SMC_MMU4_userland), a
        ld      (BDOS.cache_calling_fcb.SMC_MMU4_userland), a
        ld      (BDOS.restore_calling_fcb.SMC_MMU4_userland), a
        ld      (BDOS.copy_dma_out_kernel.SMC_MMU4_userland), a
        ld      (BDOS.copy_dma_in_kernel.SMC_MMU4_userland), a
        ld      (BDOS.copy_userland.SMC_MMU4_userland), a
        
        ld      a, (KERNEL.dynamic_data.state.mmu5)         ; Get MMU4(userland5) and patch the following
        ld      (BIOS.entry_BOOTROM.SMC_MMU5_userland), a
        ld      (BIOS.internal_KERNEL_call.SMC_MMU5_userland), a
        ld      (BDOS.entry.SMC_MMU5_userland), a
        ld      (BDOS.cache_calling_fcb.SMC_MMU5_userland), a
        ld      (BDOS.restore_calling_fcb.SMC_MMU5_userland), a
        ld      (BDOS.copy_dma_out_kernel.SMC_MMU5_userland), a
        ld      (BDOS.copy_dma_in_kernel.SMC_MMU5_userland), a
        ld      (BDOS.copy_userland.SMC_MMU5_userland), a
        
        ;ld      a, (KERNEL.dynamic_data.state.mmu6)         ; Get MMU6(userland6) and patch the following
        
        ;ld      a, (KERNEL.dynamic_data.state.mmu7)         ; Get MMU7(userland7) and patch the following
        
        ld      a, (KERNEL.dynamic_data.state.kernel0)      ; Get MMU3(kernel0) and patch the following
        ld      (BIOS.reentry_BOOTROOM.SMC_MMU4_kernel), a
        ld      (BIOS.internal_KERNEL_call.SMC_MMU4_kernel), a
        ld      (BDOS.entry.SMC_MMU4_kernel), a
        ld      (BDOS.cache_calling_fcb.SMC_MMU4_kernel), a
        ld      (BDOS.restore_calling_fcb.SMC_MMU4_kernel), a
        ld      (BDOS.copy_dma_out_kernel.SMC_MMU4_kernel), a
        ld      (BDOS.copy_dma_in_kernel.SMC_MMU4_kernel), a
        ld      (BDOS.copy_userland.SMC_MMU4_kernel), a
        
        ld      a, (KERNEL.dynamic_data.state.kernel1)      ; Get MMU4(kernel1) and patch the following
        ld      (BIOS.reentry_BOOTROOM.SMC_MMU5_kernel), a
        ld      (BIOS.internal_KERNEL_call.SMC_MMU5_kernel), a
        ld      (BDOS.entry.SMC_MMU5_kernel), a
        ld      (BDOS.cache_calling_fcb.SMC_MMU5_kernel), a
        ld      (BDOS.restore_calling_fcb.SMC_MMU5_kernel), a
        ld      (BDOS.copy_dma_out_kernel.SMC_MMU5_kernel), a
        ld      (BDOS.copy_dma_in_kernel.SMC_MMU5_kernel), a
        ld      (BDOS.copy_userland.SMC_MMU5_kernel), a
        
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
        ;;  The values these replace were saved at the start of setup
        nextreg TILEMAP_BASE_ADR_NR_6E, tilemapHiByte; Tilemap base address high byte
        
        nextreg TILEMAP_GFX_ADR_NR_6F, 0x5C ; Tile dataaddress at 0x6C00, ASCII @ 0x5D00
        
        nextreg GLOBAL_TRANSPARENCY_NR_14, 0x00; Confirm that the transparency is E3
        
        nextreg TRANSPARENCY_FALLBACK_COL_NR_4A, 0x00; Set the fallback colour to black
        
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
        call    page_zero_jumps
        xor     a
        ld      (IOBYTE_A), a           ; IOBYTE
        ld      (USERDRIVE_A), a        ; User Number in Top Nybble, Disk in Low Nybble
        
.setup_exit
        ;; Finish the Kernel/ROM handler, return back to DotCommand - which will exit to NextZXOS
        call    enable_esxdos_rom
        
        ;; Restore the stack pointer
        ld      sp, (dynamic_data.dot_stack)
        
        ret                                 ; Return to the DOT command memory
        
;
; Write the page zero jumps: JP to the BIOS warm boot at $0000, JP to the
; BDOS at $0005, whose address at $0006 is the top of the TPA.
;   $C3, BIOS.WBOOTE,  IOBYTE, user/drive,  $C3, BDOS_ENTRY_A
; Userland must be paged in at $0000. Dirties A, HL
page_zero_jumps:
        ld      a, $C3                  ; $C3  == JP instruction
        ld      (REBOOT_A), a           ; BIOS jump
        ld      ($0005), a              ; BDOS jump
        ld      hl, BIOS.WBOOTE         ; BIOS warm boot entry point (not jump table)
        ld      ($0001), hl             ; Undocumented instruction! Copy HL to addr.
        ld      hl, BDOS_ENTRY_A        ; BDOS entry point
        ld      (BDOSPTR_A), hl         ; Undocumented instruction! Copy HL to addr.
        ret

;; Shutdown kernel services, revert hardware to NextZXOS settings
exit:                                    ; DPM exiting - safely shut down the VM changes
.SMC_tilemap_base_adr EQU $+3:
        nextreg TILEMAP_BASE_ADR_NR_6E, 0xAA; Restore tilemap base address using the SMC trick again.
        
.SMC_tilemap_gfx_adr EQU $+3:
        nextreg TILEMAP_GFX_ADR_NR_6F, 0xAA; Restore tile definitions address using the SMC trick again.
        
.SMC_global_transparency EQU $+3:
        nextreg GLOBAL_TRANSPARENCY_NR_14, 0xAA; Restore global transparency.
        
.SMC_fallback_colour EQU $+3:
        nextreg TRANSPARENCY_FALLBACK_COL_NR_4A, 0xAA; Restore fallback colour.
        
.SMC_tilemap_ctrl EQU $+3:
        nextreg TILEMAP_CONTROL_NR_6B, 0xAA; Restore tilemap control
        
        nextreg     PALETTE_CONTROL_NR_43, 0x30; Tilemap primary palette, index moves on after each colour
        nextreg     PALETTE_INDEX_NR_40, 0; First Entry
.SMC_tilemap_palette_0 EQU $+3:
        nextreg     PALETTE_VALUE_9BIT_NR_44, 0xAA  ;     Colour 0, bits 8-1
.SMC_tilemap_palette_0_lsb EQU $+3:
        nextreg     PALETTE_VALUE_9BIT_NR_44, 0xAA  ;     Colour 0, bit 0
.SMC_tilemap_palette_1 EQU $+3:
        nextreg     PALETTE_VALUE_9BIT_NR_44, 0xAA  ;     Colour 1, bits 8-1
.SMC_tilemap_palette_1_lsb EQU $+3:
        nextreg     PALETTE_VALUE_9BIT_NR_44, 0xAA  ;     Colour 1, bit 0
.SMC_palette_ctrl EQU $+3:
        nextreg     PALETTE_CONTROL_NR_43, 0xAA; Restore palette control
.SMC_palette_index EQU $+3:
        nextreg     PALETTE_INDEX_NR_40, 0xAA; Restore palette index
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
        
        call    load_ccp                    ; CCP.COM from the install folder into upper memory
        jr      c, ccp_load_error
        
        call    KERNEL_TERM.init
        xor     a                           ; To make sure there's no pending keys
        ld      (KERNEL.dynamic_data.console_cache), a; We write 0 to the console_cache
        
        ret
        

;
; Read config.install_path + "CCP.COM" into CCP_A, up to the BDOS at BDOS_A.
; A longer file is cut off there. Userland must be paged in.
; Returns carry set if the file cannot be opened or read, or is empty;
; dynamic_data.working_path holds the path. Dirties AF, BC, DE, HL
load_ccp:
        ld      de, config.install_path
        ld      hl, dynamic_data.working_path
        call    strcpy
        ld      de, strings.ccp_name
        call    strcpy                      ; working_path = install path + "CCP.COM"
        ld      hl, dynamic_data.working_path
        ld      b, esx_mode_read + esx_mode_open_exist ; Open read only, if file exists
        ld      a, '*'                      ; This doesn't matter, pathspec overrides it
        m_kr_esxdos F_OPEN
        ret     c                           ; No such file, or it cannot be opened
        push    af                          ; The handle
        ld      hl, CCP_A                   ; Destination
        ld      bc, BDOS_A-CCP_A            ; At most up to the BDOS
        m_kr_esxdos F_READ                  ; BC = bytes read
        jr      c, .close                   ; Read error, carry set
        ld      a, b
        or      c                           ; Clears carry
        jr      nz, .close
        scf                                 ; Empty file
.close:
        pop     bc                          ; B = the handle
        push    af                          ; The result, in carry
        ld      a, b
        m_kr_esxdos F_CLOSE
        pop     af
        ret

;
; CCP.COM could not be loaded, at a cold or a warm boot. DP/M ends and
; NextZXOS shows "Cannot load " and the path as the dot command's error.
ccp_load_error:
        call    enable_esxdos_rom           ; The dot command's RAM at $2000, for the message and exit code
        ld      hl, @error_report
        ld      de, @DotErr.CannotLoad
        call    strcpy
        ld      de, dynamic_data.working_path
        call    strcpy
        dec     hl                          ; Last character of the path
        set     7, (hl)                     ; marks the end of the message
        ld      hl, @error_report
        jp      @kernel_error_exit

;
; Cold boot: put the command line kept from the dot command's arguments in the
; CCP's buffer, its length at CCP_CBUFF_A and its text, ending in 0, at
; CCP_CIBUFF_A, then empty the kept line, so it runs once. With no line the
; CCP is left as it was loaded. Returns the length in A, 0 if there is no
; line. Dirties AF, BC, DE, HL
autocmd_to_ccp:
        ld      a, (dynamic_data.autocmd)
        or      a
        ret     z                           ; No line
        ld      (CCP_CBUFF_A), a
        ld      c, a
        ld      b, 0
        inc     bc                          ; The text and its 0
        ld      hl, dynamic_data.autocmd+1
        ld      de, CCP_CIBUFF_A
        ldir
        ld      hl, dynamic_data.autocmd
        ld      a, (hl)                     ; The length, returned
        ld      (hl), 0                     ; The kept line is now empty
        ret

;
;-----------------------------------------------------------------------------
;-- Kernel entrypoints from BIOS
;-----------------------------------------------------------------------------
BIOS_BOOT:
        jp      KERNEL.BOOTROM

;
; Warm boot: close every open file, reload the CCP, write the page zero jumps
; again and set the DMA address to $0080. IOBYTE ($0003) and the drive and
; user ($0004) stay as they are; the BIOS starts the CCP on that drive and
; user.
BIOS_WBOOT:
        call    KERNEL.BOOTROM              ; Userland is paged in at $0000-$7FFF from here
        call    KERNEL_BDOS.handle_close_all
        call    KERNEL_BDOS.search_close
        call    page_zero_jumps
        ld      hl, TBUFF_A
        ld      (KERNEL_BDOS.dma_address), hl
        ret
        
;
; Returns status in A; 0 if no character is ready, 0FFh if one is.
; A key found here is kept in console_cache until it is taken.
BIOS_CONST:
        ld      a, (KERNEL.dynamic_data.console_cache); Is a key already waiting?
        or      a
        jp      nz, KERNEL.ret255_in_a      ; ...Yes, still ready
        call    KERNEL_KEYBOARD.read_new_key; New keypress, 0 if none
        or      a
        jp      z, KERNEL.ret0_in_a         ; ...None, not ready
        ld      (KERNEL.dynamic_data.console_cache), a; Keep the key for CONIN
        jp      KERNEL.ret255_in_a

;
; Wait until the keyboard is ready to provide a character, and return it in A.
BIOS_CONIN:
        call    console_take_key            ; Waiting or new key, 0 if none
        or      a
        jr      z, BIOS_CONIN               ; ...None, keep waiting
        ret

;
; Takes the next console key without waiting: the one CONST found if there is
; one, else a new keypress. Returns the key in A, or 0 if there is none.
console_take_key:
        ld      a, (KERNEL.dynamic_data.console_cache); Is a key already waiting?
        or      a
        jp      z, KERNEL_KEYBOARD.read_new_key; ...No, scan for a new one
        push    af
        xor     a                           ; ...Yes, take it
        ld      (KERNEL.dynamic_data.console_cache), a
        pop     af
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
; End DP/M: close every open file and the directory search, then leave
; through the dot command's exit path as a normal exit, with no error
; report. Does not return.
BIOS_EXIT:
        call    KERNEL_BDOS.handle_close_all
        call    KERNEL_BDOS.search_close
        call    enable_esxdos_rom           ; The dot command's RAM at $2000, for its exit path
        jp      @kernel_exit


;
;-----------------------------------------------------------------------------
;-- Kernel entrypoints from BDOS
;-----------------------------------------------------------------------------

;
; Called by BDOS.entry once the kernel is paged in. Jumps to the routine for
; function C, with C, DE and A = C as the caller had them. A function number
; past the end of the table returns A=0 and B=0, as the CP/M 2.2 manual gives
; for a number out of range.
bdos_dispatch:
        ld      a, c
        cp      BDOS_FUNCS
        jr      nc, .out_of_range
        push    de
        ld      hl, bdos_table               ; Base entry in jump table
        ld      e, c                         ; Function number into DE
        ld      d, 0                         ;
        add     hl, de                       ; Add it to HL...
        add     hl, de                       ; ...twice - to get right (16bit) address
        ld      e, (hl): inc hl: ld d, (hl)  ; ld de, (hl)
        ex      de, hl                       ; HL now holds address of the BDOS call
        pop     de                           ; & DE the parameters for the call

    IF DPM_DEBUG
            push    af
            ld      a, l : call KERNEL_DEBUG.tm_a_loc76
            ld      a, h : call KERNEL_DEBUG.tm_a_loc78
            pop     af
    ENDIF

        jp      (hl)
.out_of_range:
        xor     a
        ld      b, a
        ret

bdos_table:
        dw BDOS_P_TERMCPM                   ;EQU 0        00
        dw BDOS_C_READ                      ;EQU 1        01
        dw BDOS_C_WRITE                     ;EQU 2        02
        dw BDOS_A_READ                      ;EQU 3        03
        dw BDOS_A_WRITE                     ;EQU 4        04
        dw BDOS_L_WRITE                     ;EQU 5        05
        dw BDOS_C_RAWIO                     ;EQU 6        06
        dw BDOS_IO_GET                      ;EQU 7        07
        dw BDOS_IO_SET                      ;EQU 8        08
        dw BDOS_C_WRITESTR                  ;EQU 9        09
        dw BDOS_C_READSTR                   ;EQU 10       0A
        dw BDOS_C_STAT                      ;EQU 11       0B
        dw BDOS_S_BDOSVER                   ;EQU 12       0C
        dw BDOS_DRV_ALLRESET                ;EQU 13       0D
        dw BDOS_DRV_SET                     ;EQU 14       0E
        dw BDOS_F_OPEN                      ;EQU 15       0F
        dw BDOS_F_CLOSE                     ;EQU 16       10
        dw BDOS_F_SFIRST                    ;EQU 17       11
        dw BDOS_F_SNEXT                     ;EQU 18       12
        dw BDOS_F_DELETE                    ;EQU 19       13
        dw BDOS_F_READ                      ;EQU 20       14
        dw BDOS_F_WRITE                     ;EQU 21       15
        dw BDOS_F_MAKE                      ;EQU 22       16
        dw BDOS_F_RENAME                    ;EQU 23       17
        dw BDOS_DRV_LOGINVEC                ;EQU 24       18
        dw BDOS_DRV_GET                     ;EQU 25       19
        dw BDOS_F_DMAOFF                    ;EQU 26       1A
        dw BDOS_DRV_ALLOCVEC                ;EQU 27       1B
        dw BDOS_DRV_SETRO                   ;EQU 28       1C
        dw BDOS_DRV_ROVEC                   ;EQU 29       1D
        dw BDOS_F_ATTRIB                    ;EQU 30       1E
        dw BDOS_DRV_DPB                     ;EQU 31       1F
        dw BDOS_F_USERNUM                   ;EQU 32       20
        dw BDOS_F_READRAND                  ;EQU 33       21
        dw BDOS_F_WRITERAND                 ;EQU 34       22
        dw BDOS_F_SIZE                      ;EQU 35       23
        dw BDOS_F_RANDREC                   ;EQU 36       24
        dw BDOS_DRV_RESET                   ;EQU 37       25
        dw BDOS_38  ; DRV_ACCESS    MP/M    ;
        dw BDOS_39  ; DRV_FREE      MP/M    ;
        dw BDOS_F_WRITEZF                   ;EQU 40       28
        dw BDOS_41  ; Test and write record ;
        dw BDOS_42  ; F_LOCK        MP/M    ;
        dw BDOS_43  ; F_UNLOCK      MP/M    ;
        dw BDOS_44  ; F_MULTISEC    MP/M2   ;
        dw BDOS_F_ERRMODE                   ; eq 45       2D
        dw BDOS_46  ; DRV_SPACE     MP/M2   ;
        dw BDOS_47  ; P_CHAIN       MP/M2   ;
        dw BDOS_48  ; DRV_FLUSH     MP/M2   ;
BDOS_FUNCS      EQU     ($-bdos_table)/2

; Entered with C=0. Does not return.
BDOS_P_TERMCPM:     ; Function 0
        ; Quit the current program, return to command prompt through the
        ; BIOS warm boot, as a jump to $0000 does.
        jp      BIOS.entry_WBOOT

; Read a key from the keyboard, if none wait until key pressed
; Echo printable characters, CR, LF, TAB and BS to the screen, as CP/M does.
; Entered with C=1. Returns A=character
BDOS_C_READ:        ; Function 1
        call    BIOS_CONIN
        ld      b, 0
        cp      KERNEL_KEYBOARD.DEL         ; Is it the DEL character?
        ret     z                           ; ...Yes, just return
        cp      32                          ; Is it a printable character?
        jr      nc, .echo                   ; ...Yes, print it
        cp      KERNEL_KEYBOARD.CR
        jr      z, .echo
        cp      KERNEL_KEYBOARD.LF
        jr      z, .echo
        cp      KERNEL_KEYBOARD.TAB
        jr      z, .echo
        cp      KERNEL_KEYBOARD.BS
        ret     nz                          ; Other control characters are not echoed
.echo:
        call    KERNEL_TERM.process             ; Print character
        ret
;
; Entered with C=2, E=ASCII character.
BDOS_C_WRITE:       ; Function 2
        ld      a, e
        call    KERNEL_TERM.process
        jp      ret0_in_a

;
; Reader input. DP/M has no reader device: returns ^Z ($1A), the end of a
; text file, at once.
BDOS_A_READ:        ; Function 3
        ld      a, $1A
        ld      b, 0
        ret

;
; Punch output. DP/M has no punch device: the character in E is discarded.
BDOS_A_WRITE:       ; Function 4
        jp      ret0_in_a

; Direct Console IO. E==$FF means read, else write char in E to screen
BDOS_C_RAWIO:
        ld      a, e
        cp      $FF
        jr      nz, .write_console
        call    console_take_key            ; Key, or 0 if none
    IF DPM_DEBUG
        call    KERNEL_DEBUG.tm_a_loc74
    ENDIF
        ld      b, 0
        ret
.write_console
        call    KERNEL_TERM.process
        jp      ret0_in_a
        
        
;
; List output: the character in E goes to the console.
BDOS_L_WRITE:       ; Function 5
        ld      a, e
        jp      BDOS_C_RAWIO.write_console

;
; Returns A = IOBYTE, the byte at $0003.
BDOS_IO_GET:        ; Function 7
        ld      a, (IOBYTE_A)
        ld      b, 0
        ret

;
; Sets IOBYTE, the byte at $0003, to E.
BDOS_IO_SET:        ; Function 8
        ld      a, e
        ld      (IOBYTE_A), a
        jp      ret0_in_a

; Print the string at DE until we see a "$". The string may be anywhere in
; userland, so it is copied into dma_cache a piece at a time and printed from there.
BDOS_C_WRITESTR:
        ex      de, hl                  ; HL = userland string
.next_piece:
        push    hl
        ld      de, BDOS.dma_cache      ; Copy the next piece into the cache
        ld      bc, BDOS.DMA_CACHE_LEN
        call    BDOS.copy_userland
        pop     hl
        ld      de, BDOS.dma_cache
        ld      b, BDOS.DMA_CACHE_LEN
.next_char:
        ld      a, (de)
        cp      '$'
        jp      z, ret0_in_a            ; End of string
        call    KERNEL_TERM.process
        inc     de
        inc     hl
        djnz    .next_char
        jr      .next_piece             ; HL now points at the next piece

;
; Copy BC bytes, 1 or more, from kernel memory at HL to userland at DE, through
; dma_cache a piece at a time. Dirties AF, BC, DE, HL
copy_to_userland:
        push    bc                      ; Bytes left
        ld      a, b
        or      a
        jr      nz, .full_piece
        ld      a, c
        cp      BDOS.DMA_CACHE_LEN+1
        jr      c, .piece               ; The last piece
.full_piece:
        ld      bc, BDOS.DMA_CACHE_LEN
.piece:                                 ; BC = bytes in this piece
        push    bc
        push    de
        ld      de, BDOS.dma_cache
        ldir                            ; Into the cache; HL moves on to the next piece
        pop     de
        pop     bc
        push    bc
        push    hl
        ld      hl, BDOS.dma_cache
        call    BDOS.copy_userland      ; Out to userland; DE moves on to the next piece
        pop     hl
        pop     bc                      ; Bytes in this piece
        ex      (sp), hl                ; HL = bytes left, the next piece's address kept
        or      a
        sbc     hl, bc
        ld      b, h
        ld      c, l
        pop     hl
        ld      a, b
        or      c
        jr      nz, copy_to_userland
        ret

; Read a line of edited console input into the buffer at DE: +0 the maximum
; length (mx), +1 the count read (nc), +2 on the characters. The buffer may be
; anywhere in userland, so the line is built in readstr.line in the kernel and
; copied out when it ends. Input ends on CR or LF, or when mx characters have
; been typed.
;   BS, DEL     rub out the last character
;   ^X          rub out the whole line, and start again
;   ^U          "#", new line, start again
;   ^R          "#", new line, type the line again
;   ^E          new line on screen, input carries on
;   ^C          warm boot, if it is the first character
; ^U and ^R start the new line under the column where the line began.
; Other control characters are ignored.
BDOS_C_READSTR:
        ld      (KERNEL_BDOS.readstr.dest), de
        ex      de, hl                  ; HL = userland buffer
        ld      de, BDOS.dma_cache
        ld      bc, 1
        call    BDOS.copy_userland      ; Fetch mx
        ld      a, (BDOS.dma_cache)
        ld      (KERNEL_BDOS.readstr.max), a
        ld      a, (KERNEL_TERM.state.console_column)
        ld      (KERNEL_BDOS.readstr.column), a ; Column where the line began
.restart:
        xor     a
        ld      (KERNEL_BDOS.readstr.line), a ; No characters yet
.read_to_buffer:
        ld      a, (KERNEL_BDOS.readstr.max)
        ld      hl, KERNEL_BDOS.readstr.line
        cp      (hl)                    ; Buffer full?
        jr      z, .done                ; ...Yes, the line ends
        call    BIOS_CONIN              ; Wait for a key

        cp      KERNEL_KEYBOARD.CR      ; CR or LF ends the line
        jr      z, .done
        cp      KERNEL_KEYBOARD.LF
        jr      z, .done
        cp      KERNEL_KEYBOARD.BS
        jr      z, .backspace
        cp      KERNEL_KEYBOARD.DEL
        jr      z, .backspace
        cp      KERNEL_KEYBOARD.CTR_X
        jr      z, .erase_line
        cp      KERNEL_KEYBOARD.CTR_U
        jr      z, .new_line
        cp      KERNEL_KEYBOARD.CTR_R
        jr      z, .retype
        cp      KERNEL_KEYBOARD.CTR_E
        jp      z, .physical_eol
        cp      KERNEL_KEYBOARD.CTR_C
        jr      z, .reboot_if_start_of_line
        cp      32
        jp      c, .read_to_buffer      ; Other control characters are ignored

        ld      hl, KERNEL_BDOS.readstr.line
        inc     (hl)                    ; Increase the final-chars-count
        ld      e, (hl)
        ld      d, 0
        add     hl, de                  ; HL = place for this char
        ld      (hl), a                 ; Store the char in the buffer
        call    KERNEL_TERM.process     ; Echo it
        jp      .read_to_buffer

.done:
        ld      a, KERNEL_KEYBOARD.CR
        call    KERNEL_TERM.process     ; Return the carriage, as CP/M does
        ld      hl, KERNEL_BDOS.readstr.line ; Copy nc and the characters out
        ld      c, (hl)
        ld      b, 0
        inc     bc
        ld      de, (KERNEL_BDOS.readstr.dest)
        inc     de
        call    copy_to_userland
        ld      a, (KERNEL_BDOS.readstr.line)
        ld      b, 0
        ret

.reboot_if_start_of_line:
        ld      a, (KERNEL_BDOS.readstr.line)
        or      a
        jp      nz, .read_to_buffer     ; ^C later in a line is ignored
        ld      a, '^'
        call    KERNEL_TERM.process
        ld      a, 'C'
        call    KERNEL_TERM.process
        jp      $0000                   ; Warm boot

.backspace:
        ld      hl, KERNEL_BDOS.readstr.line
        ld      a, (hl)                 ; If final-chars is zero we can't go back any more
        or      a
        jp      z, .read_to_buffer
        dec     (hl)                    ; Decrease final-chars-count
        call    .rub_out
        jp      .read_to_buffer

.erase_line:
        ld      a, (KERNEL_BDOS.readstr.line)
        or      a
        jp      z, .restart
        ld      b, a
.erase_char:
        call    .rub_out
        djnz    .erase_char
        jp      .restart

.new_line:
        call    .hash_newline
        jp      .restart

.retype:
        call    .hash_newline
        ld      hl, KERNEL_BDOS.readstr.line
        ld      a, (hl)
        or      a
        jp      z, .read_to_buffer
        ld      b, a
.retype_char:
        inc     hl
        ld      a, (hl)
        call    KERNEL_TERM.process
        djnz    .retype_char
        jp      .read_to_buffer

.physical_eol:
        call    .crlf
        xor     a
        ld      (KERNEL_BDOS.readstr.column), a ; Later new lines start at the margin
        jp      .read_to_buffer

; Backspace, space, backspace: removes the last character from the screen
.rub_out:
        ld      a, KERNEL_KEYBOARD.BS
        call    KERNEL_TERM.process
        ld      a, ' '
        call    KERNEL_TERM.process
        ld      a, KERNEL_KEYBOARD.BS
        jp      KERNEL_TERM.process

; "#", then a new line, spaced out to the column where the line began
.hash_newline:
        ld      a, '#'
        call    KERNEL_TERM.process
        call    .crlf
        ld      a, (KERNEL_BDOS.readstr.column)
        or      a
        ret     z
        ld      b, a
.pad:
        ld      a, ' '
        call    KERNEL_TERM.process
        djnz    .pad
        ret

.crlf:
        ld      a, KERNEL_KEYBOARD.CR
        call    KERNEL_TERM.process
        ld      a, KERNEL_KEYBOARD.LF
        jp      KERNEL_TERM.process
        
;        
; Entered with C=0Bh. Returns A=L=status
BDOS_C_STAT:
        call    BIOS_CONST
        ld      b, 0
        ret

BDOS_S_BDOSVER:
        ld a, $22                   ; This is CP/M v2.2
        ld b, 0
        ret

;
; Reset the disk system: every drive read-write and logged out, then drive A
; selected and the DMA address set to $0080.
BDOS_DRV_ALLRESET:
        ld      hl, 0
        ld      (KERNEL_BDOS.login_vector), hl
        ld      (KERNEL_BDOS.ro_vector), hl
        ld      e, 0
        call    BDOS_DRV_SET                           ; Choose disk A:

        ld      hl, $0080
        ld      (KERNEL_BDOS.dma_address), hl                 ; Set standard DMA location
        
        jp      ret0_in_a

;
; Select the drive in E, 0=A to 15=P.
; Doesn't actually change set the drive letter on NextZXOS, but uses a change and back to detect it.
; A drive that does not exist gives the Select error, which does not return.
BDOS_DRV_SET:
        call    KERNEL_BDOS.handle_close_all        ; If we are changing disks, close any files
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
        ld      a, (KERNEL_BDOS.current_user)
        ld      c, a                                ; User number copied to C.   0 thru 15
        ld      hl, KERNEL_BDOS.current_esxdos.filepath; Destination pointer for path in HL
        call    KERNEL_BDOS.drive_and_user_to_path
        
.done:
        pop     de
        ld      a, e
        ld      (KERNEL_BDOS.current_disk), a              ; Store disk
        call    KERNEL_BDOS.set_login_drive
        
        xor     a                                   ; Wipe A
        ld      b, a                                ; ...and B
        
        ret

;
; No such drive: "BDOS Error on d: Select", a key, then a warm boot, as CP/M
; 2.2 does. $0004 is set back to the current user and disk first, so the
; CCP does not select the missing drive again when it restarts.
.error:
        pop     de
        ld      a, (KERNEL_BDOS.current_user)
        add     a, a
        add     a, a
        add     a, a
        add     a, a                                ; User in the high nibble...
        ld      hl, KERNEL_BDOS.current_disk
        or      (hl)                                ; ...disk in the low
        ld      (USERDRIVE_A), a
        ld      a, e
        ld      hl, msg.select
        jp      bdos_error

;
; Open file referenced by FCB, passed in DE. The file gets a handle in the
; handle table. s1 becomes 0 and s2 $80: module 0, with bit 7 set (file
; unmodified), as CP/M's open does whatever the caller left there. Sets rc
; for the extent the FCB names (ex) from the file size; cr is left alone,
; the caller sets it.
;  Return a = 0 for success, a = 255 for error.
BDOS_F_OPEN:
        call    BDOS.cache_calling_fcb ; Userland call, cache FCB for use in kernel
        xor     a
        ld      (BDOS.fcb_cache.s1), a
        ld      a, $80
        ld      (BDOS.fcb_cache.s2), a
        call    KERNEL_BDOS.handle_open_fcb         ; A = esxdos handle of the file
        jp      c, ret255_in_a                      ; No such file
        ld      hl, KERNEL_BDOS.current_esxdos.stats; 11byte stats buffer
        m_kr_esxdos F_FSTAT
        jp      c, ret255_in_a
        call    KERNEL_BDOS.set_rc_from_size        ; Records in the extent asked for
        jp      restore_fcp_ret0_in_a
        
;
; Close the file the FCB names: its table handle, if it has one, is synced to
; the card and closed. With s2's bit 7 (file unmodified) clear, a file in the
; table is first shortened to the FCB's rc when rc cuts its last extent short
; (KERNEL_BDOS.truncate_to_rc). Returns 0, or 255 if the file does not exist,
; or the shortening or the sync fails.
BDOS_F_CLOSE:
        call    BDOS.cache_calling_fcb              ; Userland call, cache FCB for use in kernel
        call    KERNEL_BDOS.handle_make_key
        push    de
        call    KERNEL_BDOS.handle_find             ; HL = slot, Z if the file is open
        pop     de
        jp      nz, .not_open
        ld      a, (BDOS.fcb_cache.s2)
        rla                                         ; Carry = bit 7, file unmodified
        jr      c, .sync
        push    hl
        call    KERNEL_BDOS.truncate_to_rc
        pop     hl
        jp      c, ret255_in_a
.sync:
        push    hl
        inc     hl
        ld      a, (hl)                             ; HANDLE.esx
        m_kr_esxdos F_SYNC
        pop     hl
        push    af                                  ; Carry set if the sync failed
        call    KERNEL_BDOS.handle_close_slot
        pop     af
        jp      c, ret255_in_a
        jp      ret0_in_a
.not_open:
        call    KERNEL_BDOS.copy_fcb_to_buffers     ; Convert it to ESXDOS paths
        xor     a                                   ; Flag to denote source of filename. 0==buffer
        call    KERNEL_BDOS.copy_buffers_to_fullpath; Join ESXDOS paths together
        ld      a, '*'                              ; Not important, filepath overrides it.
        ld      hl, KERNEL_BDOS.current_esxdos.fullpath
        ld      de, KERNEL_BDOS.current_esxdos.stats; 11byte stats buffer
        m_kr_esxdos F_STAT
        jp      c, ret255_in_a                      ; No such file
        jp      ret0_in_a

;
; Search for the first file that matches the FCB at DE: drive (0 the current
; disk; "?" the current disk and every user number), name with "?" for any
; character, and ex ("?" for every extent). The directory entry goes to the
; DMA address, as entry 0 of a 128 byte directory record; see
; KERNEL_BDOS.search_first for how entries are made from FAT files.
; Returns A=0, or A=255 if no file matches.
BDOS_F_SFIRST:
        call    BDOS.cache_calling_fcb ; Userland call, cache FCB for use in kernel
        call    KERNEL_BDOS.search_first
        jr      BDOS_F_SNEXT.result

;
; Search for the next directory entry that matches the FCB search first was
; given. Files opened or written between the calls do not change the search.
; Returns A=0 with the entry at the DMA address, or A=255 when there are no
; more.
BDOS_F_SNEXT:
        call    KERNEL_BDOS.search_next
.result:
        or      a
        jp      nz, ret255_in_a                     ; Found nothing
        call    BDOS.copy_dma_out_kernel
        jp      ret0_in_a                           ; Something Found!

;
; Delete the files that match DE's FCB (name with "?" for any character; ex
; plays no part). The DMA is left alone. A read-only drive, or a matching
; file that is read-only, gives the R/O error, which does not return.
; Returns 0 for success, 255 if no file matches.
BDOS_F_DELETE:
        call    BDOS.cache_calling_fcb ; Userland call, cache FCB for use in kernel
        call    KERNEL_BDOS.check_drive_writable
        ld      a, 255                              
        ld      (KERNEL_BDOS.current_esxdos.delete_flag), a; Store the result
        
        ld      a, (de)                             ; Put Drive Name into A
        ld      (KERNEL.dynamic_data.store_source), a; And then write it to somewhere safe

.loop:
        ld      a, '?'
        ld      (BDOS.fcb_cache.ex), a              ; One entry for each file
        call    KERNEL_BDOS.search_first            ; The entry in dma_cache, the file in current_esxdos.entry
        push    af
        call    KERNEL_BDOS.search_close            ; Start from scratch each time
        pop     af
        cp      255
        jr      z, .done
        ld      a, (KERNEL_BDOS.current_esxdos.entry); FAT attributes
        and     fat_attr_readonly
        jr      nz, .read_only

        xor     a
        ld      (KERNEL_BDOS.current_esxdos.delete_flag), a; Store a success reult

        ld      a, (KERNEL.dynamic_data.store_source)
        ld      (BDOS.dma_cache), a                 ; The entry, as an FCB on the drive asked for
        ld      de, BDOS.dma_cache
        call    KERNEL_BDOS.handle_close_fcb        ; A file still open is closed before it is deleted
        call    KERNEL_BDOS.copy_fcb_to_buffers     ; Convert it to ESXDOS paths
        ld      a, 0                                ; Flag to denote source of filename. 0==buffer
        call    KERNEL_BDOS.copy_buffers_to_fullpath; Join ESXDOS paths together
        
        ld      a, '*'                              ; Not important, filepath overrides it.
        ld      hl, KERNEL_BDOS.current_esxdos.fullpath; Full path to file to delete
        m_kr_esxdos F_UNLINK
        jr      c, .error
        jr      .loop
.done:
        ld      a, (KERNEL_BDOS.current_esxdos.delete_flag)
        ld      b, 0
        ret
.error:
        jp      ret255_in_a
.read_only:
        call    KERNEL_BDOS.fcb_drive
        jp      error_ro_file
;
; Read the 128 byte record the FCB's position names to the DMA address and
; advance the position. The file's handle comes from the handle table; the
; position comes from the FCB every time. A short last record is padded with
; ^Z. Returns 0, or 1 with the DMA untouched when there is no record there.
BDOS_F_READ:
        call    BDOS.cache_calling_fcb ; Userland call, cache FCB for use in kernel (mutate DE)
        call    KERNEL_BDOS.read_record
        or      a
        jr      nz, .read_fail
        call    advance_position
        jp      restore_fcp_ret0_in_a               ; Success
.read_fail:
        ld      a, 1                                ; 1 = no data at the record
        ld      b, 0
        ret

;
; Move the cached FCB's position on one record.
advance_position:
        ld      de, BDOS.fcb_cache
        call    KERNEL_BDOS.get_block_num_from_fcb  ; BCDE = record number
        call    KERNEL_MATHS.inc_bcde               ; Next record
        ld      hl, BDOS.fcb_cache
        jp      KERNEL_BDOS.set_block_num_in_fcb

;
; Write the 128 byte record at the DMA address to the file at the position the
; FCB names, and advance the position. The file's handle comes from the
; handle table, the one F_READ uses, so one FCB can read and write a file. A
; position past the end of the file first extends it with zeroes. rc becomes
; the number of records the file has in the extent the FCB names after the
; write, and s2's bit 7 (file unmodified) is cleared. A read-only drive or
; file gives the R/O error, which does not return.
; Returns 0, 2 when the disk is full or the write fails, or 255 when the file
; does not exist.
BDOS_F_WRITE:
        call    BDOS.cache_calling_fcb              ; Userland call, cache FCB for use in kernel
        call    KERNEL_BDOS.write_record
        or      a
        jr      nz, write_fail
        call    advance_position
        ; Fall through to finish the write

;
; After a write: clear s2's bit 7 (file unmodified), set rc for the extent
; the FCB names from the file's size, and copy the FCB back to the caller.
write_done:
        ld      hl, BDOS.fcb_cache.s2
        res     7, (hl)                             ; The file is modified
        ld      a, (KERNEL_BDOS.io_handle)
        ld      hl, KERNEL_BDOS.current_esxdos.stats; 11byte stats buffer
        m_kr_esxdos F_FSTAT
        ld      a, 2
        jr      c, write_fail
        call    KERNEL_BDOS.set_rc_from_size        ; Records in the extent the FCB now names
        jp      restore_fcp_ret0_in_a
write_fail:
        ld      b, 0                                ; A = the error
        ret

;
; Create the file the FCB names and leave it open in the handle table. The
; file must not exist: the CP/M 2.2 manual leaves duplicates to the program,
; which deletes the file first, so an existing file is left as it is and the
; call fails. ex, s1, s2, rc, the allocation map d0-d15 and cr are zeroed.
; A read-only drive gives the R/O error, which does not return.
; Returns 0, or 255 if the file exists or cannot be created.
BDOS_F_MAKE:
        call    BDOS.cache_calling_fcb              ; Userland call, cache FCB for use in kernel
        call    KERNEL_BDOS.check_drive_writable
        call    KERNEL_BDOS.handle_create_fcb
        jp      c, ret255_in_a                      ; Exists, or cannot be created
        ld      hl, BDOS.fcb_cache.ex
        ld      b, BDOS.fcb_cache.extra_bytes - BDOS.fcb_cache.ex ; ex through cr
.zero:
        ld      (hl), 0
        inc     hl
        djnz    .zero
        jp      restore_fcp_ret0_in_a

BDOS_F_RENAME:
    ; DE points to a FCB with the
    ; SOURCE filename at FCB+0 and
    ; TARGET filename at FCB+16.
    ; The source's drive byte selects the drive; the target's drive byte is
    ; ignored, and taken as the source's (CP/M 2.2 manual p. 5-25).
    ; The target must not exist, and the source must.
    ; A read-only drive or source file gives the R/O error, which does not
    ; return.
    ; Success a = 0
    ; Error a = 255
        call    BDOS.cache_calling_fcb              ; Userland call, cache FCB for use in kernel
        call    KERNEL_BDOS.check_drive_writable
        ld      hl, BDOS.fcb_cache+1                ; Source name
        call    .mask_name
        ld      hl, BDOS.fcb_cache+17               ; Target name
        call    .mask_name
        ld      a, (de)                             ; Source drive, 0 = current disk
        or      a
        jr      nz, .source_drive
        ld      a, (KERNEL_BDOS.current_disk)              ; Current disk is indexed from 0...
        inc     a                                   ; ...so adjust it to match the FCB
        ld      (de), a
.source_drive:
        ld      (BDOS.fcb_cache+16), a              ; The target is on the source's drive
        call    KERNEL_BDOS.handle_close_fcb        ; Close the source, if it is open
        ld      de, BDOS.fcb_cache+16
        call    KERNEL_BDOS.handle_close_fcb        ; Close the target, if it is open

        call    KERNEL_BDOS.copy_fcb_to_buffers     ; Convert the target to ESXDOS paths
        xor     a                                   ; Flag to denote source of filename. 0==buffer
        call    KERNEL_BDOS.copy_buffers_to_fullpath; Join ESXDOS paths together
        ld      a, '*'                              ; Not important, filepath overrides it.
        ld      hl, KERNEL_BDOS.current_esxdos.fullpath; Full path of the target
        ld      de, KERNEL_BDOS.current_esxdos.stats; 11byte stats buffer
        m_kr_esxdos F_STAT
        jp      nc, ret255_in_a                     ; Target already exists
        ld      de, KERNEL_BDOS.current_esxdos.fullpath
        ld      hl, KERNEL.dynamic_data.working_path
        call    KERNEL.strcpy                       ; Keep the target path, fullpath is needed for the source

        ld      de, BDOS.fcb_cache
        call    KERNEL_BDOS.copy_fcb_to_buffers     ; Convert the source to ESXDOS paths
        xor     a                                   ; Flag to denote source of filename. 0==buffer
        call    KERNEL_BDOS.copy_buffers_to_fullpath; Join ESXDOS paths together
        ld      a, '*'                              ; Not important, filepath overrides it.
        ld      hl, KERNEL_BDOS.current_esxdos.fullpath; Full path of the source
        ld      de, KERNEL_BDOS.current_esxdos.stats; 11byte stats buffer
        m_kr_esxdos F_STAT
        jp      c, ret255_in_a                      ; No source
        ld      a, (KERNEL_BDOS.current_esxdos.stats+2); FAT attributes
        and     fat_attr_readonly
        jr      z, .rename
        call    KERNEL_BDOS.fcb_drive
        jp      error_ro_file
.rename:
        ld      a, '*'                              ; Not important, filepaths override it.
        ld      hl, KERNEL_BDOS.current_esxdos.fullpath; Full path of the source
        ld      de, KERNEL.dynamic_data.working_path; Full path of the target
        m_kr_esxdos F_RENAME
        jp      c, ret255_in_a                      ; No source, or it could not be renamed
        jp      ret0_in_a
;
; Clear the attribute bit (bit 7) of the 8+3 name at HL. Dirties AF, B, HL
.mask_name:
        ld      b, 11
.mask_char:
        ld      a, (hl)
        and     %01111111
        ld      (hl), a
        inc     hl
        djnz    .mask_char
        ret

;
; Returns HL = the login vector: bit 0 for drive A to bit 15 for drive P, set
; for each drive selected, or named in an FCB, since the last reset.
BDOS_DRV_LOGINVEC:                                                              ;EQU 24       $18
        ld      hl, (KERNEL_BDOS.login_vector)
        ld      a, l
        ld      b, h
        ret

; Get the currently selected drive number, return it in A, reset B to zero at same time
BDOS_DRV_GET:                                                                   ;EQU 25       $19
        ld      a, (KERNEL_BDOS.current_disk)
        and     %00001111                       ; Make sure it is 0-15
        ld      b, 0
        ret

; Set's a new DMA address (passed in DE) to the pointer address in the BDOS RAM
BDOS_F_DMAOFF:                                                                  ;EQU 26       $1A
        ; Pass in de -> DMA Address
        ld (KERNEL_BDOS.dma_address), de
        jp ret0_in_a

;
; Returns HL = the allocation vector, the same for every drive: one bit per
; block of the DPB (function 31), with only the directory blocks in use. It
; does not describe the FAT card.
BDOS_DRV_ALLOCVEC:                                                              ;EQU 27       $1B
        ld      hl, BDOS.diskalloc
        ld      a, l
        ld      b, h
        ret

;
; Set the current drive read-only until the next disk reset (function 13,
; which the CCP runs at every warm boot). Writes to it then give the R/O
; error.
BDOS_DRV_SETRO:                                                                 ;EQU 28       $1C
        ld      a, (KERNEL_BDOS.current_disk)
        call    KERNEL_BDOS.drive_bit
        ld      de, (KERNEL_BDOS.ro_vector)
        ld      a, l
        or      e
        ld      l, a
        ld      a, h
        or      d
        ld      h, a
        ld      (KERNEL_BDOS.ro_vector), hl
        jp      ret0_in_a

;
; Returns HL = the read-only vector, bit 0 for drive A to bit 15 for drive P.
BDOS_DRV_ROVEC:                                                                 ;EQU 29       $1D
        ld      hl, (KERNEL_BDOS.ro_vector)
        ld      a, l
        ld      b, h
        ret

;
; Set the attributes of the file the FCB at DE names from the attribute bits
; of its name: t1' read-only, as the FAT read-only attribute; t2' system, as
; the FAT system and hidden attributes. f1'-f4' are not kept. A read-only
; drive gives the R/O error, which does not return.
; Returns 0, or 255 if there is no such file.
BDOS_F_ATTRIB:                                                                  ;EQU 30       $1E
        call    BDOS.cache_calling_fcb
        call    KERNEL_BDOS.check_drive_writable
        call    KERNEL_BDOS.handle_close_fcb        ; It opens again in the mode the new attributes allow
        call    KERNEL_BDOS.copy_fcb_to_buffers
        xor     a                                   ; Flag to denote source of filename. 0==buffer
        call    KERNEL_BDOS.copy_buffers_to_fullpath
        ld      b, esx_attr_write
        ld      a, (BDOS.fcb_cache+9)               ; t1
        and     %10000000
        jr      z, .writable
        ld      b, 0                                ; Read-only
.writable:
        ld      a, (BDOS.fcb_cache+10)              ; t2
        and     %10000000
        jr      z, .not_hidden
        ld      a, b
        or      esx_attr_hidden
        ld      b, a
.not_hidden:
        ld      c, esx_attr_write + esx_attr_hidden ; The attributes to change
        call    .chmod
        jp      c, ret255_in_a                      ; No such file
        ld      b, 0
        ld      a, (BDOS.fcb_cache+10)              ; t2
        and     %10000000
        jr      z, .not_system
        ld      b, esx_attr_system
.not_system:
        ld      c, esx_attr_system                  ; The attribute to change
        call    .chmod
        jp      c, ret255_in_a
        jp      ret0_in_a
;
; esxdos F_CHMOD on the file at fullpath: B = values, C = the attributes to
; change. A change of both hidden and system in one call sets the wrong
; attributes, so they are changed in separate calls.
.chmod:
        ld      a, '*'                              ; Not important, filepath overrides it.
        ld      hl, KERNEL_BDOS.current_esxdos.fullpath
        m_kr_esxdos F_CHMOD
        ret

;
; Returns HL = the disk parameter block, the same for every drive.
BDOS_DRV_DPB:                                                                   ;EQU 31       $1F
        ld      hl, BDOS.dpblk
        ld      a, l
        ld      b, h
        ret

BDOS_F_USERNUM:                   ;EQU 32       $20
    ; The user to set is passed in E. This is a value from 0 to 15.
    ; If the value is 255 then we are asking for the current user to be returned in a.
        ld      a, e
        cp      255
        jr      z, .get
.set:
        and     %00001111                           ; Make sure it is 0-15
        ld      (KERNEL_BDOS.current_user), a      ; Store new value
        ld      a, (KERNEL_BDOS.current_disk)
        ld      e, a
        
        call    BDOS_DRV_SET                ; Change to the appropriate folder, or real drive
        ret
.get:
        ld a, (KERNEL_BDOS.current_user)
            ; call KERNEL_DEBUG.tm_a_loc0
        ld b, 0
        ret
        
;
; Read the record r0, r1 names to the DMA address. cr, ex and s2 are set to
; the record (s2's bit 7 kept) and are not moved on, so a sequential read
; next reads it again; rc is set for its extent.
; Returns 0; 1 when the file has no record there, or 4 when the record's
; extent does not exist either (the DMA is left alone, the position set);
; 6 when r2 is not zero (the FCB is left alone).
BDOS_F_READRAND:                                                                ;EQU 33       $21
        call    BDOS.cache_calling_fcb
        call    KERNEL_BDOS.random_to_position
        jr      nz, random_past_disk
        call    KERNEL_BDOS.read_record             ; A = 0, or 1
        push    af
        ld      de, BDOS.fcb_cache
        call    KERNEL_BDOS.handle_open_fcb         ; The file's handle, if it opens
        jr      c, .result
        ld      hl, KERNEL_BDOS.current_esxdos.stats; 11byte stats buffer
        m_kr_esxdos F_FSTAT
        jr      c, .result
        call    KERNEL_BDOS.set_rc_from_size        ; 0 when the extent has no records
        pop     af
        or      a
        jr      z, .done
        ld      a, (BDOS.fcb_cache.rc)
        or      a
        jr      nz, .unwritten                      ; Records in the extent, not this one
        ld      a, (BDOS.fcb_cache.s2)
        and     %01111111
        ld      b, a
        ld      a, (BDOS.fcb_cache.ex)
        or      b
        jr      z, .unwritten                       ; Extent 0 exists in every file
        ld      a, 4                                ; 4 = seek to unwritten extent
        jr      .done
.result:
        pop     af
        or      a
        jr      z, .done
.unwritten:
        ld      a, 1                                ; 1 = reading unwritten data
.done:
        call    BDOS.restore_calling_fcb
        ld      b, 0
        ret

random_past_disk:
        ld      a, 6                                ; 6 = seek past physical end of disk
        ld      b, 0
        ret

;
; Write the record at the DMA address as the record r0, r1 names. cr, ex
; and s2 are set to the record and are not moved on, so a sequential write
; next writes it again. A record past the end of the file first extends the
; file with zeroes, so function 40, write random with zero fill, is the same
; call. s2's bit 7 is cleared and rc set, as for a sequential write.
; A read-only drive or file gives the R/O error, which does not return.
; Returns 0; 2 when the write fails; 255 when the file does not exist; or 6
; when r2 is not zero (the FCB is left alone).
BDOS_F_WRITERAND:                                                               ;EQU 34       $22
BDOS_F_WRITEZF:                                                                 ;EQU 40       $28
        call    BDOS.cache_calling_fcb
        call    KERNEL_BDOS.random_to_position
        jr      nz, random_past_disk
        call    KERNEL_BDOS.write_record
        or      a
        jp      nz, write_fail
        jp      write_done

;
; Set r0, r1 and r2 of the FCB at DE to the size of the file it names in
; records, a short last record counted whole: the number of the record after
; the last. CP/M's largest file is 65536 records, r2 = 1; a larger FAT file is
; given as that.
; Returns 0, or 255 if there is no such file.
BDOS_F_SIZE:                                                                    ;EQU 35       $23
        call    BDOS.cache_calling_fcb
        call    KERNEL_BDOS.handle_open_fcb         ; A = esxdos handle of the file
        jp      c, ret255_in_a                      ; No such file
        ld      hl, KERNEL_BDOS.current_esxdos.stats; 11byte stats buffer
        m_kr_esxdos F_FSTAT
        jp      c, ret255_in_a
        ld      hl, (KERNEL_BDOS.current_esxdos.stats+7); DE:HL = file size
        ld      de, (KERNEL_BDOS.current_esxdos.stats+9)
        ld      bc, 127                             ; Round up to a whole record
        add     hl, bc
        jr      nc, .rounded
        inc     de
        ld      a, d
        or      e
        jr      z, .largest                         ; Past 4G
.rounded:
        sla     l                                   ; D:E:H = size / 128, carry its bit 24
        rl      h
        rl      e
        rl      d
        jr      c, .largest
        ld      a, d
        or      a
        jr      nz, .largest                        ; 65536 records or more
        ld      a, h
        ld      (BDOS.fcb_cache.r0), a
        ld      a, e
        ld      (BDOS.fcb_cache.r1), a
        xor     a
        ld      (BDOS.fcb_cache.r2), a
        jp      restore_fcp_ret0_in_a
.largest:
        xor     a
        ld      (BDOS.fcb_cache.r0), a
        ld      (BDOS.fcb_cache.r1), a
        inc     a
        ld      (BDOS.fcb_cache.r2), a              ; 65536 records
        jp      restore_fcp_ret0_in_a

;
; Set r0, r1 and r2 of the FCB at DE to the record its cr, ex and s2 name.
; Returns 0.
BDOS_F_RANDREC:                                                                 ;EQU 36       $24
        call    BDOS.cache_calling_fcb
        call    KERNEL_BDOS.get_block_num_from_fcb  ; BCDE = record number
        ld      a, e
        ld      (BDOS.fcb_cache.r0), a
        ld      a, d
        ld      (BDOS.fcb_cache.r1), a
        ld      a, c
        ld      (BDOS.fcb_cache.r2), a
        jp      restore_fcp_ret0_in_a

;
; Reset the drives whose bits are set in DE: their open files are closed,
; and they are logged out and set read-write again. Returns 0.
BDOS_DRV_RESET:                                                                 ;EQU 37       $25
        call    KERNEL_BDOS.handle_close_drives
        ld      a, e
        cpl
        ld      e, a
        ld      a, d
        cpl
        ld      d, a                                ; DE = the drives to keep
        ld      hl, KERNEL_BDOS.login_vector
        call    .keep
        ld      hl, KERNEL_BDOS.ro_vector
        call    .keep
        jp      ret0_in_a
.keep:
        ld      a, (hl)
        and     e
        ld      (hl), a
        inc     hl
        ld      a, (hl)
        and     d
        ld      (hl), a
        ret

;
; MP/M and CP/M 3 functions that CP/M 2.2 does not have. They return A=0,
; HL=0, as CP/M 2.2 does for a function number it does not know.
BDOS_38:            ; DRV_ACCESS    MP/M
BDOS_39:            ; DRV_FREE      MP/M
BDOS_41:            ; Test and write record
BDOS_42:            ; F_LOCK        MP/M
BDOS_43:            ; F_UNLOCK      MP/M
BDOS_44:            ; F_MULTISEC    MP/M2
BDOS_F_ERRMODE:     ; F_ERRMODE     CP/M 3
BDOS_46:            ; DRV_SPACE     MP/M2
BDOS_47:            ; P_CHAIN       MP/M2
BDOS_48:            ; DRV_FLUSH     MP/M2
        jp      ret0_in_a

;
; Report a write to a read-only drive or file as CP/M 2.2 does (manual
; p. 1-45): "BDOS Error on d: R/O", or "BDOS Error on d: File R/O", then wait
; for a key and warm boot. A = the drive (0-15). Does not return.
; bdos_error takes the message after "d:" in HL.
error_ro_drive:
        ld      hl, msg.ro
        jr      bdos_error
error_ro_file:
        ld      hl, msg.file_ro
bdos_error:
        push    hl
        push    af
        ld      a, KERNEL_KEYBOARD.CR
        call    KERNEL_TERM.process
        ld      a, KERNEL_KEYBOARD.LF
        call    KERNEL_TERM.process
        ld      hl, msg.error_on
        call    kr_print_string_hl
        pop     af
        add     a, 'A'
        call    KERNEL_TERM.process
        ld      a, ':'
        call    KERNEL_TERM.process
        pop     hl
        call    kr_print_string_hl
        call    BIOS_CONIN                          ; Any key...
        jp      BIOS.entry_WBOOT                    ; ...then a warm boot

;-----------------------------------------------------------------------------
;-- Size reducing utility methods - for common >3byte things we do
;-----------------------------------------------------------------------------

restore_fcp_ret0_in_a:
        call BDOS.restore_calling_fcb
ret0_in_a:
        xor a                                           ; a = 0
        ld b, a
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
.ro:
        db ' R/O',0
.file_ro:
        db ' File R/O',0
.select:
        db ' Select',0

    ENDMODULE
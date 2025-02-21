;-----------------------------------------------------------------------------
; -- DPM Terminal Display Driver
; 
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FCB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------
    MODULE KERNEL_TERM

process:
        call    map_graphics_mem
        push    hl : push bc : push de : push af; Preserve entry state
        
                push af : ld a, (state.debug_terminal) : cp 0 : jr z, .skip_debug
                pop     af
                ld      hl, tilemapAddr+(31*80)
                push    af              ; Debug routines need to preserve everything
                ld      c, a            ; Copy our debug value to C for later
                rra : rra : rra : rra   ; First nybble now in Least Significant 4 bits
                call    KERNEL_DEBUG.nybble_to_ASCIIhex
                ld      (hl), a             ; Place Higher Nybble Hex onto tilemap at col 40
                ld      a,c                 ; Get original hex value back
                call    KERNEL_DEBUG.nybble_to_ASCIIhex
                inc     hl
                ld      (hl), a             ; Place Higher Nybble Hex onto tilemap at col 41
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
                ; call    KERNEL_DEBUG.pause
.skip_debug
                pop     af

        ld      hl, (state.stage)           ; Load the address of the stage processor
        jp      (hl)                        ; Jump into stage processor
;
clear:
        call    map_graphics_mem
        push    hl : push bc : push de : push af; Preserve entry state
func.clear_all:
        ld      hl, tilemapAddr;            ; Copy From First Entry
        ld      (hl), ' ';                  ; Put a space at the first entry in tilemap
        ld      de, tilemapAddr+1;          ; Copy To Subsequent Entry
        ld      bc, (80*32)-1;              ; Length of Copy
        ldir                                ; ldi repeat. Go. (and fall throught)
        jp      done
;
; Process a byte - maybe it's a non-printing character, passed in A
func.print_char:
        cp      ' '                         ; Is this a printable character
        jr      nc, .print_char             ; ...Yes! Print it.
        cp      KERNEL_KEYBOARD.ESC         ; Is this an ESC character?
        jp      z, set.escape             ; ...Yes! Start to escape handler mode
        cp      KERNEL_KEYBOARD.BS                              ; $08
        jr      z, .BS
        cp      KERNEL_KEYBOARD.LF                              ; $0A
        jr      z, .LF
        cp      KERNEL_KEYBOARD.CR                              ; $0D
        jr      z, .CR
        ; ...etc!
        jp      done
.BS:
        ld      a, (state.console_column)
        cp      0
        jr      nz, .do_backspace
        ld      a, (state.console_row)
        cp      0
        jr      nz, .do_backspace_wraparound
        jp      done
.do_backspace_wraparound:
        dec     a
        ld      (state.console_row), a
        ld      a, 80
.do_backspace:
        dec     a
        ld      (state.console_column), a
        call    calculate_console_pointer

        ld      hl, (state.console_pointer)
        ld      (hl), ' '
        jp      done
.LF:
        ld      a, (state.console_row)
        inc     a
        jr      .check_scroll
.CR:
        ld      a, 0
        ld      (state.console_column), a
        jr      .update_console_pointer
.print_char:
;         cp      128
;         jr      c, .ASCII
;         ld      a, '#'
; .ASCII
        ld      hl, (state.console_pointer)
        ld      (hl), a
        ld      a, (state.console_column)
        inc     a
        ld      d, 80
        cp      d                           ; Compare A (column) to d (80)
        jp      z, .wraparound              ; True == wraparound
        ld      (state.console_column), a
        jr      .update_console_pointer
.wraparound:
        ld      a, 0
        ld      (state.console_column), a
        ld      a, (state.console_row)
        inc     a
.check_scroll:
        cp      24
        jp      z, .scroll             ; Z == Same, so scroll display
        ld      (state.console_row), a
        jr      .update_console_pointer
.scroll:                                    ; Scroll the exiting text upwards
        ld      a, 23
        ld      (state.console_row), a
        call    screen_scroll;
.update_console_pointer:
        call    calculate_console_pointer
        jp      done
;
mode:                                ; MODE functions are used to handle what happens in a single state
.escape:                                ; ESCape starts a control code, what next: ESC ...?
        cp      '['                         ; Is this the second part of the init sequence?
        jp      z, set.csi                  ; ...Yes! Is a CSI command
        jr      set.ground                  ; Nope - end escape sequence
.csi:                                   ; Control Sequence Introducer - params or command follow: [ ...?
                                    ; There should probably be an "Intermediate byte" (20 to 2f) check here too
        cp      30                          ; Is A a parameter? (between 30 and 3f) 
        jp      c, set.ground               ; ...Below 30, revert to printing ("GROUND")
        cp      ';'                         ; Is A=3B
        jp      z, set.next_param           ; ...Yes, move to next parameter
        cp      $3f                         ; Test for 3F?
        jp      z, set.vt220                ; ==3F, aka ?  (these are VT220 specific codes, I think)
        jp      nc, csi_complete            ; ...Yes, Do the CSI command
                                            ; ...No, so is a parameter
        ld      hl, (state.current_param_pointer);Get the current parameter pointer
        ld      e, (hl)                     ; Get the value of the current paremeter
        ld      d, 10                       ; We need to move increase it one place, base 10
        mul     d, e                        ; Yay! Z80n, we have a MUL instruction, so that was easy
        sub     '0'                         ; Now turn A from ASCII to a real value
        add     a, e                        ; And add the previous value (which we x10'ed)
        ld      (hl), a                     ; Save the parameter value
        jr      done
.vt220:                                    ; There should probably be an "Intermediate byte" (20 to 2f) check here too
        cp      30                          ; Is A a parameter? (between 30 and 3f) 
        jp      c, set.ground               ; ...Below 30, revert to printing ("GROUND")
        cp      ';'                         ; Isa A=3B
        jp      z, set.next_param           ; ...Yes, move to next parameter
        jp      nc, vt220_complete          ; ...Yes, Do the CSI command
                                            ; ...No, so is a parameter
        ld      hl, (state.current_param_pointer);Get the current parameter pointer
        ld      e, (hl)                     ; Get the value of the current paremeter
        ld      d, 10                       ; We need to move increase it one place, base 10
        mul     d, e                        ; Yay! Z80n, we have a MUL instruction, so that was easy
        sub     '0'                         ; Now turn A from ASCII to a real value
        add     a, e                        ; And add the previous value (which we x10'ed)
        ld      (hl), a                     ; Save the parameter value
        jr      done
;
set:                                ; SET functions are used to transition between states within the machine
.ground:                                ; ... Ground is the "normal" printing state, no ESC seq started
        call    reset                   ; Set state to print_char, params all == 0
        jr      done
.escape:                                ; Starting ESCape sequence
        ld      hl, mode.escape
                ld a, 1 : ld (state.debug_terminal), a
        jr      savestage
.csi:                                   ; Starting Control Sequence Introducer, e.g. ESC[nn;nnX - n=num
        ld      hl, mode.csi
        jr      savestage
.vt220:
        ld      hl, mode.vt220
        jr      savestage
.next_param:
        ld      hl, (state.current_param_pointer);Get current parameter pointer value
        inc     hl                      ; Increment parameter address by one
        ld      (state.current_param_pointer), hl;Save the new pointer value
        jr      done
;
savestage:
        ld      (state.stage), hl
        ;; Fall through to DONE, as we're complete now
;
done:                               ; Exit terminal routine, balancing stack as we go...
        call    unmap_graphics_mem
        pop     af : pop     de : pop     bc : pop     hl
        ret
;
csi_complete:
        cp      'H'
        jr      z, func.H_movecursor
        cp      'J'
        jr      z, func.J_clear
        jp      set.ground
;
func.J_clear
        ld      a, (state.param1)
        push    af
        call    reset
        pop     af
        cp      0
        jp      z, func.clear_all
        cp      1
        jr      z, $
        cp      2
        jp      z, func.clear_all
        jp      set.ground
func.H_movecursor
        ld      a, (state.param1)
        ld      (state.console_row), a
                call KERNEL_DEBUG.tm_a_loc4
        ld      a, (state.param2)
        ld      (state.console_column), a
                call KERNEL_DEBUG.tm_a_loc8
        call    calculate_console_pointer
        jp      set.ground
        
vt220_complete:
        ; cp      'l'
        ; jr      z, func.H_movecursor
        ; cp      'J'
        ; jr      z, func.J_clear
        jp      set.ground
;
; Calculate the memory address for writing to the console based on current Row/Col.
;     Dirties HL, DE
calculate_console_pointer: 
        ld      d, 0
        ld      hl, state.console_column
        ld      e, (hl)
        ld      hl, tilemapAddr
        add     hl, de
        push    hl                          ; Stash HL while we use it to load row
        ld      d, 80
        ld      hl, state.console_row
        ld      e, (hl)
        mul     d, e                        ; Z80N fast 8bit multiply
        pop     hl                          ; Get back old sum
        add     hl, de                      ; and add result of MUL
        ld      (state.console_pointer), hl
        ret


;
; Scroll screen up one line
;     Dirties HL, DE, and BC
screen_scroll:
        ; Scroll rows 1->23, over 0->22
        ld      hl, tilemapAddr+80          ; Copy From
        ld      de, tilemapAddr             ; Copy To
        ld      bc, 23*80                   ; Length of Copy
        ldir                                ; ldi repeat. Go.  (and fall throught)
        
        ; Blank row 23
        ld      hl, tilemapAddr+(23*80)
        ld      (hl), ' '
        ld      de, tilemapAddr+(23*80)+1   ; Copy To
        ld      bc, 79                      ; Length of Copy
        ldir                                ; ldi repeat. Go.  (and fall throught)
        ret
        
map_graphics_mem:
        nextreg	MMU2_4000_NR_52, 0x0A
        nextreg	MMU3_6000_NR_53, 0x0B
        ret
        
unmap_graphics_mem:
.SMC_MMU2 EQU $+3:
        nextreg	MMU2_4000_NR_52, 0xAA
.SMC_MMU3 EQU $+3:
        nextreg	MMU3_6000_NR_53, 0xAA
        ret

init:                               ; Called INIT externally
reset:                              ; resets the ANSI processor
        ld      hl, func.print_char     ; Get address of the default terminal stage
        ld      (state.stage), hl       ; And set the stage pointer to it
        ld      a, 0
        ld      (state.param1), a       ; Wipe the parameters
        ld      (state.param2), a       ; Although we only actually support 2
        ld      (state.param3), a       ; We've build some scope for unsupported
        ld      (state.param4), a       ; Parameters here, upto 4.
                ld      (state.debug_terminal), a
        ld      hl, state.param1        ; Which param are we working on?
        ld      (state.current_param_pointer), hl

        ret
        
;-----------------------------------------------------------------------------
; Terminal Emulator State
;-----------------------------------------------------------------------------
state:
.console_column
        DB  0
.console_row
        DB  0
.console_pointer
        DW  tilemapAddr
.stage:
        DW  func.print_char
.param1:
        DB  0
.param2:
        DB  0
.param3:
        DB  0
.param4:
        DB  0
.current_param_pointer:
        DW  0
.debug_terminal
        DB  0
    ENDMODULE
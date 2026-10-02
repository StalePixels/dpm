;-----------------------------------------------------------------------------
; -- DPM Terminal Display Driver
;
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FCB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
; The console is rows 0-23 of the 80x32 tilemap. It understands:
;   BS              cursor left (wraps to the end of the row above)
;   TAB             cursor to the next multiple of 8, stopping at column 79
;   LF              cursor down, scrolling at the bottom
;   FF              clear the screen and home the cursor
;   CR              cursor to column 0
;   VT52:   ESC A / B / C / D   cursor up / down / right / left, stopping at the edges
;           ESC H               cursor home
;           ESC J / ESC K       clear to end of screen / to end of line
;           ESC Y row col       cursor to row-32, col-32
;           ESC I               cursor up, scrolling down at the top
;           ESC E               clear the screen and home the cursor (Heathkit)
;   ANSI:   ESC [ row ; col H   cursor to row, col (1-based)
;           ESC [ n J           clear to end of screen (0), from start (1), all (2)
; Other control codes, and escape sequences it does not know, show nothing.
;
; The cursor is the tile cursorTile drawn over the cell at console_pointer,
; showing that cell's character in inverse. Every entry point takes it off the
; screen before it changes anything, and done puts it back.
;-----------------------------------------------------------------------------
    MODULE KERNEL_TERM

process:
        call    map_graphics_mem
        push    hl : push bc : push de : push af; Preserve entry state
        call    cursor_hide
    IF DPM_DEBUG
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
    ENDIF

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
        jp      set.ground
;
; Clear the whole screen and home the cursor
func.clear_home:
        xor     a
        ld      (state.console_row), a
        ld      (state.console_column), a
        ld      hl, tilemapAddr
        ld      (state.console_pointer), hl
        jr      func.clear_all
;
; Process a byte - maybe it's a non-printing character, passed in A
func.print_char:
        cp      ' '                         ; Is this a printable character
        jr      nc, .print_char             ; ...Yes! Print it.
        cp      KERNEL_KEYBOARD.ESC         ; Is this an ESC character?
        jp      z, set.escape             ; ...Yes! Start to escape handler mode
        cp      KERNEL_KEYBOARD.BS                              ; $08
        jr      z, .BS
        cp      KERNEL_KEYBOARD.TAB                             ; $09
        jr      z, .TAB
        cp      KERNEL_KEYBOARD.LF                              ; $0A
        jr      z, .LF
        cp      KERNEL_KEYBOARD.FF                              ; $0C
        jr      z, func.clear_home
        cp      KERNEL_KEYBOARD.CR                              ; $0D
        jr      z, .CR
        jp      done                        ; BEL and the rest: nothing shown
.BS:                                        ; Moves left, does not erase
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
        jr      .update_console_pointer
.TAB:
        ld      a, (state.console_column)
        or      7
        inc     a                           ; Next multiple of 8
        cp      80
        jr      c, .tab_column
        ld      a, 79                       ; ...past the last column, stop there
.tab_column:
        ld      (state.console_column), a
        jr      .update_console_pointer
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
        cp      'Y'                         ; VT52 direct cursor address, row and column follow
        jp      z, set.esc_y
        cp      'A'
        jp      z, func.cursor_up
        cp      'B'
        jp      z, func.cursor_down
        cp      'C'
        jp      z, func.cursor_right
        cp      'D'
        jp      z, func.cursor_left
        cp      'H'
        jp      z, func.cursor_home
        cp      'J'
        jp      z, func.clear_to_end
        cp      'K'
        jp      z, func.clear_line
        cp      'I'
        jp      z, func.reverse_lf
        cp      'E'
        jp      z, func.clear_home
        jp      set.ground                  ; Not known: the sequence ends, nothing shown
.esc_y_row:                             ; ESC Y: the row byte, offset by 32
        sub     32
        ld      (state.param1), a           ; Out of range rows are dropped when the column comes
        ld      hl, mode.esc_y_col
        jp      savestage
.esc_y_col:                             ; ESC Y row: the column byte, offset by 32
        sub     32
        cp      80
        jr      c, .esc_y_column
        ld      a, 79                       ; Past the right edge: the last column
.esc_y_column:
        ld      (state.console_column), a
        ld      a, (state.param1)
        cp      24
        jp      nc, func.move_done          ; Row off the screen: the row does not change
        ld      (state.console_row), a
        jr      func.move_done
.csi:                                   ; Control Sequence Introducer - params or command follow: [ ...?
                                    ; There should probably be an "Intermediate byte" (20 to 2f) check here too
        cp      '0'                         ; Is A a parameter? (between 30 and 3f)
        jp      c, set.ground               ; ...Below 30, revert to printing ("GROUND")
        cp      ';'                         ; Is A=3B
        jp      z, set.next_param           ; ...Yes, move to next parameter
        cp      $3f                         ; Test for 3F?
        jp      z, set.vt220                ; ==3F, aka ?  (these are VT220 specific codes, I think)
        jp      nc, csi_complete            ; ...Yes, Do the CSI command
        cp      ':'                         ; $3A-$3E are not digits
        jp      nc, done                    ; ...ignore them
                                            ; ...No, so is a parameter
        ld      hl, (state.current_param_pointer);Get the current parameter pointer
        ld      e, (hl)                     ; Get the value of the current paremeter
        ld      d, 10                       ; We need to move increase it one place, base 10
        mul     d, e                        ; Yay! Z80n, we have a MUL instruction, so that was easy
        sub     '0'                         ; Now turn A from ASCII to a real value
        add     a, e                        ; And add the previous value (which we x10'ed)
        ld      (hl), a                     ; Save the parameter value
        jp      done
.vt220:                                    ; There should probably be an "Intermediate byte" (20 to 2f) check here too
        cp      '0'                         ; Is A a parameter? (between 30 and 3f)
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
        jp      done
;
; VT52 cursor movement. Each stops at the edge of the console.
func.cursor_up:
        ld      a, (state.console_row)
        or      a
        jr      z, func.move_done
        dec     a
        ld      (state.console_row), a
        jr      func.move_done
func.cursor_down:
        ld      a, (state.console_row)
        cp      23
        jr      nc, func.move_done
        inc     a
        ld      (state.console_row), a
        jr      func.move_done
func.cursor_right:
        ld      a, (state.console_column)
        cp      79
        jr      nc, func.move_done
        inc     a
        ld      (state.console_column), a
        jr      func.move_done
func.cursor_left:
        ld      a, (state.console_column)
        or      a
        jr      z, func.move_done
        dec     a
        ld      (state.console_column), a
        jr      func.move_done
func.cursor_home:
        xor     a
        ld      (state.console_row), a
        ld      (state.console_column), a
func.move_done:                             ; Row and column are set: point at the cell, end the sequence
        call    calculate_console_pointer
        jp      set.ground
;
; Cursor up one row; at the top row, scroll the console down instead
func.reverse_lf:
        ld      a, (state.console_row)
        or      a
        jr      z, .scroll_down
        dec     a
        ld      (state.console_row), a
        jr      func.move_done
.scroll_down:
        call    screen_scroll_down
        jp      set.ground
;
; Clear from the cursor to the end of the console, cursor cell included
func.clear_to_end:
        ld      hl, tilemapAddr+(24*80)
        ld      de, (state.console_pointer)
        or      a
        sbc     hl, de                      ; Cells from the cursor to the end
        ld      b, h
        ld      c, l
        ex      de, hl
        call    fill_spaces
        jp      set.ground
;
; Clear from the cursor to the end of its row, cursor cell included
func.clear_line:
        ld      a, (state.console_column)
        neg
        add     a, 80                       ; Cells from the cursor to the end of the row
        ld      b, 0
        ld      c, a
        ld      hl, (state.console_pointer)
        call    fill_spaces
        jp      set.ground
;
; Clear from the start of the console to the cursor, cursor cell included
func.clear_to_cursor:
        ld      hl, (state.console_pointer)
        ld      de, tilemapAddr-1
        or      a
        sbc     hl, de                      ; Cells from the start to the cursor
        ld      b, h
        ld      c, l
        ld      hl, tilemapAddr
        call    fill_spaces
        jp      set.ground
;
set:                                ; SET functions are used to transition between states within the machine
.ground:                                ; ... Ground is the "normal" printing state, no ESC seq started
        call    reset                   ; Set state to print_char, params all == 0
        jr      done
.escape:                                ; Starting ESCape sequence
        ld      hl, mode.escape
    IF DPM_DEBUG
                ld a, 1 : ld (state.debug_terminal), a
    ENDIF
        jr      savestage
.csi:                                   ; Starting Control Sequence Introducer, e.g. ESC[nn;nnX - n=num
        ld      hl, mode.csi
        jr      savestage
.vt220:
        ld      hl, mode.vt220
        jr      savestage
.esc_y:                                 ; Starting VT52 ESC Y row col
        ld      hl, mode.esc_y_row
        jr      savestage
.next_param:
        ld      hl, (state.current_param_pointer);Get current parameter pointer value
        ld      de, state.param4
        or      a
        sbc     hl, de                  ; Already on the last parameter?
        jr      nc, done                ; ...Yes, later parameters add to it
        add     hl, de
        inc     hl                      ; Increment parameter address by one
        ld      (state.current_param_pointer), hl;Save the new pointer value
        jr      done
;
savestage:
        ld      (state.stage), hl
        ;; Fall through to DONE, as we're complete now
;
done:                               ; Exit terminal routine, balancing stack as we go...
        call    cursor_show
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
        cp      0
        jp      z, func.clear_to_end
        cp      1
        jp      z, func.clear_to_cursor
        cp      2
        jp      z, func.clear_all
        jp      set.ground
;
; ESC [ row ; col H - 1-based, 0 or no parameter is 1, past the edge is the edge
func.H_movecursor
        ld      a, (state.param1)
    IF DPM_DEBUG
                call KERNEL_DEBUG.tm_a_loc4
    ENDIF
        call    .one_based
        cp      24
        jr      c, .row
        ld      a, 23
.row:
        ld      (state.console_row), a
        ld      a, (state.param2)
    IF DPM_DEBUG
                call KERNEL_DEBUG.tm_a_loc8
                call map_graphics_mem       ; The tracer above pages the screen out
    ENDIF
        call    .one_based
        cp      80
        jr      c, .column
        ld      a, 79
.column:
        ld      (state.console_column), a
        jp      func.move_done
.one_based:
        or      a
        ret     z
        dec     a
        ret

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
; Take the cursor off the screen: put back the character it covers.
;     Dirties HL
cursor_hide:
        push    af
        ld      hl, (state.console_pointer)
        ld      a, (hl)
        cp      cursorTile                  ; Is the cursor drawn here?
        jr      nz, .done                   ; ...No, nothing to put back
        ld      a, (cursorCharAddr)
        ld      (hl), a
.done:
        pop     af
        ret

;
; Draw the cursor at console_pointer: keep the character there in
; cursorCharAddr, make cursorTile that character in inverse, and put
; cursorTile in the cell.
;     Dirties AF, HL, DE, B
cursor_show:
        ld      hl, (state.console_pointer)
        ld      a, (hl)                     ; Character under the cursor
        cp      cursorTile
        ret     z                           ; Cursor already drawn
        ld      (cursorCharAddr), a
        ld      (hl), cursorTile
        ld      hl, state.cursor_glyph      ; Character cursorTile shows now
        cp      (hl)
        ret     z                           ; ...the same one, the tile is ready
        ld      (hl), a
        ld      h, 0
        ld      l, a
        add     hl, hl
        add     hl, hl
        add     hl, hl                      ; 8 bytes per tile
        ld      de, tileGfxAddr
        add     hl, de                      ; HL = the character's tile
        ld      de, tileGfxAddr+(cursorTile*8)
        ld      b, 8
.invert:
        ld      a, (hl)
        cpl
        ld      (de), a
        inc     hl
        inc     de
        djnz    .invert
        ret

;
; Fill BC cells (at least 1) from HL with spaces
;     Dirties HL, DE, BC
fill_spaces:
        ld      (hl), ' '
        dec     bc
        ld      a, b
        or      c
        ret     z
        ld      d, h
        ld      e, l
        inc     de
        ldir
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

;
; Scroll screen down one line
;     Dirties HL, DE, and BC
screen_scroll_down:
        ; Scroll rows 0->22, over 1->23, copying from the end backwards
        ld      hl, tilemapAddr+(23*80)-1   ; Copy From
        ld      de, tilemapAddr+(24*80)-1   ; Copy To
        ld      bc, 23*80                   ; Length of Copy
        lddr

        ; Blank row 0
        ld      hl, tilemapAddr
        ld      bc, 80
        jr      fill_spaces

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
        ld      a, cursorTile
        ld      (state.cursor_glyph), a ; Build the cursor tile again on the next draw
reset:                              ; resets the ANSI processor
        ld      hl, func.print_char     ; Get address of the default terminal stage
        ld      (state.stage), hl       ; And set the stage pointer to it
        ld      a, 0
        ld      (state.param1), a       ; Wipe the parameters
        ld      (state.param2), a       ; Although we only actually support 2
        ld      (state.param3), a       ; We've build some scope for unsupported
        ld      (state.param4), a       ; Parameters here, upto 4.
    IF DPM_DEBUG
                ld      (state.debug_terminal), a
    ENDIF
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
.cursor_glyph                       ; Character cursorTile was last built from
        DB  cursorTile
    ENDMODULE

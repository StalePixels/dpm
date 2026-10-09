;-----------------------------------------------------------------------------
; -- DPM Terminal Display Driver
;
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FCB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
; A VT100 terminal (DEC VT100 User Guide, chapter 3), with the ECMA-48 SGR
; colours. The console is consoleRows rows of the 80x32 tilemap, from display
; row consoleTop (addresses.asm). Rows and columns count from 1 in sequences.
; It understands:
;   BS HT LF CR     as a VT100; BS stops at column 1, HT stops at column 80
;   VT FF           as LF; LF, VT and FF also return the carriage in LNM
;   SO SI           G1 / G0 in use
;   CAN SUB         end the sequence, nothing shown
;   ESC D / M / E   IND, RI, NEL: down, up, next line, scrolling the region
;   ESC H           HTS, tab stop at the cursor
;   ESC 7 / 8       DECSC, DECRC: cursor, rendition, character sets, origin mode
;   ESC c           RIS, back to the start state, console cleared
;   ESC # 8         DECALN, the console filled with "E"
;   ESC ( / ) x     G0 / G1 is x: B ASCII, A UK (# is a pound sign), 0 line
;                   drawing (codes $5F-$7E as CP437 glyphs, graphics_set)
;   ESC [ n A/B/C/D CUU, CUD, CUF, CUB; up and down stop at the margins
;   ESC [ r;c H / f CUP, HVP; relative to the margins in origin mode
;   ESC [ n J / K   ED, EL: 0 cursor to end, 1 start to cursor, 2 all
;   ESC [ ... m     SGR: 0 off, 1 bold, 22 not bold, 7 reverse, 27 not
;                   reverse, 30-37 ink, 39 default ink, 40-47 paper, 49
;                   default paper; 4, 5 and others show nothing
;   ESC [ t;b r     DECSTBM, the scroll region
;   ESC [ n g       TBC: 0 the tab stop at the cursor, 3 all of them
;   ESC [ ... h / l SM, RM: 20 LNM
;   ESC [ ? ... h/l DECSET, DECRST: 1 DECCKM (the cursor keys send ESC O x),
;                   5 DECSCNM, 6 DECOM, 7 DECAWM
;   ESC [ 5 n       DSR: the reply ESC [ 0 n
;   ESC [ 6 n       DSR: the reply ESC [ r;c R, the cursor, relative to the
;                   margins in origin mode
;   ESC [ c / 0 c   DA: the reply ESC [ ? 1 ; 0 c, a VT100 with no options
; Replies go in the console input queue (KERNEL.console_push), where the
; program reads them as keys.
; Other control codes, and sequences it does not know, show nothing. DECAWM is on at the start. A character in
; the last column leaves the cursor there with a wrap pending; the next
; character goes to the start of the next line, and a cursor move clears it.
;
; Each cell is two bytes, the character and its attribute (addresses.asm).
; A printed character gets state.attribute, made from the rendition when SGR
; ends. Cells that an erase, a scroll or a clear empties get a space with
; state.erase_attr: the same ink and paper, reverse off. DECSCNM swaps the
; ink and paper of all 128 palette pairs.
;
; The 32 map rows are a ring. NextReg $31 shows map row state.scroll_row at
; display row 0, and display row d is map row (scroll_row + d) mod 32. A
; scroll of the whole console moves scroll_row by one and clears one row; a
; scroll region smaller than the console copies its rows. Display rows 0 and
; 31, outside the console, stay blank in the default attribute.
;
; The parser is a state machine: state.stage is the routine for the next
; byte. In ground it is state.ground, the routine for the character set in
; use, or ground.wrap while a wrap is pending, so a printable byte takes one
; test before it goes into the map.
;
; The cursor is the reverse bit of the attribute of the cell at
; console_pointer, flipped, so the cell shows inverted. Every entry point
; takes it off the screen before it changes anything, and done puts it back.
; While interrupts are on, the frame interrupt flips the bit every
; BLINK.frames frames (BDOS.asm), so the cursor blinks.
;-----------------------------------------------------------------------------
    MODULE KERNEL_TERM

process:
        call    map_graphics_mem
        push    hl : push bc : push de : push af; Preserve entry state
        call    cursor_hide
    IF DPM_DEBUG
                push af : ld a, (state.debug_terminal) : cp 0 : jr z, .skip_debug
                ld      a, 31
                call    display_row_addr    ; Display row 31
                pop     af
                push    af              ; Debug routines need to preserve everything
                ld      c, a            ; Copy our debug value to C for later
                rra : rra : rra : rra   ; First nybble now in Least Significant 4 bits
                call    KERNEL_DEBUG.nybble_to_ASCIIhex
                ld      (hl), a             ; Place Higher Nybble Hex onto tilemap at col 0
                inc     hl
                ld      (hl), defaultAttr
                ld      a,c                 ; Get original hex value back
                call    KERNEL_DEBUG.nybble_to_ASCIIhex
                inc     hl
                ld      (hl), a             ; Place Lower Nybble Hex onto tilemap at col 1
                inc     hl
                ld      (hl), defaultAttr
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
        xor     a
        ld      (state.cursor_shown), a     ; The cells are all new: no cursor on them
        ld      (state.scroll_row), a       ; Map row 0 at display row 0
        call    set_scroll
        ld      hl, tilemapAddr
        ld      bc, 80*32
        ld      a, (state.default_attr)
        ld      e, ' '
        call    fill_cells
        jp      set.ground
;
; Ground: the byte is shown, or it is a control code
ground:
.ascii:                                     ; G0 or G1 in use is ASCII
        cp      ' '
        jr      c, control
.show:                                      ; Show code A at the cursor
        ld      hl, (state.console_pointer)
        ld      (hl), a
        inc     hl
        ld      a, (state.attribute)
        ld      (hl), a
        ld      a, (state.console_column)
        cp      79
        jr      z, .last_column
        inc     a
        ld      (state.console_column), a
        inc     hl
        ld      (state.console_pointer), hl
        jp      done
.last_column:                               ; The cursor stays in the last column
        ld      a, (state.autowrap)
        or      a
        jp      z, done                     ; ...and the next character replaces this one
        ld      (state.wrap_pending), a     ; ...or goes to the next line
        call    set_ground_stage
        jp      done
.graphics:                                  ; The line-drawing set is in use
        cp      ' '
        jr      c, control
        cp      $5F
        jr      c, .show
        cp      $7F
        jr      nc, .show
        ld      hl, graphics_set-$5F
        add     hl, a
        ld      a, (hl)
        jr      .show
.uk:                                        ; The UK set is in use
        cp      ' '
        jr      c, control
        cp      '#'
        jr      nz, .show
        ld      a, $9C                      ; CP437 pound sign
        jr      .show
.wrap:                                      ; A wrap is pending
        cp      ' '
        jr      c, control
        push    af
        xor     a
        ld      (state.console_column), a
        call    index
        call    calculate_console_pointer   ; Clears the wrap: the stage is the character set's again
        pop     af
        ld      hl, (state.stage)
        jp      (hl)
;
; A control code, in ground or inside a sequence. Inside a sequence it acts
; and the sequence carries on, apart from CAN, SUB and ESC.
control:
        add     a, a
        ld      hl, control_table
        add     hl, a
        ld      a, (hl)
        inc     hl
        ld      h, (hl)
        ld      l, a
        jp      (hl)
control_table:
        DW      done, done, done, done, done, done, done, done              ; NUL-BEL
        DW      ctl.bs, ctl.ht, ctl.lf, ctl.lf, ctl.lf, ctl.cr, ctl.so, ctl.si ; BS HT LF VT FF CR SO SI
        DW      done, done, done, done, done, done, done, done              ; DLE-ETB
        DW      set.ground, done, set.ground, set.escape, done, done, done, done ; CAN EM SUB ESC FS-US
;
ctl:
.bs:
        ld      a, (state.console_column)
        or      a
        jr      z, .moved
        dec     a
        ld      (state.console_column), a
.moved:
        call    calculate_console_pointer
        jp      done
.ht:                                        ; To the next tab stop, or column 80
        ld      a, (state.console_column)
        ld      hl, state.tabs
        add     hl, a
.ht_next:
        cp      79
        jr      nc, .ht_column
        inc     a
        inc     hl
        bit     0, (hl)
        jr      z, .ht_next
.ht_column:
        ld      (state.console_column), a
        jr      .moved
.lf:
        call    index
        ld      a, (state.newline)
        or      a
        jr      z, .moved
.cr:
        xor     a
        ld      (state.console_column), a
        jr      .moved
.so:
        ld      a, 1
        jr      .shift
.si:
        xor     a
.shift:
        ld      (state.shift), a
        call    select_charset
        jp      done
;
mode:                                ; MODE functions are used to handle what happens in a single state
.escape:                                ; ESCape starts a control code, what next: ESC ...?
        cp      ' '
        jp      c, control
        cp      '['
        jp      z, set.csi
        cp      'D'
        jp      z, esc.ind
        cp      'M'
        jp      z, esc.ri
        cp      'E'
        jp      z, esc.nel
        cp      'H'
        jp      z, esc.hts
        cp      '7'
        jp      z, esc.decsc
        cp      '8'
        jp      z, esc.decrc
        cp      'c'
        jp      z, esc.ris
        cp      '('
        jp      z, set.scs_g0
        cp      ')'
        jp      z, set.scs_g1
        cp      '#'
        jp      z, set.hash
        cp      $7F
        jp      z, done                     ; DEL is ignored
        cp      '0'
        jp      c, set.esc_ignore           ; Another intermediate: the final byte follows
        jp      set.ground                  ; Not known: the sequence ends, nothing shown
.esc_ignore:                            ; ESC, intermediates: up to the final byte
        cp      ' '
        jp      c, control
        cp      '0'
        jp      c, done
        cp      $7F
        jp      z, done
        jp      set.ground
.hash:                                  ; ESC #
        cp      ' '
        jp      c, control
        cp      '8'
        jp      z, esc.decaln
        jr      .esc_ignore
.scs:                                   ; ESC ( or ESC ): the set for state.scs_target
        cp      ' '
        jp      c, control
        cp      '0'
        jp      c, done
        ld      c, 2
        jr      z, .designate
        ld      c, 1
        cp      'A'
        jr      z, .designate
        ld      c, 0
        cp      'B'
        jr      z, .designate
        cp      $7F
        jp      z, done
        jp      set.ground                  ; Other sets: no change
.designate:
        ld      a, (state.scs_target)
        ld      hl, state.g0
        add     hl, a
        ld      (hl), c
        call    select_charset
        jp      set.ground
.csi:                                   ; Control Sequence Introducer - params or command follow: [ ...?
        cp      ' '
        jp      c, control
        cp      '0'
        jr      c, .csi_bad                 ; An intermediate: not a sequence DP/M knows
        cp      ':'
        jr      c, .digit
        cp      ';'
        jr      z, .separator
        cp      '?'
        jr      z, .private
        cp      '@'
        jr      c, .csi_bad                 ; : < = >
        cp      $7F
        jp      z, done
        jp      c, csi_final
        jp      set.ground
.csi_bad:
        ld      hl, mode.csi_ignore
        jp      savestage
.digit:                                     ; The parameter is value*10 + digit, at most 255
        sub     '0'
        ld      c, a
        ld      hl, (state.param_pointer)
        ld      e, (hl)
        ld      d, 10
        mul     d, e
        ld      a, d
        or      a
        jr      nz, .param_max
        ld      a, e
        add     a, c
        jr      nc, .param
.param_max:
        ld      a, 255
.param:
        ld      (hl), a
        jp      done
.separator:
        ld      hl, (state.param_pointer)
        ld      de, state.param_sink
        or      a
        sbc     hl, de
        jp      z, done                     ; Past the last parameter: the rest go in the sink
        add     hl, de
        inc     hl
        ld      (state.param_pointer), hl
        jp      done
.private:
        ld      a, 1
        ld      (state.private), a
        jp      done
.csi_ignore:                            ; A CSI sequence DP/M does not know: up to the final byte
        cp      ' '
        jp      c, control
        cp      '@'
        jp      c, done
        cp      $7F
        jp      z, done
        jp      set.ground
;
csi_final:
        ld      c, a
        ld      a, (state.private)
        or      a
        ld      a, c
        jr      nz, .private
        cp      'A'
        jp      z, csi.cuu
        cp      'B'
        jp      z, csi.cud
        cp      'C'
        jp      z, csi.cuf
        cp      'D'
        jp      z, csi.cub
        cp      'H'
        jp      z, csi.cup
        cp      'f'
        jp      z, csi.cup
        cp      'J'
        jp      z, csi.ed
        cp      'K'
        jp      z, csi.el
        cp      'm'
        jp      z, csi.sgr
        cp      'r'
        jp      z, csi.decstbm
        cp      'g'
        jp      z, csi.tbc
        cp      'h'
        jp      z, csi.sm
        cp      'l'
        jp      z, csi.rm
        cp      'n'
        jp      z, csi.dsr
        cp      'c'
        jp      z, csi.da
        jp      set.ground
.private:
        cp      'h'
        jp      z, csi.decset
        cp      'l'
        jp      z, csi.decrst
        jp      set.ground
;
; ESC sequences
esc:
.ind:
        call    index
        jp      move_done
.ri:
        call    reverse_index
        jp      move_done
.nel:
        xor     a
        ld      (state.console_column), a
        call    index
        jp      move_done
.hts:
        ld      a, (state.console_column)
        ld      hl, state.tabs
        add     hl, a
        ld      (hl), 1
        jp      set.ground
.decsc:
        ld      hl, state.cursor
        ld      de, state.saved
        ld      bc, cursorBytes
        ldir
        jp      set.ground
.decrc:
        ld      hl, state.saved
        ld      de, state.cursor
        ld      bc, cursorBytes
        ldir
        call    make_attribute
        call    select_charset
        jp      move_done
.decaln:                                    ; Margins to the console, cursor home, "E" in every cell
        xor     a
        ld      (state.top), a
        ld      (state.console_row), a
        ld      (state.console_column), a
        ld      a, consoleRows-1
        ld      (state.bottom), a
        ld      b, consoleTop
.decaln_row:
        push    bc
        ld      a, b
        call    display_row_addr
        ld      bc, 80
        ld      a, (state.erase_attr)
        ld      e, 'E'
        call    fill_cells
        pop     bc
        inc     b
        ld      a, b
        cp      consoleTop+consoleRows
        jr      nz, .decaln_row
        jp      move_done
.ris:
        ld      a, (state.screen_reverse)
        or      a
        jr      z, .ris_state
        xor     a
        ld      (state.screen_reverse), a
        call    load_palette
.ris_state:
        ld      hl, reset_values
        ld      de, state.cursor
        ld      bc, resetBytes
        ldir
        ld      hl, state.tabs
        ld      b, 80
.ris_tab:
        ld      a, b
        and     7
        ld      a, 0
        jr      nz, .ris_tab_set
        inc     a                           ; Columns 1, 9, 17 ... 73
.ris_tab_set:
        ld      (hl), a
        inc     hl
        djnz    .ris_tab
        call    make_attribute
        call    select_charset
        ld      b, 0
        ld      c, consoleRows
        call    clear_console_rows
        jp      move_done
;
; CSI sequences
csi:
.cuu:                                       ; Stops at the top margin, or row 1 above it
        call    count_param
        ld      c, a
        ld      a, (state.top)
        ld      b, a
        ld      a, (state.console_row)
        cp      b
        jr      nc, .cuu_limit
        ld      b, 0
.cuu_limit:
        sub     c
        jr      c, .cuu_clamp
        cp      b
        jr      nc, .set_row
.cuu_clamp:
        ld      a, b
        jr      .set_row
.cud:                                       ; Stops at the bottom margin, or the last row below it
        call    count_param
        ld      c, a
        ld      a, (state.bottom)
        ld      b, a
        ld      a, (state.console_row)
        cp      b
        jr      z, .cud_limit
        jr      c, .cud_limit
        ld      b, consoleRows-1
.cud_limit:
        add     a, c
        jr      c, .cud_clamp
        cp      b
        jr      c, .set_row
.cud_clamp:
        ld      a, b
.set_row:
        ld      (state.console_row), a
        jp      move_done
.cuf:
        call    count_param
        ld      c, a
        ld      a, (state.console_column)
        add     a, c
        jr      c, .cuf_clamp
        cp      80
        jr      c, .set_column
.cuf_clamp:
        ld      a, 79
        jr      .set_column
.cub:
        call    count_param
        ld      c, a
        ld      a, (state.console_column)
        sub     c
        jr      nc, .set_column
        xor     a
.set_column:
        ld      (state.console_column), a
        jp      move_done
.cup:                                       ; 0 or no parameter is 1, past the edge is the edge
        ld      a, (state.params)
    IF DPM_DEBUG
                call KERNEL_DEBUG.tm_a_loc4
    ENDIF
        call    .one_based
        ld      c, a
        ld      a, (state.origin)
        or      a
        jr      z, .cup_absolute
        ld      a, (state.bottom)
        ld      b, a
        ld      a, (state.top)
        add     a, c
        jr      c, .cup_clamp
        ld      c, a
        jr      .cup_limit
.cup_absolute:
        ld      b, consoleRows-1
.cup_limit:
        ld      a, c
        cp      b
        jr      c, .cup_row
.cup_clamp:
        ld      a, b
.cup_row:
        ld      (state.console_row), a
        ld      a, (state.params+1)
    IF DPM_DEBUG
                call KERNEL_DEBUG.tm_a_loc8
                call map_graphics_mem       ; The tracer above pages the screen out
    ENDIF
        call    .one_based
        cp      80
        jr      c, .set_column
        ld      a, 79
        jr      .set_column
.one_based:
        or      a
        ret     z
        dec     a
        ret
.ed:
        ld      a, (state.params)
        or      a
        jr      z, .ed_to_end
        dec     a
        jr      z, .ed_to_cursor
        dec     a
        jp      nz, set.ground
        ld      b, 0
        ld      c, consoleRows
        call    clear_console_rows
        jp      set.ground
.ed_to_end:
        call    clear_to_row_end
        ld      a, (state.console_row)
        inc     a
        ld      b, a                        ; The rows below the cursor
        neg
        add     a, consoleRows
        ld      c, a
        call    clear_console_rows
        jp      set.ground
.ed_to_cursor:
        ld      b, 0
        ld      a, (state.console_row)
        ld      c, a                        ; The rows above the cursor
        call    clear_console_rows
        call    clear_row_to_cursor
        jp      set.ground
.el:
        ld      a, (state.params)
        or      a
        jr      z, .el_to_end
        dec     a
        jr      z, .el_to_cursor
        dec     a
        jp      nz, set.ground
        ld      a, (state.console_row)
        add     a, consoleTop
        call    clear_display_row
        jp      set.ground
.el_to_end:
        call    clear_to_row_end
        jp      set.ground
.el_to_cursor:
        call    clear_row_to_cursor
        jp      set.ground
.sgr:
        call    param_list
.sgr_param:
        ld      a, (hl)
        or      a
        jr      z, .sgr_reset
        cp      1
        jr      z, .sgr_bold
        cp      7
        jr      z, .sgr_reverse
        cp      22
        jr      z, .sgr_normal
        cp      27
        jr      z, .sgr_positive
        cp      39
        jr      z, .sgr_default_ink
        cp      49
        jr      z, .sgr_default_paper
        cp      38
        jr      z, .sgr_end                 ; Extended colours: the rest of the parameters are theirs
        cp      48
        jr      z, .sgr_end
        sub     30
        jr      c, .sgr_next
        cp      8
        jr      c, .sgr_ink
        sub     10
        jr      c, .sgr_next
        cp      8
        jr      nc, .sgr_next
        ld      (state.paper), a
        jr      .sgr_next
.sgr_ink:
        ld      (state.ink), a
        jr      .sgr_next
.sgr_reset:
        ld      (state.bold), a
        ld      (state.reverse), a
        ld      a, (reset_values.ink)
        ld      (state.ink), a
        ld      a, (reset_values.paper)
        ld      (state.paper), a
        jr      .sgr_next
.sgr_bold:
        ld      (state.bold), a
        jr      .sgr_next
.sgr_reverse:
        ld      a, 1
        ld      (state.reverse), a
        jr      .sgr_next
.sgr_normal:
        xor     a
        ld      (state.bold), a
        jr      .sgr_next
.sgr_positive:
        xor     a
        ld      (state.reverse), a
        jr      .sgr_next
.sgr_default_ink:
        ld      a, (reset_values.ink)
        ld      (state.ink), a
        jr      .sgr_next
.sgr_default_paper:
        ld      a, (reset_values.paper)
        ld      (state.paper), a
.sgr_next:
        inc     hl
        djnz    .sgr_param
.sgr_end:
        call    make_attribute
        jp      set.ground
.decstbm:                                   ; At least two rows, then the cursor goes home
        ld      a, (state.params)
        or      a
        jr      nz, .stbm_top
        inc     a
.stbm_top:
        dec     a
        ld      c, a
        ld      a, (state.params+1)
        or      a
        jr      z, .stbm_full
        cp      consoleRows+1
        jr      c, .stbm_bottom
.stbm_full:
        ld      a, consoleRows
.stbm_bottom:
        dec     a
        ld      b, a
        ld      a, c
        cp      b
        jp      nc, set.ground
        ld      (state.top), a
        ld      a, b
        ld      (state.bottom), a
        call    home
        jp      set.ground
.tbc:
        ld      a, (state.params)
        or      a
        jr      z, .tbc_here
        cp      3
        jp      nz, set.ground
        ld      hl, state.tabs
        ld      b, 80
.tbc_all:
        ld      (hl), 0
        inc     hl
        djnz    .tbc_all
        jp      set.ground
.tbc_here:
        ld      a, (state.console_column)
        ld      hl, state.tabs
        add     hl, a
        ld      (hl), 0
        jp      set.ground
.sm:
        ld      c, 1
        jr      .ansi_modes
.rm:
        ld      c, 0
.ansi_modes:
        call    param_list
.ansi_mode:
        ld      a, (hl)
        cp      20
        jr      nz, .ansi_next
        ld      a, c
        ld      (state.newline), a
.ansi_next:
        inc     hl
        djnz    .ansi_mode
        jp      set.ground
.decset:
        ld      c, 1
        jr      .dec_modes
.decrst:
        ld      c, 0
.dec_modes:
        call    param_list
.dec_mode:
        ld      a, (hl)
        cp      1
        jr      z, .decckm
        cp      5
        jr      z, .decscnm
        cp      6
        jr      z, .decom
        cp      7
        jr      nz, .dec_next
        ld      a, c
        ld      (state.autowrap), a
        jr      .dec_next
.decckm:
        ld      a, c
        ld      (state.cursor_keys), a
        jr      .dec_next
.decscnm:
        ld      a, (state.screen_reverse)
        cp      c
        jr      z, .dec_next
        ld      a, c
        ld      (state.screen_reverse), a
        push    hl
        push    bc
        call    load_palette
        pop     bc
        pop     hl
        jr      .dec_next
.decom:
        ld      a, c
        ld      (state.origin), a
        push    hl
        push    bc
        call    home
        pop     bc
        pop     hl
.dec_next:
        inc     hl
        djnz    .dec_mode
        jp      set.ground
.dsr:
        ld      a, (state.params)
        ld      hl, reply_ok
        cp      5
        jr      z, .reply
        cp      6
        jp      nz, set.ground
        ld      hl, reply_cpr               ; ESC [
        call    push_reply
        ld      a, (state.origin)
        or      a
        jr      z, .cpr_row
        ld      a, (state.top)
.cpr_row:
        ld      b, a
        ld      a, (state.console_row)
        sub     b
        inc     a
        call    push_decimal
        ld      a, ';'
        call    KERNEL.console_push
        ld      a, (state.console_column)
        inc     a
        call    push_decimal
        ld      a, 'R'
        call    KERNEL.console_push
        jp      set.ground
.da:
        ld      a, (state.params)
        or      a
        jp      nz, set.ground
        ld      hl, reply_da
.reply:
        call    push_reply
        jp      set.ground
;
; Puts the 0-terminated reply at HL in the console input queue
;     Dirties AF, HL
push_reply:
        ld      a, (hl)
        or      a
        ret     z
        push    hl
        call    KERNEL.console_push
        pop     hl
        inc     hl
        jr      push_reply
;
; Puts A, 1-99, in the console input queue as decimal digits
;     Dirties AF, BC, HL
push_decimal:
        ld      b, '0'
.tens:
        cp      10
        jr      c, .units
        sub     10
        inc     b
        jr      .tens
.units:
        ld      c, a
        ld      a, b
        cp      '0'
        call    nz, KERNEL.console_push
        ld      a, c
        add     a, '0'
        jp      KERNEL.console_push
;
reply_ok:
        DB      KERNEL_KEYBOARD.ESC, "[0n", 0
reply_cpr:
        DB      KERNEL_KEYBOARD.ESC, "[", 0
reply_da:
        DB      KERNEL_KEYBOARD.ESC, "[?1;0c", 0
;
; Parameter 1, with 0 or none as 1
;     Dirties AF
count_param:
        ld      a, (state.params)
        or      a
        ret     nz
        inc     a
        ret
;
; HL = the first parameter, B = how many were given (1-16)
;     Dirties AF, DE
param_list:
        ld      hl, (state.param_pointer)
        ld      de, state.params
        or      a
        sbc     hl, de
        ld      a, l
        cp      16
        jr      c, .count
        ld      a, 15
.count:
        inc     a
        ld      b, a
        ex      de, hl
        ret
;
; The attributes for printed and for erased cells, from the rendition
;     Dirties AF, B
make_attribute:
        ld      a, (state.bold)
        rrca
        rrca                                ; Bold is pair bit 6
        ld      b, a
        ld      a, (state.ink)
        add     a, a
        add     a, a
        add     a, a
        or      b
        ld      b, a
        ld      a, (state.paper)
        or      b
        add     a, a                        ; Pair << 1
        ld      (state.erase_attr), a
        ld      b, a
        ld      a, (state.reverse)
        or      b
        ld      (state.attribute), a
        ret
;
; The set in use is G1 after SO, G0 after SI
;     Dirties AF, HL
select_charset:
        ld      a, (state.shift)
        ld      hl, state.g0
        add     hl, a
        ld      a, (hl)
        ld      (state.active_set), a
        jr      set_ground_stage
;
; Cursor home: the top margin in origin mode, row 1 otherwise
;     Dirties AF, DE, HL
home:
        ld      a, (state.origin)
        or      a
        jr      z, .row
        ld      a, (state.top)
.row:
        ld      (state.console_row), a
        xor     a
        ld      (state.console_column), a
;
; Calculate the memory address for writing to the console based on current
; Row/Col. A move clears a pending wrap.
;     Dirties AF, HL, DE
calculate_console_pointer:
        ld      a, (state.console_row)
        add     a, consoleTop
        call    display_row_addr
        ld      a, (state.console_column)
        add     a, a                        ; Two bytes per cell
        add     hl, a
        ld      (state.console_pointer), hl
        xor     a
        ld      (state.wrap_pending), a
;
; state.ground is ground.wrap while a wrap is pending, otherwise the stage for
; the set in use; in ground, state.stage follows it
;     Dirties AF, HL
set_ground_stage:
        ld      a, (state.wrap_pending)
        or      a
        ld      hl, ground.wrap
        jr      nz, .set
        ld      a, (state.active_set)
        add     a, a
        ld      hl, charset_stages
        add     hl, a
        ld      a, (hl)
        inc     hl
        ld      h, (hl)
        ld      l, a
.set:
        ld      (state.ground), hl
        ld      a, (state.in_sequence)
        or      a
        ret     nz
        ld      (state.stage), hl
        ret
charset_stages:                             ; By state.active_set
        DW      ground.ascii, ground.uk, ground.graphics
;
; Cursor down a row; at the bottom margin the region scrolls up instead, and
; on the last row below the region nothing happens
;     Dirties AF, BC, DE, HL
index:
        ld      a, (state.console_row)
        ld      hl, state.bottom
        cp      (hl)
        jr      z, scroll_up
        cp      consoleRows-1
        ret     z
        inc     a
        ld      (state.console_row), a
        ret
;
; Cursor up a row; at the top margin the region scrolls down instead, and
; on the first row above the region nothing happens
;     Dirties AF, BC, DE, HL
reverse_index:
        ld      a, (state.console_row)
        ld      hl, state.top
        cp      (hl)
        jr      z, scroll_down
        or      a
        ret     z
        dec     a
        ld      (state.console_row), a
        ret
;
; Scroll the region up a line. The whole console scrolls with the ring.
;     Dirties AF, BC, DE, HL
scroll_up:
        ld      a, (state.top)
        or      a
        jr      nz, .copy
        ld      a, (state.bottom)
        cp      consoleRows-1
        jp      z, screen_scroll
.copy:
        ld      a, (state.top)
        ld      c, a                        ; Destination row
.row:
        ld      a, (state.bottom)
        cp      c
        jr      z, .last
        ld      b, c
        inc     b                           ; Source row
        push    bc
        call    copy_console_row
        pop     bc
        inc     c
        jr      .row
.last:
        ld      a, c
        add     a, consoleTop
        jp      clear_display_row
;
; Scroll the region down a line. The whole console scrolls with the ring.
;     Dirties AF, BC, DE, HL
scroll_down:
        ld      a, (state.top)
        or      a
        jr      nz, .copy
        ld      a, (state.bottom)
        cp      consoleRows-1
        jp      z, screen_scroll_down
.copy:
        ld      a, (state.bottom)
        ld      c, a                        ; Destination row
.row:
        ld      a, (state.top)
        cp      c
        jr      z, .first
        ld      b, c
        dec     b                           ; Source row
        push    bc
        call    copy_console_row
        pop     bc
        dec     c
        jr      .row
.first:
        ld      a, c
        add     a, consoleTop
        jp      clear_display_row
;
; Copy console row B to console row C
;     Dirties AF, BC, DE, HL
copy_console_row:
        ld      a, c
        add     a, consoleTop
        call    display_row_addr
        push    hl
        ld      a, b
        add     a, consoleTop
        call    display_row_addr
        pop     de
        ld      bc, rowBytes
        ldir
        ret

set:                                ; SET functions are used to transition between states within the machine
.ground:                                ; ... Ground is the "normal" printing state, no ESC seq started
    IF DPM_DEBUG
                xor a : ld (state.debug_terminal), a
    ENDIF
        xor     a
        ld      (state.in_sequence), a
        ld      hl, (state.ground)
        jr      savestage
.escape:                                ; Starting ESCape sequence
        ld      a, 1
        ld      (state.in_sequence), a
        ld      hl, mode.escape
    IF DPM_DEBUG
                ld (state.debug_terminal), a
    ENDIF
        jr      savestage
.csi:                                   ; Starting Control Sequence Introducer, e.g. ESC[nn;nnX - n=num
        ld      hl, state.params
        ld      (state.param_pointer), hl
        xor     a
        ld      b, 17                       ; The parameters and the sink
.csi_clear:
        ld      (hl), a
        inc     hl
        djnz    .csi_clear
        ld      (state.private), a
        ld      hl, mode.csi
        jr      savestage
.scs_g0:
        xor     a
        jr      .scs
.scs_g1:
        ld      a, 1
.scs:
        ld      (state.scs_target), a
        ld      hl, mode.scs
        jr      savestage
.hash:
        ld      hl, mode.hash
        jr      savestage
.esc_ignore:
        ld      hl, mode.esc_ignore
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
move_done:                          ; Row and column are set: point at the cell, end the sequence
        call    calculate_console_pointer
        jp      set.ground

;
; The map address of display row A (0-31)
;     Dirties AF, DE, HL
display_row_addr:
        ld      hl, state.scroll_row
        add     a, (hl)
        and     31                          ; The map is a ring of 32 rows
        ld      e, a
        ld      d, rowBytes
        mul     d, e                        ; Z80N fast 8bit multiply
        ld      hl, tilemapAddr
        add     hl, de
        ret

;
; Show map row scroll_row at display row 0. NextReg $31 counts pixel lines.
;     Dirties AF
set_scroll:
        ld      a, (state.scroll_row)
        add     a, a
        add     a, a
        add     a, a                        ; 8 lines a row
        nextreg TILEMAP_YOFFSET_NR_31, a
        ret

;
; Take the cursor off the screen: its cell gets back the attribute it had
; before cursor_show, whichever way the blink has left it.
;     Dirties HL
cursor_hide:
        push    af
        ld      a, (state.cursor_shown)
        or      a
        jr      z, .done                    ; ...not drawn, nothing to put back
        xor     a
        ld      (state.cursor_shown), a
        ld      hl, (BLINK.cell)
        ld      a, (state.cursor_attr)
        ld      (hl), a
.done:
        pop     af
        ret

;
; Draw the cursor at console_pointer: flip the reverse bit of its cell, keep
; the attribute it had, and give the cell to the frame interrupt (BLINK),
; which flips it again every BLINK.frames frames, starting a full count from
; now.
;     Dirties AF, HL
cursor_show:
        ld      a, (state.cursor_shown)
        or      a
        ret     nz                          ; Cursor already drawn
        inc     a
        ld      (state.cursor_shown), a
        ld      hl, (state.console_pointer)
        inc     hl                          ; The attribute byte
        ld      a, (hl)
        ld      (state.cursor_attr), a
        xor     attrReverse
        ld      (hl), a
        ld      (BLINK.cell), hl
        ld      a, BLINK.frames
        ld      (BLINK.count), a
        ret

;
; Clear C console rows (0 or more) from console row B
;     Dirties AF, HL, DE, BC
clear_console_rows:
        ld      a, c
        or      a
        ret     z
.row:
        push    bc
        ld      a, b
        add     a, consoleTop
        call    clear_display_row
        pop     bc
        inc     b
        dec     c
        jr      nz, .row
        ret

;
; Clear from the cursor to the end of its row, cursor cell included
;     Dirties AF, HL, DE, BC
clear_to_row_end:
        ld      a, (state.console_column)
        neg
        add     a, 80                       ; Cells from the cursor to the end of the row
        ld      b, 0
        ld      c, a
        ld      hl, (state.console_pointer)
        jr      fill_spaces

;
; Clear from the start of the cursor's row to the cursor, cursor cell included
;     Dirties AF, HL, DE, BC
clear_row_to_cursor:
        ld      a, (state.console_row)
        add     a, consoleTop
        call    display_row_addr
        ld      a, (state.console_column)
        inc     a                           ; Cells, the cursor cell included
        ld      b, 0
        ld      c, a
        jr      fill_spaces

;
; Clear display row A, outside the console, with the default attribute
;     Dirties AF, HL, DE, BC
clear_border_row:
        call    display_row_addr
        ld      bc, 80
        ld      a, (state.default_attr)
        ld      e, ' '
        jr      fill_cells

;
; Clear display rows 0 and 31, outside the console, with the default attribute
;     Dirties AF, HL, DE, BC
clear_border_rows:
        call    map_graphics_mem
        xor     a
        call    clear_border_row
        ld      a, 31
        call    clear_border_row
        jp      unmap_graphics_mem

;
; Clear display row A
;     Dirties AF, HL, DE, BC
clear_display_row:
        call    display_row_addr
        ld      bc, 80
;
; Fill BC cells (at least 1) from HL with spaces in the erase attribute
;     Dirties AF, HL, DE, BC
fill_spaces:
        ld      a, (state.erase_attr)
        ld      e, ' '
;
; Fill BC cells (at least 1) from HL with character E in attribute A
;     Dirties AF, HL, DE, BC
fill_cells:
        ld      (hl), e
        inc     hl
        ld      (hl), a
        dec     hl
        dec     bc
        ld      a, b
        or      c
        ret     z
        ld      d, h
        ld      e, l
        inc     de
        inc     de                          ; The next cell
        sla     c
        rl      b                           ; Bytes in the cells left
        ldir                                ; Copies the first cell along
        ret

;
; Scroll the whole console up one line: display row 31, blank, becomes the
; last console row, and console row 0 becomes display row 0 and is cleared
;     Dirties AF, HL, DE, and BC
screen_scroll:
        ld      a, 31
        call    clear_display_row
        ld      hl, state.scroll_row
        ld      a, (hl)
        inc     a
        and     31
        ld      (hl), a
        call    set_scroll
        xor     a
        jr      clear_border_row

;
; Scroll the whole console down one line: display rows 31 and 0, blank,
; become display row 0 and console row 0, and the last console row becomes
; display row 31 and is cleared
;     Dirties AF, HL, DE, and BC
screen_scroll_down:
        ld      a, 31
        call    clear_border_row
        xor     a
        call    clear_display_row
        ld      hl, state.scroll_row
        ld      a, (hl)
        dec     a
        and     31
        ld      (hl), a
        call    set_scroll
        ld      a, 31
        jr      clear_border_row

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

;
; Load the tilemap first palette: entry pair*2 is the pair's paper, pair*2+1
; its ink, bright when bold is set (pair = bold*64 + ink*8 + paper). With
; DECSCNM set, the two are swapped. The border follows (paper_border).
;     Dirties AF, HL, C, DE
load_palette:
        nextreg PALETTE_CONTROL_NR_43, 0x30 ; Tilemap first palette, index moves on after each colour
        nextreg PALETTE_INDEX_NR_40, 0
        ld      c, 0                        ; Pair
.pair:
        ld      a, c
        and     7
        ld      e, a                        ; Paper
        ld      a, c
        rrca : rrca : rrca
        and     $0F
        ld      d, a                        ; Ink, 8 on when bold
        ld      a, (state.screen_reverse)
        or      a
        jr      z, .write
        ld      a, d
        ld      d, e
        ld      e, a
.write:
        ld      a, e
        call    .colour
        ld      a, d
        call    .colour
        inc     c
        bit     7, c
        jr      z, .pair                    ; ...until all 128 pairs are done
        jr      paper_border
.colour:                                    ; Write colour A (0-15) of palette_colours
        add     a, a
        ld      hl, palette_colours
        add     hl, a
        ld      a, (hl)
        nextreg PALETTE_VALUE_9BIT_NR_44, a ; Bits 8-1, RRRGGGBB
        inc     hl
        ld      a, (hl)
        nextreg PALETTE_VALUE_9BIT_NR_44, a ; Bit 0, the low blue bit
        ret

;
; Make the global transparency and fallback colours (NextRegs $14 and $4A) the
; default paper as it shows, the default ink with DECSCNM set, so the border
; shows it. The two are always equal: in text mode a pixel of the transparency
; colour shows the fallback, so it looks the same and no ink vanishes.
;     Dirties AF
paper_border:
        push    hl
        ld      a, (state.screen_reverse)
        or      a
        ld      a, (reset_values.paper)
        jr      z, .rgb
        ld      a, (reset_values.ink)
.rgb:
        add     a, a
        ld      hl, palette_colours
        add     hl, a
        ld      a, (hl)                     ; RRRGGGBB, the 8 high bits
        nextreg GLOBAL_TRANSPARENCY_NR_14, a
        nextreg TRANSPARENCY_FALLBACK_COL_NR_4A, a
        pop     hl
        ret

    ;; A 9-bit colour, levels 0-7 for red, green and blue, as NextReg $44 takes it
m_rgb9  MACRO   red, green, blue
        DB      (red<<5)|(green<<2)|(blue>>1), blue&1
    ENDM
    ;; The VGA text colours in SGR order, 8 normal then 8 bright. VGA's levels
    ;; $00, $55, $AA, $FF are 0, 2, 5, 7.
palette_colours:
        m_rgb9  0, 0, 0                     ; Black
        m_rgb9  5, 0, 0                     ; Red
        m_rgb9  0, 5, 0                     ; Green
        m_rgb9  5, 2, 0                     ; Yellow (VGA brown)
        m_rgb9  0, 0, 5                     ; Blue
        m_rgb9  5, 0, 5                     ; Magenta
        m_rgb9  0, 5, 5                     ; Cyan
        m_rgb9  5, 5, 5                     ; White
        m_rgb9  2, 2, 2                     ; Bright black
        m_rgb9  7, 2, 2                     ; Bright red
        m_rgb9  2, 7, 2                     ; Bright green
        m_rgb9  7, 7, 2                     ; Bright yellow
        m_rgb9  2, 2, 7                     ; Bright blue
        m_rgb9  7, 2, 7                     ; Bright magenta
        m_rgb9  2, 7, 7                     ; Bright cyan
        m_rgb9  7, 7, 7                     ; Bright white

    ;; The VT100 line-drawing set, codes $5F-$7E, as CP437 codes. Glyphs that
    ;; CP437's upper half lacks (the diamond, the control pictures and "not
    ;; equal") show as a small square, $FE; scan lines 1, 3 and 7 as the
    ;; middle line and scan line 9 as "_".
graphics_set:
        DB      ' '                         ; $5F blank
        DB      $FE                         ; $60 diamond
        DB      $B1                         ; $61 checkerboard
        DB      $FE, $FE, $FE, $FE          ; $62-$65 HT FF CR LF
        DB      $F8                         ; $66 degree
        DB      $F1                         ; $67 plus or minus
        DB      $FE, $FE                    ; $68-$69 NL VT
        DB      $D9, $BF, $DA, $C0, $C5     ; $6A-$6E corners and crossing
        DB      $C4, $C4, $C4, $C4, '_'     ; $6F-$73 scan lines 1, 3, 5, 7, 9
        DB      $C3, $B4, $C1, $C2, $B3     ; $74-$78 tees and vertical line
        DB      $F3, $F2, $E3, $FE, $9C, $FA; $79-$7E <= >= pi != pound dot

;
; Make D = ink and E = paper (0-7) the default colours: SGR 0, 39 and 49 and
; ESC c give them, and the ink and paper in use, and those DECRC restores,
; become them now. The border shows the new paper (paper_border)
;     Dirties AF, B
set_defaults:
        ld      a, d
        ld      (reset_values.ink), a
        ld      (reset_values.saved_ink), a
        ld      (state.ink), a
        ld      (state.saved_ink), a
        add     a, a
        add     a, a
        add     a, a
        or      e
        add     a, a                        ; Pair << 1
        ld      (state.default_attr), a
        ld      a, e
        ld      (reset_values.paper), a
        ld      (reset_values.saved_paper), a
        ld      (state.paper), a
        ld      (state.saved_paper), a
        call    paper_border
        jp      make_attribute

init:                               ; Called INIT externally
reset:                              ; resets the ANSI processor
        xor     a
        ld      (state.in_sequence), a
    IF DPM_DEBUG
                ld      (state.debug_terminal), a
    ENDIF
        ld      hl, (state.ground)
        ld      (state.stage), hl
        ret

;-----------------------------------------------------------------------------
; Terminal Emulator State
;-----------------------------------------------------------------------------
    ;; ESC c puts state.cursor to state.wrap_pending back to these. Their
    ;; colours are the defaults, which set_defaults changes
reset_values:
        DB      0, 0
.ink
        DB      defaultInk
.paper
        DB      defaultPaper
        DB      0, 0, 0, 0, 0, 0
        DB      0, 0
.saved_ink
        DB      defaultInk
.saved_paper
        DB      defaultPaper
        DB      0, 0, 0, 0, 0, 0
        DB      1, 0, 0, 0, consoleRows-1, 0
state:
.cursor:                            ; What DECSC saves and DECRC restores
.console_column
        DB  0
.console_row
        DB  0
.ink                                ; SGR rendition: colours 0-7, bold and reverse 0 or 1
        DB  defaultInk
.paper
        DB  defaultPaper
.bold
        DB  0
.reverse
        DB  0
.g0                                 ; The sets in G0 and G1: 0 ASCII, 1 UK, 2 line drawing
        DB  0
.g1
        DB  0
.shift                              ; 1 after SO, G1 in use
        DB  0
.origin                             ; DECOM
        DB  0
.saved
        DB  0, 0
.saved_ink
        DB  defaultInk
.saved_paper
        DB  defaultPaper
        DB  0, 0, 0, 0, 0, 0
.autowrap                           ; DECAWM
        DB  1
.newline                            ; LNM
        DB  0
.cursor_keys                        ; DECCKM
        DB  0
.top                                ; Scroll region, console rows
        DB  0
.bottom
        DB  consoleRows-1
.wrap_pending                       ; 1 after a character in the last column
        DB  0
.reset_end:
.active_set                         ; The set in use, from G0 or G1
        DB  0
.screen_reverse                     ; DECSCNM
        DB  0
.attribute                          ; Attribute of printed characters
        DB  defaultAttr
.erase_attr                         ; Attribute of erased cells
        DB  defaultAttr
.default_attr                       ; Attribute of the default colours, for clear and rows 0 and 31
        DB  defaultAttr
.console_pointer
        DW  consoleAddr
.stage:
        DW  ground.ascii
.ground:                            ; The stage in ground
        DW  ground.ascii
.in_sequence                        ; 1 from ESC to the end of the sequence
        DB  0
.scs_target                         ; ESC ( or ESC ): 0 G0, 1 G1
        DB  0
.private                            ; 1 after ESC [ ?
        DB  0
.param_pointer
        DW  .params
.params:
        DS  16, 0
.param_sink                         ; Parameters past the 16th
        DB  0
.tabs                               ; 1 for a tab stop, a byte a column
        DB  0, 0, 0, 0, 0, 0, 0, 0
        DUP 9
        DB  1, 0, 0, 0, 0, 0, 0, 0
        EDUP
.debug_terminal
        DB  0
.cursor_shown                       ; 1 while the cursor is on its cell
        DB  0
.cursor_attr                        ; The attribute of the cursor's cell without the cursor
        DB  0
.scroll_row                         ; Map row shown at display row 0
        DB  0
cursorBytes     EQU     state.saved-state.cursor
resetBytes      EQU     state.reset_end-state.cursor
        ASSERT  state.reset_end-state.cursor == state-reset_values
        ASSERT  state.autowrap-state.saved == cursorBytes
        ASSERT  reset_values.ink-reset_values == state.ink-state.cursor
        ASSERT  reset_values.saved_ink-reset_values == state.saved_ink-state.cursor
        ASSERT  state.saved_ink-state.saved == state.ink-state.cursor
    ENDMODULE

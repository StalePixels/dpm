;-----------------------------------------------------------------------------
; -- DPM Keyboard Driver
; 
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FCB based1
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------
    MODULE KERNEL_KEYBOARD

; Scans the keyboard matrix, returns ASCII value in A, or 0 if no key pressed.
; keypos is left holding that key's matrix position, $FF if none.
read_char_a:
    call    read_matrix                     ; Get matrix inputs
    ld      (status), a                     ;
    ret

; Scans for a new keypress. Returns its code in A once per press, and
; 0 while no key is down or the same key is still held. A press is tracked by
; its matrix position, so letting go of a shift key before the key itself
; gives no second character. CAPS SHIFT+2 toggles caps lock and returns 0.
; CAPS SHIFT and SYMBOL SHIFT pressed and let go with no other key toggle
; Extended mode, as in NextZXOS; it applies to the next key, and Extended +
; 1 to 4 give KEY_PF1 to KEY_PF4. A code of KEY_SEQUENCE or more is a key
; that sends an ESC sequence ending in its low 7 bits (KERNEL.console_scan).
; Dirties HL, BC, DE
read_new_key:
    call    read_char_a                     ; This scan's key, 0 if none
    ld      b, a
    ld      hl, extended
    ld      a, (keypos)
    inc     a                               ; $FF, no key but the shifts?
    jr      z, .shifts                      ; ...Yes
    set     EXT_OTHER, (hl)                 ; ...No, the shifts are not alone
    jr      .track
.shifts:
    ld      a, (shifts)
    cp      3                               ; Both shifts down?
    jr      nz, .shifts_up
    set     EXT_BOTH, (hl)                  ; ...Yes, and no other key
    jr      .track
.shifts_up:
    or      a                               ; Any shift still down?
    jr      nz, .track                      ; ...Yes, wait for it
    ld      a, (hl)
    and     EXT_PRESS
    cp      1 << EXT_BOTH                   ; Both shifts, alone, then let go?
    ld      a, (hl)
    jr      nz, .shifts_done
    xor     1 << EXT_ARMED                  ; ...Yes, Extended mode on or off
.shifts_done:
    and     1 << EXT_ARMED                  ; A new press starts
    ld      (hl), a
.track:
    ld      a, (keypos)                     ; Where it is on the matrix
    ld      hl, prevpos                     ; Where the last scan's key was
    cp      (hl)                            ; Same key (or still none)?
    jr      z, .none                        ; ...Yes, nothing new
    ld      (hl), a                         ; ...No, remember it ($FF on release)
    inc     a                               ; A key let go?
    jr      z, .key                         ; ...Yes, B is 0
    ld      hl, extended
    bit     EXT_ARMED, (hl)                 ; Extended mode?
    jr      z, .key                         ; ...No
    res     EXT_ARMED, (hl)                 ; ...Yes, for this key only
    sub     16                              ; A is position + 1; keys 1 to 4 are 15 to 18
    cp      4
    jr      nc, .key                        ; Not 1 to 4: the key as it is
    add     a, KEY_PF1
    ret
.key:
    ld      a, b
    cp      CAPS
    ret     nz                              ; The new key, or 0 if one was let go
    ld      a, (cl_status)
    cpl                                     ; Flip all bits in CapsLock_status
    ld      (cl_status), a
.none:
    xor     a                               ; A=0, no new key
    ret
    
;
read_matrix:
    ld      bc, $fefe                       ; Point BC to "Shift/Z/X?/V" port
    ld      hl, MatrixLine0                 ; Point HL to MatrixLineX byte
.scanloop:
    in      a, (c)                          ; Read matrix row, low == pressed
    cpl                                     ; Flip the bits, high == pressed
    and     0b00011111                      ; mask right 5 bits ($1F)
    ld      (hl), a                         ; Save result to MatrixLineX memory
    inc     hl                              ; Increment MatrixLineX pointer
    rlc     b                               ; Rotate B left, move port to next Line
    jr      c, .scanloop                    ; Carry Flag set after 8 full reads
;.Select_Matrix_Lookup
    ld      hl, MatrixLine7
    ld      a, (hl)
    and     %00000010                       ; SYMBOL SHIFT is bit 1 of shifts
    res     1, (hl)                         ; Not a key of its own
    ld      hl, MatrixLine0
    bit     0, (hl)                         ; CAPS SHIFT is bit 0 of shifts
    res     0, (hl)                         ; Not a key of its own
    jr      z, .no_capsshift
    inc     a
.no_capsshift:
    ld      (shifts), a
    cp      3                               ; Both shifts?
    jr      z, .map                         ; ...Yes, MAP_CSSS, caps lock or not
    ld      e, a
    ld      a, (cl_status)
    or      a                               ; Cheap Zero Check
    ld      a, e
    jr      z, .map                         ; ...CapsLock off
    add     a, 4                            ; ...CapsLock on, the MAP_CL maps
.map:
    ld      e, a
    ld      d, 5 * 8                        ; Size of classic matrix
    mul     d, e
    ld      hl, KERNEL_KEYBOARD.MAP_def     ; HL points to matrix-to-ASCII map
    add     hl, de
;.Pressed_Normal
    ld      de, MatrixLine0                 ; Pointer to first line read
    ld      b, 8                            ; Count of rows, AKA times to loop
.rotatelines:
    ld      a, (de)                         ; Load matrix read value
    ld      c, 5                            ; Counter for valid bits in line
.rotatebits:
    rrc     a                               ; Shift right, into carry
    jr      c, .foundbit                    ; Carry Set == Key Pressed
    inc     hl                              ; Inc. "which key in map" pointer
    dec     c                               ; Dec. bits in line pointer
    jr      nz, .rotatebits                 ; If not end of line, loop
    inc     de                              ; Inc Matrix Line Pointer
    djnz    .rotatelines                    ; Dec. rows (B) & loop if not zero
    ld      a, $FF
    ld      (keypos), a                     ; No key down
    xor     a                               ; Fast zero set
    ret
;
.foundbit:
    ld      a, 8                            ; Matrix position = row * 5 + bit
    sub     b                               ; Row, 0-7
    ld      e, a
    add     a, a
    add     a, a
    add     a, e                            ; Row * 5
    add     a, 5
    sub     c                               ; Plus bit, 0-4
    ld      (keypos), a
    ld      a, (hl)                         ; Set A to value pointed by HL
    or      a                               ; set zero flag, if applicable
    ret 
;
cl_status       db      $00
prevpos         db      $ff     ; Matrix position of the key read_new_key last saw
keypos          db      $ff     ; Matrix position of the key at the last scan
shifts          db      0       ; Shifts down at the last scan: bit 0 CAPS, bit 1 SYMBOL
extended        db      0       ; Extended mode: the EXT_ bits
status	        db      0
counter         db      0
;
MatrixLine0     db      0
MatrixLine1     db      0
MatrixLine2     db      0
MatrixLine3     db      0
MatrixLine4     db      0
MatrixLine5     db      0
MatrixLine6     db      0
MatrixLine7     db      0
;
CAPS            EQU     $FF
EXT_ARMED       EQU     0       ; Extended mode, for the next key
EXT_BOTH        EQU     1       ; Both shifts down since all keys were up
EXT_OTHER       EQU     2       ; Another key down since all keys were up
EXT_PRESS       EQU     (1 << EXT_BOTH) | (1 << EXT_OTHER)
KEY_SEQUENCE    EQU     $C0     ; Codes from here up send ESC sequences
KEY_UP          EQU     $80 | 'A'
KEY_DOWN        EQU     $80 | 'B'
KEY_RIGHT       EQU     $80 | 'C'
KEY_LEFT        EQU     $80 | 'D'
KEY_PF1         EQU     $80 | 'P'       ; PF1 to PF4 follow

                        
MAP_def:        DB      0x00, "z",  "x",  "c",  "v"
                DB      "a",  "s",  "d",  "f",  "g"
                DB      "q",  "w",  "e",  "r",  "t"
                DB      "1",  "2",  "3",  "4",  "5"
                DB      "0",  "9",  "8",  "7",  "6"
                DB      "p",  "o",  "i",  "u",  "y"
                DB      CR,   "l",  "k",  "j",  "h"
                DB      " ",  0x00, "m",  "n",  "b"
;
MAP_CS:         DB      0x00, "Z",  "X",  "C",  "V"
                DB      "A",  "S",  "D",  "F",  "G"
                DB      "Q",  "W",  "E",  "R",  "T"
                DB      BS,   CAPS, 0x00, 0x00, KEY_LEFT        ; Cursor keys
                DB      DEL,  TAB,  KEY_RIGHT, KEY_UP, KEY_DOWN
                DB      "P",  "O",  "I",  "U",  "Y"
                DB      CR,   "L",  "K",  "J",  "H"
                DB      ESC,  0x00, "M",  "N",  "B"
;
MAP_SS:         DB      0x00, ':',  0x9C, '?',  '/' ; 0x9C == £
                DB      '~',  '|',  0x5C, '{',  '}' ; 0x5C == \
                DB      0x00, 0x00, 0x00, '<',  '>'
                DB      '!',  '@',  '#',  '$',  '%'
                DB      '_',  ')',  '(',  "'",  '&'
                DB      '"',  ';',  0x00, ']',  '['
                DB      CR,   '=',  '+',  '-',  '^'
                DB      ' ',  0x00, '.',  ',',  '*'
;
MAP_CSSS:       DB      0x00, CTR_Z,CTR_X,CTR_C,0x16
                DB      0x01, CTR_S,0x04, 0x06, 0x07
                DB      0x11, 0x17, CTR_E,CTR_R,0x14
                DB      DEL,  0x00, 0x00, 0x00, 0x00
                DB      BS,   0x00, TAB,  0x00, 0x00
                DB      CTR_P,0x0f, 0x09, CTR_U,0x19
                DB      CR,   0x0c, 0x0b, 0x0a, 0x08
                DB      " ",  0x00, 0x0d, 0x0e, 0x02
;
MAP_CL:         DB      0x00, "Z",  "X",  "C",  "V"
                DB      "A",  "S",  "D",  "F",  "G"
                DB      "Q",  "W",  "E",  "R",  "T"
                DB      "1",  "2",  "3",  "4",  "5"
                DB      "0",  "9",  "8",  "7",  "6"
                DB      "P",  "O",  "I",  "U",  "Y"
                DB      CR,   "L",  "K",  "J",  "H"
                DB      " ",  0x00, "M",  "N",  "B"
;
MAP_CL_CS:      DB      0x00, "Z",  "X",  "C",  "V"
                DB      "A",  "S",  "D",  "F",  "G"
                DB      "Q",  "W",  "E",  "R",  "T"
                DB      BS,   CAPS, 0x00, 0x00, KEY_LEFT        ; Cursor keys
                DB      DEL,  TAB,  KEY_RIGHT, KEY_UP, KEY_DOWN
                DB      "P",  "O",  "I",  "U",  "Y"
                DB      CR,   "L",  "K",  "J",  "H"
                DB      ESC,  0x00, "M",  "N",  "B"
;
MAP_CL_SS:      DB      0x00, ':',  0x9C, '?',  '/' ; 0x9C == £
                DB      '~',  '|',  0x5C, '{',  '}' ; 0x5C == \
                DB      0x00, 0x00, 0x00, '<',  '>'
                DB      '!',  '@',  '#',  '$',  '%'
                DB      '_',  ')',  '(',  "'",  '&'
                DB      '"',  ';',  0x00, ']',  '['
                DB      CR,   '=',  '+',  '-',  '^'
                DB      ' ',  0x00, '.',  ',',  '*'
    ENDMODULE
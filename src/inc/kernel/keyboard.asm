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

; Scans for a new keypress. Returns its ASCII value in A once per press, and
; 0 while no key is down or the same key is still held. A press is tracked by
; its matrix position, so letting go of a shift key before the key itself
; gives no second character. CAPS SHIFT+2 toggles caps lock and returns 0.
; Dirties HL, BC, DE
read_new_key:
    call    read_char_a                     ; This scan's key, 0 if none
    ld      b, a
    ld      a, (keypos)                     ; Where it is on the matrix
    ld      hl, prevpos                     ; Where the last scan's key was
    cp      (hl)                            ; Same key (or still none)?
    jr      z, .none                        ; ...Yes, nothing new
    ld      (hl), a                         ; ...No, remember it ($FF on release)
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
    ld      a, (cl_status)
    ld      hl, KERNEL_KEYBOARD.MAP_def     ; HP points to matrix-to-ASCII map
    or      a                               ; Cheap Zero Check
    jr      z, .capsoff                     ; ...CapsLock off
    ld      hl, KERNEL_KEYBOARD.MAP_CL      ; ...CapsLock on, new lookup table
.capsoff:
    ld      de, 5 * 8                       ; Size of classic matrix
    ld      a, (MatrixLine0)                ; Point at first line read
    bit     0, a                            ; check Line0/Bit0 (CS)
    call    nz, .found_capsshift            ; ...CapsShift was pressed
    ld      a, (MatrixLine7)                ; Point at last line read
    bit     1, a                            ; check Line7/Bit1 (SS)
    call    nz, .found_symbshift            ; ...SymbShift was pressed
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
.found_capsshift:
    add     hl, de                          ; Move matrix lookup pointer on 40
    res     0, a                            ; Set bit 0 of a, to 0
    ld      (MatrixLine0), a                ; Save the modified matrix0 line back
    ret
;
.found_symbshift:
    add     hl, de                          ; Move matrix lookup pointer on 40
    add     hl, de                          ; ...and 40 more
    res     1, a                            ; Set bit 1 of a, to 0
    ld      (MatrixLine7), a                ; Save the modified matrix7 line back
    ret
;
cl_status       db      $00
prevpos         db      $ff     ; Matrix position of the key read_new_key last saw
keypos          db      $ff     ; Matrix position of the key at the last scan
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
                DB      BS,   CAPS, 0x00, 0x00, CTR_S   ; Cursor keys give WordStar's
                DB      DEL,  TAB,  0x04, CTR_E,CTR_X   ; ^S left, ^D right, ^E up, ^X down
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
                DB      BS,   CAPS, 0x00, 0x00, CTR_S   ; Cursor keys give WordStar's
                DB      DEL,  TAB,  0x04, CTR_E,CTR_X   ; ^S left, ^D right, ^E up, ^X down
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
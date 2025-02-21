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

; Scans the keyboard matrix, returns ASCII value in A, or $FF is no key pressed
read_char_a:
    call    read_matrix                     ; Get matrix inputs
    cp      CAPS
    jr      nz, .status_and_ret
    
    ld      a, (cl_status)
    cpl                                     ; Flip all bits in CapsLock_status
    ld      (cl_status), a
    xor     a                               ; Zero A
.status_and_ret
    ld      (status), a                     ;
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
    xor     a                               ; Fast zero set
    ret
;
.foundbit:
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
prevkey         db      $ff
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
ESC             EQU     $1b
CTR_C           EQU     $03     ;control-c
CTR_E           EQU     $05     ;control-e
BS              EQU     $08     ;backspace

TAB             EQU     $09     ;tab
LF              EQU     $0A     ;line feed
FF              EQU     $0C     ;form feed
CR              EQU     $0D     ;carriage return

CTR_P           EQU     $10     ;control-p
CTR_R           EQU     $12     ;control-r
CTR_S           EQU     $13     ;control-s
CTR_U           EQU     $15     ;control-u
CTR_X           EQU     $18     ;control-x
CTR_Z           EQU     $1A     ;control-z (end-of-file mark)
DEL             EQU     $7F     ;rubout
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
                DB      BS,   CAPS, 0x00, 0x00, 0x08
                DB      DEL,  TAB,  0x0c, 0x0b, 0x0a
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
                DB      BS,   CAPS, 0x00, 0x00, 0x08
                DB      DEL,  TAB,  0x0c, 0x0b, 0x0a
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
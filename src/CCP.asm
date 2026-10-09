;    ENHANCED CP/M CONSOLE COMMAND PROCESSOR (CCP) for CP/M REV. 2.2
;    
;    Origianl CCP disassembled by ????
;    Original CCP disassembled further by RLC
;    Original CCP commented by RLC
;    Modified and generalized by John Thomas (6/20/81)
;    Macros expanded and condtional for terminals which
;    use form feeds to clear the screen added by
;    Bo McCormick (6/27/81)
;
;    Converted to Z80-style mnemonics and slightly modified
;    for Z80 Playground by John Squires, January 2021
;    
;    ASSEMBLING THIS CCP FOR CP/M 2.2 *****
;    You    must be using a Z-80 processor to run this
;    program. You do not need MAC or any macro library.
;    If you add further modifications to the program
;    the    total size of the program must not exceed
;    2K in order to fit under the BDOS. (Unless you change the CCP_START location!)
;    Code must be added to use the Clear Screen command with
;    your terminal, if it is not VT100 compatible.
;    Also, there is a provision for a boot-up command. Place
;    the    command to be executed on cold and warm starts at 
;    location CBUFF.
;    
;    NON-STANDARD FEATURES *****
;    The non-standard features incorporated into this CCP are:
;    A.  The Command-Search Hierarchy, as follows --
;        1.    Scan for a CCP-resident command and execute it if found    
;        2.    If not CCP-resident, look for a .COM file on disk
;        3.    If the .COM file is not found in the current user area and the current user area is not USER 0,
;            USER 0 is selected and scanned for the file
;        4.    If the .COM file is not found on the current logged-in disk drive, drive A: is selected
;            and scanned for the file
;    B.    The DIR Command no longer prints the current drive spec at    the beginning of each line
;    C.    The TYPE Command pages its output
;    D.    A LIST Command now exists which is like TYPE but does not page and sends its output to the LST: device
;    E.    A CLS (Clear Screen) Command now exists which clears the screen of the terminal
;    F.    The user number is printed as part of the command prompt;
;        the prompt is now du>, such as A0> and A15>
;    G.    Z80-code is used throughout to reduce the size of the CCP
;        and give room to implement the additional functions
;    H.    The input line buffer has been reduced in size to 100 bytes
;    I.    The ERA Command displays the names of the files it is to erase    
;    J.    The DIR Command has an additional special form of "DIR @"
;        which displays all files (both non-system and system),
;        while "DIR" displays just the non-system files
;    K.    The Directory Display no longer displays the disk name at
;        the beginning of each line and it now includes a '.' between
;        the file name and file type (FILENAME.TYP)
;    L.    The SUBMIT File Facility now expects the $$$.SUB file to be
;        on the currently logged-in disk (as opposed to always A:)
;    M.    The Command Line Prompt is now '$' if the command comes from
;        a $$$.SUB file and '>' if the command comes from the user;
;        also, the '>' is not printed until all preprocessing is completed
;    N.    The TYPE and LIST Commands mask the MSB of each byte, so that
;        files created by editors such as EDIT80 are "printable"
;    O.    An EXIT Command ends DP/M and returns to NextZXOS, through
;        function $00 of DPM control in DP/M's BIOS jump table
;        (BIOS_CONTROL_OFS)

;    DP/M ASSEMBLY *****
;    This file is assembled on its own into CCP.COM, an image of the CCP at
;    CCP_A. The kernel reads CCP.COM from its install folder at every
;    cold and warm boot, so another CCP.COM can replace it. Any CCP.COM must
;    start with the two jumps at ENTRY: the BIOS enters at CCP_A+3 with the
;    drive and user in C, and the file must fit below the BDOS at BDOS_A.

    DEVICE zxspectrumnext
    OPT reset --zxnext --syntax=abfw
    CSPECTMAP CCP.map

    INCLUDE "inc/addresses.asm"                 ; CCP_A, TBUFF_A
    INCLUDE "inc/constants.asm"                 ; TRUE, FALSE
    INCLUDE "inc/ascii.asm"                     ; KERNEL_KEYBOARD.CR, LF, ESC

        ORG    CCP_A        ; START OF CCP IN MEMEORY IN YOUR SYSTEM
        
ccp_start:
        DISPLAY "ccp ORG\t:\t",/H,$
        
        MODULE CCP
NLINES:     EQU    consoleRows  ; NUMBER OF LINES ON CRT SCREEN
H19:        EQU    FALSE        ; USING HEATH H19/H89 TERMINAL
HAZE:       EQU    FALSE        ; USING HAZELTINE 1500 TERMINAL
FFTERM:     EQU    TRUE         ; USING TERMINAL THAT RESPONDS TO 0CH
        
WBOOT:      EQU    0000H        ; CP/M WARM BOOT ADDRESS

UDFLAG:     EQU    0004H        ; USER NUMBER IS IN HIGH NYBBLE, DISK IN LOW

BDOS:       EQU    0005H        ; BDOS FUNCTION CALL ENTRY PT

TFCB:       EQU    005CH        ; DEFAULT FCB BUFFER

TPA:        EQU    0100H        ; BASE OF TPA
        
        
        
;-----------------------------------------------------------------------------
; -- CCP    Entry point
;-----------------------------------------------------------------------------
        
ENTRY:    
        jp      CCP
        jp      CCP1
        
;    INPUT    COMMAND LINE AND DEFAULT COMMAND

BUFLEN          EQU    100        ; MAXIMUM BUFFER LENGTH
MBUFF:    
                db    BUFLEN        ; 100 bytes of input buffer
                
CBUFF:    
        DEFB    3        ;<== NUMBER OF VALID CHARS IN COMMAND LINE
        
; Character input buffer, usually pointed to by CMDINBUFF_PTR
CIBUFF:    
        db      'DIR '          ;<== DEFAULT (COLD BOOT) COMMAND
        db      '    '
        db      '    '
        db      '    '
CIBUF:    
        ds      BUFLEN-15         ; 16Char (from CIBUFF) plus this  = total command buffer
STACK_BOTTOM:
        ds      20              ; Stack size
STACK:                          ; Top of CPP stack

; Pointer to command input buffer
CMDINBUFF_PTR:    
        DEFW    CIBUFF
CIPTR:    
        DEFW    CIBUF        ;CURRENT PNTR
        
;    
;    I/O UTILITIES
;    
        
;    OUTPUT <SP>
SPACER:    
        ld      a, ' '          ; Load accumilator with A, and fall through
CONOUT:                         ; KERNEL.BDOS_C_WRITE                     ;EQU 2        02
        push    bc
        push    hl
        ld      c, $02
        ; Fall through to OUTPUT
OUTPUT:
        ld      e, a
        call    BDOS
        pop     hl
        pop     bc
        ret

;    CALL    BDOS AND SAVE BC
BDOSB:    
        push    bc
        call    BDOS
        pop     bc
        ret
        
;    OUTPUT CHAR IN REG A TO LIST DEVICE
LSTOUT:    
        PUSH    BC
        PUSH    HL
        LD    C,05H
        DEFB    18H
        DEFB    OUTPUT-$-1 AND 0FFH
        
;    OUTPUT <CRLF>
CRLF:    
        ld      a, KERNEL_KEYBOARD.CR
        call    CONOUT
        ld      a, KERNEL_KEYBOARD.LF
        jr      CONOUT
        
; Print null terminated string pointed to by return address after a CRLF
PRINT:    
        ex      (sp), hl        ; Get Return address into HL
        push    af              ; Save AF on stack
        call    CRLF
        call    .string_at_hl
        pop     af              ; GET FLAGS
        ex      (sp), hl        ; Push HL, which is StringNULL+1, back as return
        ret
        
;  Print null terminated string pointed to by HL
.string_at_hl:    
        ld      a, (hl)         ; Get next char from string
        inc     hl              ; Increment pointer in string
        or      a               ; Cheap zero check
        ret     z               ; ...Yes, zero, end of string, return
        call    CONOUT          ; Print Char in A
        jr      .string_at_hl
        

        ; dw KERNEL.BDOS_A_READ                      ;EQU 3        03
        ; dw KERNEL.BDOS_A_WRITE                     ;EQU 4        04
        ; dw KERNEL.BDOS_L_WRITE                     ;EQU 5        05
        
        ; dw KERNEL.BDOS_IO_GET                      ;EQU 7        07
        ; dw KERNEL.BDOS_IO_SET                      ;EQU 8        08
        ; dw KERNEL.BDOS_C_READSTR                   ;EQU 10       0A
        ; dw KERNEL.BDOS_C_STAT                      ;EQU 11       0B
        ; dw KERNEL.BDOS_S_BDOSVER                   ;EQU 12       0C
        
        ; dw KERNEL.BDOS_F_RENAME                    ;EQU 23       17
        ; dw KERNEL.BDOS_DRV_LOGINVEC                ;EQU 24       18
        ; dw KERNEL.BDOS_DRV_GET                     ;EQU 25       19
        ; dw KERNEL.BDOS_F_DMAOFF                    ;EQU 26       1A
        ; dw KERNEL.BDOS_DRV_ALLOCVEC                ;EQU 27       1B
        ; dw KERNEL.BDOS_DRV_SETRO                   ;EQU 28       1C
        ; dw KERNEL.BDOS_DRV_ROVEC                   ;EQU 29       1D
        ; dw KERNEL.BDOS_F_ATTRIB                    ;EQU 30       1E
        ; dw KERNEL.BDOS_DRV_DPB                     ;EQU 31       1F
        
        ; dw KERNEL.BDOS_F_READRAND                  ;EQU 33       21
        ; dw KERNEL.BDOS_F_WRITERAND                 ;EQU 34       22
        ; dw KERNEL.BDOS_F_SIZE                      ;EQU 35       23
        ; dw KERNEL.BDOS_F_RANDREC                   ;EQU 36       24
        ; dw KERNEL.BDOS_DRV_RESET                   ;EQU 37       25*
        
RESET:                      ; KERNEL.BDOS_DRV_ALLRESET                ;EQU 13       0D
        ld      c, $0d
        jp      BDOS
;
LOGIN:                          ; KERNEL.BDOS_DRV_SET                     ;EQU 14       0E
        ld      e, a
        ld      c, $0e
        jp      BDOS
;
OPENF:    
        XOR    A
        LD    (FCBCR),A
        LD    DE,FCB_DN         ; Fall through to OPEN
;
OPEN:                           ; KERNEL.BDOS_F_OPEN                      ;EQU 15       0F
        LD      c, $0F                      ; Fall through to GRBDOS
;
GRBDOS:                         ; Turns $ff (error) into 0, turns (zero success) into 1 on return
        call    BDOS
        inc     a               ; SET ZERO FLAG FOR ERROR RETURN
        ret
;
CLOSE:                      ; KERNEL.BDOS_F_CLOSE                     ;EQU 16       10 
        ld      c, $10
        jr      GRBDOS
;
SEARF:    
        ld      de, FCB_DN  ; SPECIFY FCB
;
SEAR1:                      ; KERNEL.BDOS_F_SFIRST                    ;EQU 17       11
        ld      c, $11
        jr      GRBDOS
        ; jp      BDOS
;
SEARN:                      ; KERNEL.BDOS_F_SNEXT                     ;EQU 18       12
        ld      c,$12
        jr      GRBDOS
;
DELETE:                     ; KERNEL.BDOS_F_DELETE                    ;EQU 19       13
        ld      c,$13
        jp      BDOS
;
READF:    
        LD    DE,FCB_DN     ; FALL THRU TO READ
;
READ:                       ; KERNEL.BDOS_F_READ                      ;EQU 20       14
        ld      c, $14
;
GOBDOS:    
        call    BDOSB       ; PRESERVE B
        or      a
        ret
;
WRITE:                      ; KERNEL.BDOS_F_WRITE                     ;EQU 21       15
        ld      c, $15
        jr      GOBDOS
;
CREATE:                     ; KERNEL.BDOS_F_MAKE                      ;EQU 22       16
        ld      c, $16
        jr      GRBDOS
;
GETUSR:                     ; KERNEL.BDOS_F_USERNUM                   ;EQU 32       20
        ld      e, $FF          ; When calling SET with 255 in E, we GET instead
SETUSR:                     ; KERNEL.BDOS_F_USERNUM                   ;EQU 32       20
        ld      c, $20          ; Set current User Number to value in E (or GET)
        jp      BDOS
        
;    
;    END    OF BDOS FUNCTIONS
;    

;    
;    CCP    UTILITIES
;    
        
;    DEFL    USER/DISK FLAG TO CURRENT USER AND DEFAULT DISK
SETUD:    
        call    GETUSR              ; Get current user number
        add     a, a                ; x2 (And shift left 4)
        add     a, a                ; x4 (which is same as A+A 4 times)
        add     a, a                ; x8 (Which leaves the resultant value)
        add     a, a                ; x16 (In the top nybble, and bottom = 0b000)
        ld      hl, TDRIVE          ; Point at current drive number
        or      (hl)                ; Mask with usernumber
        ld      (UDFLAG), A         ; Save User/Drive flags
        ret    
        
;    DEFL    USER/DISK FLAG TO USER 0 AND DEFAULT DISK
SETU0D:    
        ld      a, (TDRIVE)         ; SET USER 0/DEFAULT DISK
        ld      (UDFLAG), a         ; SET USER/DISK NUMBER
        ret
        
; Convert any character in A to upper-case
A_TO_UCASE:    
        cp      'a'             ; Compare to lower case a ASCII val
        ret     c               ; Return if carry, i.e., lower than 97ASCII
        cp      'z'+1           ; Compare to Lower case z ASCII val
        ret     nc              ; Return is no-carry,  i.e.., higher than ASCII 122
        and     $5f             ; Capitalise - and ASCII with 0b01011111, ie, drop bit5
        ret
        
; Read next line to be processed by CCP (Console, or submitfile) and CAPITALISE it.
READBUF:
        ld      a, (SUBEXEC)                    ; Is there a submit file currently being parsed?
        or      a                               ; Fast zero check
        jr      z, .read_console                ; ...0=NO...Get console input

        ld      de, SUBFCB     ; OPEN $$$.SUB
        call    OPEN
        jr      z, .read_console                          ; ERASE $$$.SUB IF END OF FILE AND GET CMND
        
        LD    A,(SUBFRC)    ; GET VALUE OF LAST RECORD IN FILE
        DEC    A        ; PT TO NEXT TO LAST RECORD
        LD    (SUBFCR),A    ; SAVE NEW VALUE OF LAST RECORD IN $$$.SUB
        LD    DE,SUBFCB    ; READ LAST RECORD OF SUBMIT FILE
        CALL    READ
        DEFB    20H
        DEFB    .read_console-$-1 AND 0FFH; ABORT $$$.SUB IF ERROR IN READING LAST REC
        LD    DE,CBUFF    ; COPY LAST RECORD (NEXT SUBMIT CMND) TO CBUFF
        LD    HL,TBUFF_A  ;   FROM TBUFF
        LD    BC,BUFLEN    ; NUMBER OF BYTES
        ldir
        LD    HL,SUBFS2    ; PT TO S2 OF $$$.SUB FCB
        LD    (HL),0        ; SET S2 TO ZERO
        INC    HL        ; PT TO RECORD COUNT
        DEC    (HL)        ; DECREMENT RECORD COUNT OF $$$.SUB
        LD    DE,SUBFCB    ; CLOSE $$$.SUB
        CALL    CLOSE
        DEFB    28H
        DEFB    .read_console-$-1 AND 0FFH; ABORT $$$.SUB IF ERROR
        LD    A,'$'        ; PRINT SUBMIT PROMPT
        CALL    CONOUT
        LD    HL,CIBUFF    ; PRINT COMMAND LINE FROM $$$.SUB
        CALL    PRINT.string_at_hl
        CALL    BREAK        ; CHECK FOR ABORT (ANY CHAR)
        jr      z, .capitialise_buffer
        CALL    SUBKIL        ; KILL $$$.SUB IF ABORT
        JP    RESTART        ; RESTART CCP
.read_console:                  ; Read input from user/console
        call    SUBKIL              ; If $$$.SUB exists, delete it
        call    SETUD               ; Set current User+Drive mask in lower memory
        ld      a, '>'              ; Processing done, end of prompt...
        call    CONOUT              ; ...print it!
        ld      c, $0a              ; Load C == function number. OA = KERNEL.BDOS_C_READSTR  
        ld      de, MBUFF           ; DE = Input buffer Length, +1 = current length, +2 text starts
        call    BDOS
        call    SETU0D              ; Set User 0 on default disk number
        ; fall through into 
        
; Capitalize null termianted string in CBUFF
.capitialise_buffer:    
        ld      hl, CBUFF           ; Point at user's entered command...
        ld      b, (HL)             ; ...First byte is buffer-len
.next_char:
        inc     hl                  ; Move pointer along 1, to next valid char
        ld      a, b                ; Remaining chars in buffer into A
        or      a                   ; Cheap zero check
        jr      z, .end_buff
        ld      a, (hl)             ; Get char pointed at by HL
        call    A_TO_UCASE          ; Capitalise, if lower case
        ld      (hl), a             ; Store char, incase it was changed
        dec     b                   ; Reduce buffer len counter
        jr      .next_char          ; And loop
.end_buff:
        ld      (hl), a             ; Store terminating character (NULL)
        ld      hl, CIBUFF          ; Reset Command Line pointer to first char
        ld      (CMDINBUFF_PTR), hl        ; Set CommandInputBufferPointer to CIBUFF
        ret
        
; Check for a character pending from the console, return with zeroflag if none
BREAK:
        push    de                  ; Save DE
        ld      e, $ff              ; Return char & don't echo; zero if none is available
        ld      c, $06              ; KERNEL.BDOS_C_RAWIO  ;EQU 6        06
        call    BDOSB
        pop     de
        and     $7f                 ; Mask ou the MSB, while setting zero flag at same time
        ret
        
; Get the currently selected drive number, returned in A
GETDRV:    
        ld    c, $19
        jp    BDOS
        
; Set the DMA pointer to default
DEFDMA:    
        ld      de, TBUFF_A         ; 80H=TBUFF_A
        ; Fallthrough to...
        
; Set the DMA pointer to value in DE
DMASET:
        ld      c, $1A
        jp      BDOS
        
;    CHECK    FOR SUBMIT FILE IN EXECUTION AND ABORT IT IF SO
SUBKIL:
        ld      hl, SUBEXEC         ; See if a SUBmit FILE is currently being exec'ed
        ld      a, (hl)
        or      a                   ; "Cheap" cp 0,
        ret     z                   ; 0=NO
        ld      (hl), 0             ; ABORT SUBMIT FILE
        ld      de, SUBFCB          ; DE == subfile FCB
        jp      DELETE
        
; Invalid Command - print it out with a prompt as hint to user
INVALID_COMMAND:
        call    CRLF                ; Print NewLine
        ld      hl, (CIPTR)         ; Set pointer to start of command line buffer
.loop:    
        ld      a, (hl)             ; Get Char
        cp      ' '                 ; Is character a space?
        jr      z, .print_qmark     ; ...Yes, print question mark
        or      a                   ; Cheap zero check
        jr      z, .print_qmark     ; ...Yes, print question mark
        push    hl                  ; Save pointer to character that generated error
        call    CONOUT              ; print error character
        pop     hl                  ; Restore pointer
        inc     hl                  ; Move pointer to next character
        jr      .loop
.print_qmark:    
        ld      a, '?'              ; Print '?'
        call    CONOUT
        call    SUBKIL              ; TERMINATE ACTIVE $$$.SUB IF ANY
        jp      RESTART              ; Restart CCP
        
; Check to see if DE points to a Delimiter (One of NULL, Space, or = _ . : ; < >) set zeroflag if so
SEARCHDELIM:    
        ld      a, (de)
        or      a                   ; 0=Delimiter
        ret     z                   ; ...Found
        cp      ' '                 ; Compare to character
        jr      c, INVALID_COMMAND
        ret     z                   ; ...Found
        cp      '='                 ; Compare to character
        ret     z                   ; ...Found
        cp      '_'                 ; Compare to character
        ret     z                   ; ...Found
        cp      '.'                 ; Compare to character
        ret     z                   ; ...Found
        cp      ':'                 ; Compare to character
        ret     z                   ; ...Found
        cp      ';'                 ; Compare to character
        ret     z                   ; ...Found
        cp      '<'                 ; Compare to character
        ret     z                   ; ...Found
        cp      '>'                 ; Compare to character
        ret
        
; Search a string for first non-blank char, or EoString (NULL)
SBLANK:    
        ld      a, (de)             ; A = char pointed by DE
        or      a                   ; Is it a zero-check?
        ret     z                   ; ...EoString found, bail
        cp      ' '                 ; Or is it s space?
        ret     nz                  ; ...Not a Space found, bail
        inc     de                  ; Increment pointer
        jr      SBLANK              ; Try again
        

; Add  A to HL - so adds 8bit to 16bit value.
ADDAHL:    
        add     a, l
        ld      l, a
        ret     nc
        inc     h
        ret
        
; Parse commandline from DMABUF pointer, extract token and place into FCB_DN.
; Format FCB_DN if the token appears to be a filename (FILENAME.EXT),
; On input CMDINBUFF_PTR points to character at which to start scan;
; On output CMDINBUFF_PTR points to character at which to continue parsing,
;   z flag set if '?' is in the token.
PARSECMD:
        xor     a                   ; Start at drive/user spec byte of FCB
.scan1:
        ld      hl, FCB_DN          ; Destination of parsed command
        call    ADDAHL              ; Add A (offset) to HL (fcb) pointer
        push    hl 
        xor     a                   ; Cheap Set A=0
        ld      (TEMP_DR), a        ; Set tempdrive number to default, 0.
        ld      hl, (CMDINBUFF_PTR)        ; HL point to next char in commandline
        ex      de, hl              ; Switch char ptr into DE
        call    SBLANK              ; Skip to first non-blank, or EoLine
        ld      (CIPTR), de         ; CIPTR now points to first char, or EoLine
        pop     hl                  ; Restore FCB_DN into HL
        push    hl                  ; and save it again
        ld      a, (de)             ; Get char DE is pointing at?
        or      a                   ; Is it Null?  ( Cheap zero check )
        jr      z, .defaultdrive    ; ...Yes
        sbc     a, 'A'-1            ; Convert letter to drive number, just in case
        ld      b, a                ; ...and store in B
        inc     de                  ; Move pointer to point at next character
        ld      a, (de)             ; Get character pointed at
        cp      ':'                 ; Is it a colon?
        jr      z, .drivespec       ; ...Yes - This was a drive after all!
        dec     de                  ; ...Nope - restore pointer back one place
.defaultdrive:
        ld      a, (TDRIVE)         ; Set 1ST byte of FCB_DN as default drive
        ld      (hl), a
        jr      .filename
.drivespec:
        ld      a, b                ; Copy B into A
        ld      (TEMP_DR), a        ; Set temporary drive from A
        ld      (hl), b             ; Set 1st byte of FCB_DN as specified drive
        inc     de                  ; Point to first byte after ":" in command
.filename:
        ld      b, $08              ; Set B to max characters in a filename
.copynamechars:
        call    SEARCHDELIM         ; Does DE point to a delim? 
        jr      z, .fill_with_space ; ...Yes? Fill filename part with space.
        inc     hl                  ; Move pointer to next byte in FCB DiskNName
        cp      '*'                 ; Does it point to a wildcard?
        jr      nz, .save_char      ; ...No
        ld      (hl), '?'           ; Put '?' in FCB_DN & don't advance DE
        jr      .copynamechars_done
.save_char:
        ld      (hl), a             ; Save character in FCB_DiskName
        inc     de                  ; Move pointer to next char in command buffer
.copynamechars_done:
        djnz    .copynamechars      ; Loop if it's less than 8 chars
.scan8:
        call    SEARCHDELIM         ; 8 chars or more, now skip until next delim
        jr      z, .filedelim
        inc     de                  ; Move pointer to next char in commandline
        jr      .scan8
.fill_with_space:
        inc     hl                  ; Point to next byte in FCB DiskNo
        ld      (hl), ' '           ; Fill filename part with " "
        djnz    .fill_with_space
; EXTRA CT FILE TYPE FROM POSSIBLE FILENAME.TYP
.filedelim:
        ld      b, $03              ; Max chars in the filename extension
        cp      '.'                 ; Check if (DE) is '.'
        jr      nz, .full_with_space; ...No, decrease B, check zero & jump
        inc     de                  ; Move pointer in commandline along 1
.scan11:
        call    SEARCHDELIM         ; Find next delimiter
        jr      z, .full_with_space  ; Is Delim, copy extension
        inc     hl                  ; PT TO NEXT BYTE IN FCB DiskNo
        cp      '*'                 ; WILD?
        jr      nz, .copyextchars   ; 
        ld      (hl),'?'            ; Store '?' and don't increase pointer
        jr      .scan13
.copyextchars:
        ld      (hl), a             ; Store char in FCB DiskNo
        inc     de                  ; Inc pointer to next char in command line
.scan13:
        djnz    .scan11             ; ...No, decrease B and jump
.scan14:
        call    SEARCHDELIM         ; SKIP REST OF CHARS AFTER 3-CHAR TYPE TO
        jr      z, .wipe_stats      ;   DELIMITER
        inc     de
        jr      .scan14
.full_with_space:    
        inc     hl                  ; Increment string pointer
        ld      (hl), ' '           ; Set char at pointer to space
        djnz    .full_with_space    ; ...No, decrease B, check zero & jump
.wipe_stats:                        ; Fill EX, S1, S2, & RC with zeroes
        ld      b, 4                ; 4 byte counter
.fill_with_null:
        inc     hl                  ; Inc pointer to next byte in FCB DiskNo
                ; push af : push bc : push de : push hl 
                ; call CRLF : ld a, (hl) : call CONOUT : ld a, '_' : call CONOUT
                ; pop hl : pop de: pop bc : pop af
        ld      (hl), 0
        djnz    .fill_with_null     ; Decrease B and jump
            ; Scan Complete -- DE PTS TO DELIMITER BYTE AFTER TOKEN
        ex      de, hl              ; STORE PTR TO NEXT BYTE IN COMMAND LINE
        ld      (CMDINBUFF_PTR),HL
;    DEFL    ZERO FLAG TO INDICATE PRESENCE OF '?' IN FILENAME.TYP
        POP    HL        ; GET PTR TO FCB_DNIN HL
        LD    BC,11        ; SCAN FOR '?' IN FILENAME.TYP (C=11 BYTES)
.scan18:    
        INC    HL        ; PT TO NEXT BYTE IN FCB DiskNo
        LD    A,(HL)
        CP    '?'
        jr      nz, .scan19
        INC    B        ; B<>0 TO INDICATE '?' ENCOUNTERED
.scan19:    
        DEC    C        ; COUNT DOWN
        jr      nz, .scan18
        LD    A,B        ; A=B=NUMBER OF '?' IN FILENAME.TYP
        OR    A        ; SET ZERO FLAG TO INDICATE ANY '?'
        RET    
        
;    
;    CCP    BUILT-IN COMMAND TABLE AND COMMAND PROCESSOR
;    
; Number of built-in commands in the CCP
NUMCMDS:    EQU    9
; Number of unique characters to check for built-in commands (padded with spaces)
CMDS_LEN:    EQU    4

; CCP Built-in command names
CMDS_TBL:    
        db      'DIR '
        db      'ERA '
        db      'LIST'
        db      'TYPE'
        db      'SAVE'
        db      'REN '
        db      'USER'
        db      'CLS '
        db      'EXIT'
        
; CCP Built-in command function addresses
PROC_TBL:    
        dw      CMD_DIR
        dw      CMD_ERA
        dw      CMD_LIST
        dw      CMD_TYPE
        dw      CMD_SAVE
        dw      CMD_REN
        dw      CMD_USER
        dw      CMD_CLS
        dw      CMD_EXIT
        dw      RUN_COM             ; Not a built-in command, execute a .COM file
        
; Scan CMDS_TBL, on return A=Entry (0 to NUMCMDS-1) or NUMCMDS if not found (COM file)
CMD_BUILTIN:
        ld      hl, CMDS_TBL        ; Pointer to command table
        ld      c, 0                ; Offset into Command Table
.check_cmd
        ld      a, c                ; Check command number
        cp      NUMCMDS             ; Does it equal total number of commands?
        ret     nc
        ld      de, FCB_FN           ; Pointer to stored command-name
        ld      b, CMDS_LEN         ; Built-in command length (never longer than 8)
.check_char:    
        ld      a, (de)             ; Compare command to current table entry
        cp      (hl)
        jr      nz, .skip_cmd
        inc     de                  ; Increase pointer for user entry...
        inc     hl                  ; ...and for table entry
        djnz    .check_char
        ld      a, (de)             ; Make sure this is end of entered command too
        cp      ' '
        jr      nz, .next_cmd       ; ...Nope?
        ld      a, c                ; ...Yep, save command position in A
        ret
.skip_cmd:
        inc     hl                  ; Move to end of this command name, in table
        djnz    .skip_cmd
.next_cmd:
        inc    c        ; INCREMENT TABLE ENTRY NUMBER
        jr     .check_cmd
        
;    
;    CCP    STARTING POINTS
;    
        
; Start CCP without running the default commands
CCP1:
        xor     a                   ; SET NO DEFAULT COMMAND
        ld      (CBUFF), a
; Start CCP processing any default commands
CCP:
        ld      sp, STACK           ; RESET STACK
        push    bc
        ld      a, c                ; C=USER/DISK NUMBER (SEE LOC 4)
        rra                         ; Extract user number from it's nybble
        rra    
        rra    
        rra    
        and     $0F
        ld      e, a                ; SET USER NUMBER 
        call    SETUSR
                
        call    RESET               ; RESET DISK SYSTEM

        pop     bc
        ld      a, c                ; C=USER/DISK NUMBER (SEE LOC 4)
        and     $0f                 ; EXTRACT DEFAULT DISK DRIVE
        ld      (TDRIVE), a         ; SET IT
        call    LOGIN               ; LOG IN DEFAULT DISK

        ld      de, SUBFCB           ; CHECK FOR $$$.SUB ON CURRENT DISK
        call    SEAR1               ; "F_SFIRST"
        dec     a                   ; Adjust A to actual returned value  (SEARF/SEARN special case)
        cpl                         ; $ff=="Not Found", so flip all bits
	    ld	    (SUBEXEC), a        ; Save A, found-state (0=NO $$$.SUB)
        ld      a, (CBUFF)          ; Execute default command?
        or      a                   ; Set zero flag, if required
        jr      nz, RS1             ; ...0==Nothing in buffer==no exec

; Display commandline and get user input
RESTART:
        ld      sp, STACK           ; Reset the stack to our internal location
        call    CRLF                ; New line
        call    GETDRV              ; Load current drive-letter into A
        add     a, 'A'              ; Make ASCII
        call    CONOUT              ; ...and print it
        call    GETUSR              ; Load current user-number
        cp      10                  ; User number > 10?
        jr      c, .get_user_input
        sub     10                  ; Subtract 10 from usernumber
        push    af                  ; ...and keep a note of it
        ld      a, '1'              ; Print 'a'
        call    CONOUT
        pop     af                  ; restore actual usernumber
.get_user_input:
        add     a, '0'              ; Output actual digit in ASCII
        call    CONOUT
        call    READBUF             ; Load next line of input from either user or $$$.SUB
RS1:    call    DEFDMA              ; Point to input command line buffer (TBUFF, $0080 in base memory)
        call    GETDRV              ; Get default drive number
        ld      (TDRIVE),A          ; Write "Default Drive" to SET IT
        call    PARSECMD            ; Parse commandline
        call    nz, INVALID_COMMAND ; Command contains a "?"
        ld      a, (TEMP_DR)        ; Does command contain a drive letter?
        or      a                   ; Cheap zero check, NZ==YES
        jp      nz, RUN_COM         ; ...Yes? Execute the .COM file
        call    CMD_BUILTIN         ; Get command position in function table in A
        ld      hl, PROC_TBL        ; Execute function pointed to by A (CCP-RESIDENT OR COM)
        ld      e, a                ; Compute address offset into function table...
        ld      d, 0                ; ... by turning index into 16bit number
        add     hl, de              ; And increment the pointer table base address...
        add     hl, de              ; ...by this value, twice. (addresses are 16bit) 
        ld      a, (hl)             ; Cache low part off address (little endian, innit) in A
        inc     hl                  ; ...increment pointer, now points at high part of address
        ld      h, (hl)             ; Overwrite H with High part of address...
        ld      l, a                ; ...copy cached low part from A into L
        jp      (hl)                ; hl now pointer to function handler, so execute it.

;    
;    ERROR    MESSAGES
;    
PRINT_NOFILE:    
        call    PRINT        ; NO FILE MESSAGE
        db      'No Files',0
        ret
        
;    
;    MORE    CCP UTILITIES
;    
;    EXTRA    CT NUMBER FROM COMMAND LINE
NUMBER:    
        CALL    PARSECMD        ; PARSE NUMBER AND PLACE IN FCB_FN
        LD    A,(TEMP_DR)    ; TOKEN BEGIN WITH DRIVE SPEC (D:)?
        OR    A        ; ERROR IF SO
        JP    NZ, INVALID_COMMAND
        LD    HL,FCB_FN    ; PT TO TOKEN FOR CONVERSION
        LD    BC,11        ; B=ACCUMULATED VALUE, C=CHAR COUNT
NUM1:    
        LD    A,(HL)        ; GET CHAR
        CP    ' '        ; DONE IF <SP>
        DEFB    28H
        DEFB    NUM2-$-1 AND 0FFH
        INC    HL        ; PT TO NEXT CHAR
        SUB    '0'        ; CONVERT TO BINARY (ASCII 0-9 TO BINARY)
        CP    10        ; ERROR IF >= 10
        JP    NC, INVALID_COMMAND
        LD    D,A        ; DIGIT IN D
        LD    A,B        ; GET ACCUMULATED VALUE
        AND    0E0H        ; CHECK FOR RANGE ERROR (>255)
        JP    NZ, INVALID_COMMAND
        LD    A,B        ; NEW VALUE = OLD VALUE * 10
        RLCA    
        RLCA    
        RLCA    
        ADD    A,B        ; CHECK FOR RANGE ERROR
        JP    C, INVALID_COMMAND
        ADD    A,B        ; CHECK FOR RANGE ERROR
        JP    C, INVALID_COMMAND
        ADD    A,D        ; NEW VALUE = OLD VALUE * 10 + DIGIT
        JP    C, INVALID_COMMAND    ; CHECK FOR RANGE ERROR
        LD    B,A        ; SET NEW VALUE
        DEC    C        ; COUNT DOWN
        DEFB    20H
        DEFB    NUM1-$-1 AND 0FFH
        RET    
        
;    REST    OF TOKEN BUFFER MUST BE <SP>
NUM2:    
        LD    A,(HL)        ; CHECK FOR <SP>
        CP    ' '
        JP    NZ, INVALID_COMMAND
        INC    HL        ; PT TO NEXT
        DEC    C        ; COUNT DOWN CHARS
        DEFB    20H
        DEFB    NUM2-$-1 AND 0FFH
        LD    A,B        ; GET ACCUMULATED VALUE
        RET    

; Get the (A+C)th byte from the TBUFF temporary buffer, returned in A, uses HL
BYTE_AT_AC_IN_TBUFF:
        ld      hl, TBUFF_A         ; HL points to start at Temp Buffer
        add     a, c                ; Calculate relative offset
        call    ADDAHL              ; Add relative offset to start of buffer addr
        ld      a, (hl)             ; Get byte from buffer
        ret    
        
; Check if drive exists, and login if it does and isn't the default drive
SLOGIN:    
        xor     a                   ; Cheap a=0
        ld      (FCB_DN), A         ; Store 0 in CCP FCB, so "use default drive" for operations
        call    CHECKDRIVE          ; Check if drive is default or same
        ret     z                   ; Drive is same, return
        jp      LOGIN               ; Do drive login
        
;    CHECK    FOR SPECIFIED DRIVE AND LOG IN DEFAULT DRIVE IF SPECIFIED<>DEFAULT
DLOGIN:    
        call    CHECKDRIVE          ; Check if drive is default or same
        RET     Z                   ; ...Yes, abort!
        LD      A,(TDRIVE)          ; LOG IN DEFAULT DRIVE
        JP      LOGIN
        
; Do actual drive login, Z flag set at exit means routine aborted for some reason
CHECKDRIVE:    
        ld      a, (TEMP_DR)        ; Get the drive letter requested
        or      a                   ; Is it 0, ie current?
        ret     z                   ; ...Yes - then don't bother checking
        dec     a                   ; Is it 1?
        ld      hl, TDRIVE          ; Get temp drive address
        cp      (HL)                ; Compare 
        ret                         ; Return, let caller handle results
        
;    
;    Builtin function: DIR
;    
CMD_DIR:
        ld      a, $80              ; Set system bit only "attribs flag"
        push    af                  ; And stash it on the stack
        call    PARSECMD            ; Extract any extra tokens such as drive & name
        call    SLOGIN              ; Log in drive, if required
        ld      hl, FCB_FN          ; Get pointer to FCB FileName
        ld      a, (hl)             ; Get 1st char of the filename
        cp      ' '                 ; Is it a " "
        jr      z, .all_wildcard    ; ...Yes? Show all - all wildcards
        cp      '@'                 ; Is it a "@"
        jr      nz, .do_dir         ; ...No? Do directory. searching for specific file
        inc     hl                  ; Move pointer along
        ld      a, (hl)             ; Get next char, as it must be "@ "
        dec     hl                  ; But rewind the pointer first, for later
        cp      ' '                 ; Now, is that char a " "?
        jr      nz, .do_dir         ; ...Nope! Just a normal directory
        pop     af                  ; ...Yep - get "attribs flag" from the stack
        xor     a                   ; Unset the system bit (well, all bits really)
        push    af                  ; And stash the flag back on the stack
.all_wildcard:
        ld      b, 11               ; Total chars for filename and extention combined
.pad_wildcards:
        ld      (hl), '?'           ; Write the wildcard character to the buffer
        inc     hl                  ; Increment pointer address
        djnz   .pad_wildcards       ; Is B zero? If not decrement and do another wildcard
.do_dir:
        pop     af                  ; Get "attributes flag"
        call    .print_dir          ; Print the directory entry
        jp      RESTART_CCP              ; Restart CCP, which is already in memory, so fast
.print_dir:                     ; Print directory, if high bit of A is set System Files not printed
        ld      d, a                ; Store system-flag in D
        ld      e, 0                ; Set Column Counter to 0
        push    de                  ; Save system-flag and column counter
        call    SEARF               ; Search & get first entry from directory if found
        call    z, PRINT_NOFILE     ; ...Not found, print a friendly message and restart CCP
.print_loop:                    ; Print Selection Loop, A=Offset from Search function
        jr      z, .done            ; If zero flag, we're done printing
        dec     a                   ; Adjust A to actual returned value (SEARF/SEARN special case)
        rrca                        ; Convert number into TBUFF offset
        rrca
        rrca
        and     $60
        ld      c, a                ; C now offset into TBUFF entry
        ld      a, 10               ; +10 places into buffer, to get System File Attr
        call    BYTE_AT_AC_IN_TBUFF ; Get next char into A
        pop     de                  ; Restore System Mask bit from D...
        push    de                  ; ...and stash it again
        and     d                   ; Mask against byte from Directory Entry
        jr      nz, .break_check    ; Zero? Nope - Check for break
        pop     de                  ; Get entry counter, 
        ld      a, e                ; move E into A
        inc     e                   ; preemtively increment E
        push    de                  ; and save it back
        or      a                   ; Is this the first column?
        jr      nz, .check_eol      ; ...Nope? Check if it's last column?
.linewrap
        call    CRLF                ; ...Yep? Print a new line and prompt
        push    af
        push    bc
        call    GETDRV              ; Load current drive-letter into A
        add     a, 'A'              ; Make ASCII
        call    CONOUT              ; ...and print it
        pop     bc
        pop     af
.check_eol:
        cp      $04                 ; Is this the first column?
        jr      nz, .print_spacer   ; ...Nope? Output a spacer
        pop de : ld e, 0 : push de
        
.print_spacer:
        call    SPACER              ; Print a couple of spaces
        ld      a, ':'              ; And then a colon
        call    CONOUT
        call    SPACER              ; And the couple of spaces again
.print_filename:
        ld      b, $01              ; Point to first byte of filename
.print_next_char:
        ld      a, b                ; A==Offset into filename
        call    BYTE_AT_AC_IN_TBUFF ; Get next char into A
        and     $7f                 ; Mask out the MSB because of how FCB attrs work
.print_char:
        call    CONOUT              ; Print the char we loaded into A
        inc     b                   ; Bump the string length counter
        ld      a, b
        cp      12                  ; Did we reach 12 chars length?
        jr      nc, .break_check    ; ...Yep, continue to next file
        cp      09                  ; Did we get to end of filename part?
        jr      nz, .print_next_char; ...Nope, do next character
        LD      a, '.'              ; Now where a dot would be between name & ext
        CALL    CONOUT              ; Print the dot
        jr      .print_next_char    ; And then move along to next character
.break_check:
        call    BREAK               ; Did User press ESCAPE to abort listing?
        cp      $03                 ; Was it control C?
        jr      z, .break_notify    ; ...Yes, we're done
        cp      $1b                 ; Was it Escape?
        jr      z, .break_notify    ; ...Yes, we're done
        call    SEARN               ; Get next directory entry, if exists
        jr      .print_loop
.break_notify:
        call    CRLF
        call    PRINT
        db      "BREAK", 0
        call    CRLF
.done:
        pop     de                  ; Balance stack
        ret
        
;    
;    Builtin function: ERA
;    
CMD_ERA:
        call    PARSECMD                    ; Run the parser again, the the filespec in an FCB
        cp      $0b                         ; Is the filename entirely wildcards? (11x'?')
        jr      nz, .erase                  ; ...Nope! So do the deletes!
        call    PRINT
        db      'All (Y/N)?',0
        call    READBUF                     ; Get a buffered keyboard response
        ld      hl, CBUFF                   ; Check for <CR>
        DEC     (hl)
        jp      nz, RESTART                 ; Blank string == Just <CR> == Abort, restart CCP
        inc     hl                          ; Point to response byte
        ld      a, (hl)                     ; Get char pointed at
        cp      'Y'                         ; Said Yes, did ye?
        jp      nz, RESTART                 ; Nope! So do the restart CCP dance.
        inc     hl                          ; Point to thing after the Y
        ld      (CMDINBUFF_PTR), hl         ; Store pointer
.erase:    
        call    SLOGIN                      ; Make sure we've selected (Logged On) the correct disk
        ld      a, $80                      ; Don't delete files marked "SYSTEM" (examine top bit)
        call    CMD_DIR.print_dir           ; Print the directory of files that match to be deleted
        ld      de, FCB_DN                  ; DE points to our FCB driveblock
        call    DELETE                      ; BDOS Delete routine
        jp      RESTART_CCP                      ; REENTER CCP
        
;    
;    Builtin function: LIST
;    
CMD_LIST:    
        LD      A, $ff                      ; Enable Printer (not sure how we will handle printers yet)
        jr      CMD_TYPE.actual
        
;    
;    Builtin function: TYPE
;    
CMD_TYPE:
        xor     a                           ; Disable Printer (we don't support printers yet anyways!)
.actual:    
        ld      (PRINT_FLAG), a             ; Store the "Printer Enabled" flag, in case we ever find a use
        call    PARSECMD                    ; Extract the filename specification to the FCB_*
        jp      nz, INVALID_COMMAND         ; If there was any wildcards in our command, error out
        call    SLOGIN                      ; "Mount" required disk
        call    OPENF                       ; And open the file in the FCB
        jp      z, .invalid_command         ; Error opening file, so "invalid command"
        call    CRLF                        ; Print a newline before we start showing text
        call    .page_set                   ; Set line count before pausing
        ld      hl, type_char_count         ; Address of character counter
        ld      (hl), $ff                   ; Set "char counter"=255
        ld      b, 0                        ; Set tab counter to 0
.loop:
        ld      hl, type_char_count         ; Get address of char counter (again, on first loop)
        ld      a, (hl)                     ; Get number of chars in this row
        cp      $80                         ; Is it less than 80?
        jr      c, .TYPE2                   ; ...Yes! Print char
        push    hl                          ; Preserve char counter
        call    READF                       ; Read block from disk
        pop     hl                          ; Restore char counter
        jr      nz, .done                   
        xor     a                           ; RESET COUNT
        ld      (hl), a
.TYPE2:
        inc     (hl)                        ; Increment character count
        ld      hl, TBUFF_A                 ; Get address of text buffer
        call    ADDAHL                      ; Calculate offset addr (HL+A)
        ld      a ,(hl)                     ; Get next character
        and     $7f                         ; Mask out most significant bit
        cp      $1a                         ; EoF check (^Z)
        jp      z, RESTART_CCP              ; ...Yes! So Restart CCP
        push    af                          ; ...No - preserve char
        ld      a, (PRINT_FLAG)             ; Use printer?
        or      a                           ; A=0?
        jr      z, .print_char              ; ...Yes, print the character
        pop     af                          ; Get preserved char back for printer
        cp      KERNEL_KEYBOARD.CR          ; RESET TAB COUNT?
        jr      z, .TABRST
        cp      KERNEL_KEYBOARD.LF          ; RESET TAB COUNT?
        jr      z, .TABRST
        cp      TAB                         ; TAB?
        jr      z, .LTAB
        CALL    LSTOUT                      ; LIST CHAR
        INC     B                           ; INCREMENT CHAR COUNT
        jr      .continue
.TABRST:    
        CALL    LSTOUT                      ; OUTPUT <CR>
        LD      B,0                         ; RESET TAB COUNTER
        jr      .continue
.LTAB:    
        LD      A,' '                       ; <SP>
        CALL    LSTOUT
        INC     B                           ; INCR POS COUNT
        LD      A,B
        AND     7
        jr      nz, .LTAB
        jr      .continue
.print_char:    
        pop     af                          ; Get preserved char back for screen
        push    af                          ; SAVE CHAR
        call    CONOUT                      ; TYPE CHAR
        POP     af
        cp      KERNEL_KEYBOARD.LF          ; PAGE ON <LF>
        call    Z, .pager                   ; COUNT LINES AND PAGE
.continue:    
        call    BREAK                       ; CHECK FOR ABORT
        jr      z, .loop                    ; CONTINUE IF NO CHAR
        cp      'C'-'@'                     ; ^C?
        jp      Z, RESTART_CCP              ; RESTART IF SO
        cp      KERNEL_KEYBOARD.ESC         ; ESC?
        jp      Z, RESTART_CCP              ; RESTART IF SO
        jr      .loop
.done:    
        dec    a                        ; NO ERROR?
        jp     z,RESTART_CCP    ; RESTART CCP
        CALL    PRINT        ; PRINT READ ERROR MSG
        DEFB    'Read Error',0
.invalid_command:
        CALL    DLOGIN        ; LOG IN DEFAULT DRIVE
        JP    INVALID_COMMAND
        
;    
;    Paging routines used by "TYPE"
.pager:    
        LD    A,(type_line_count)    ; COUNT DOWN
        DEC    A
        LD    (type_line_count),A
        RET    NZ
        PUSH    HL        ; SAVE HL
.PAGER1:    
        LD    C,6        ; DIRECT CONSOLE I/O
        LD    E,0FFH        ; INPUT
        CALL    BDOSB
        OR    A        ; CHAR READY?
        jr      z, .PAGER1
        CP    'C'-'@'        ; ^C
        JP    Z, RESTART_CCP    ; RESTART CCP
        POP    HL        ; RESTORE HL
.page_set:    
        ld    a, NLINES-2           ; Scroll length = ScreenLen (NLINES) - 2
        ld    (type_line_count), a
        ret
        
;    
;    CCP    SAVE FUNCTION (SAVE)
;    
CMD_SAVE:    
        CALL    NUMBER        ; EXTRACT NUMBER FROM COMMAND LINE
        PUSH    AF        ; SAVE IT
        CALL    PARSECMD        ; EXTRACT FILENAME.TYPE
        JP    NZ, INVALID_COMMAND    ; MUST BE NO '?' IN IT
        CALL    SLOGIN        ; LOG IN SELECTED DISK
        LD    DE,FCB_DN   ; DELETE FILE IN CASE IT ALREADY EXISTS
        PUSH    DE
        CALL    DELETE
        POP    DE
        CALL    CREATE        ; MAKE NEW FILE
        DEFB    28H
        DEFB    SAVE3-$-1 AND 0FFH; ERROR?
        XOR    A        ; SET RECORD COUNT FIELD OF NEW FILE'S FCB
        LD    (FCBCR),A
        POP    AF        ; GET PAGE COUNT
        LD    L,A        ; HL=PAGE COUNT
        LD    H,0
        ADD    HL,HL        ; DOUBLE IT FOR HL=SECTOR (128 BYTES) COUNT
        LD    DE,TPA        ; PT TO START OF SAVE AREA (TPA)
SAVE1:    
        LD    A,H        ; DONE WITH SAVE?
        OR    L        ; HL=0 IF SO
        DEFB    28H
        DEFB    SAVE2-$-1 AND 0FFH
        DEC    HL        ; COUNT DOWN ON SECTORS
        PUSH    HL        ; SAVE PTR TO BLOCK TO SAVE
        LD    HL,128        ; 128 BYTES PER SECTOR
        ADD    HL,DE        ; PT TO NEXT SECTOR
        PUSH    HL        ; SAVE ON STACK
        CALL    DMASET        ; SET DMA ADDRESS FOR WRITE (ADDRESS IN DE)
        LD    DE,FCB_DN   ; WRITE SECTOR
        CALL    WRITE
        POP    DE        ; GET PTR TO NEXT SECTOR IN DE
        POP    HL        ; GET SECTOR COUNT
        DEFB    20H
        DEFB    SAVE3-$-1 AND 0FFH; WRITE ERROR?
        DEFB    18H
        DEFB    SAVE1-$-1 AND 0FFH; CONTINUE
SAVE2:    
        LD    DE,FCB_DN   ; CLOSE SAVED FILE
        CALL    CLOSE
        INC    A        ; ERROR?
        DEFB    20H
        DEFB    SAVE4-$-1 AND 0FFH
SAVE3:    
        CALL    PRINT
        DEFB    'No Space',0
SAVE4:    
        CALL    DEFDMA        ; SET DMA TO 0080
        JP    RESTART_CCP        ; RESTART CCP
        
;    
;    CCP    RENAME FILE FUNCTION (REN)
;    
CMD_REN:    
        CALL    PARSECMD        ; EXTRACT FILE NAME
        JP    NZ, INVALID_COMMAND    ; ERROR IF ANY '?' IN IT
        LD    A,(TEMP_DR)    ; SAVE CURRENT DEFAULT DISK
        PUSH    AF
        CALL    SLOGIN        ; LOG IN SELECTED DISK
        CALL    SEARF        ; LOOK FOR SPECIFIED FILE
        DEFB    28H
        DEFB    REN0-$-1 AND 0FFH; CONTINUE IF NOT FOUND
        CALL    PRINT
        DEFB    'File Exists',0
        jr      RENRET
REN0:    
        LD    HL,FCB_DN   ; SAVE NEW FILE NAME
        LD    DE,FCBDM
        LD    BC,16        ; 16 BYTES
        ldir
        LD    HL,(CMDINBUFF_PTR)    ; GET PTR TO NEXT CHAR IN COMMAND LINE
        EX    DE,HL        ; ... IN DE
        CALL    SBLANK        ; SKIP TO NON-BLANK
        CP    '='        ; '=' OR UNDERSCORE OK
        DEFB    28H
        DEFB    REN1-$-1 AND 0FFH
        CP    5FH
        DEFB    20H
        DEFB    REN4-$-1 AND 0FFH
REN1:    
        EX    DE,HL        ; PT TO CHAR AFTER '=' OR UNDERSCORE IN HL
        INC    HL
        LD    (CMDINBUFF_PTR),HL    ; SAVE PTR TO OLD FILE NAME
        CALL    PARSECMD        ; EXTRACT FILENAME.TYP TOKEN
        DEFB    20H
        DEFB    REN4-$-1 AND 0FFH; ERROR IF ANY '?'
        POP    AF        ; GET OLD DEFAULT DRIVE
        LD    B,A        ; SAVE IT
        LD    HL,TEMP_DR    ; COMPARE IT AGAINST CURRENT DEFAULT DRIVE
        LD    A,(HL)        ; MATCH?
        OR    A
        DEFB    28H
        DEFB    REN2-$-1 AND 0FFH
        CP    B        ; CHECK FOR DRIVE ERROR
        LD    (HL),B
        DEFB    20H
        DEFB    REN4-$-1 AND 0FFH
REN2:    
        LD    (HL),B
        XOR    A
        LD    (FCB_DN),A    ; SET DEFAULT DRIVE
        LD    DE,FCB_DN   ; RENAME FILE
        LD    C,17H        ; BDOS RENAME FCT
        CALL    BDOS
        INC    A        ; ERROR? -- FILE NOT FOUND IF SO
        DEFB    20H
        DEFB    RENRET-$-1 AND 0FFH
REN3:    
        call    PRINT_NOFILE        ; PRINT NO FILE MSG
RENRET:    
        JP    RESTART_CCP        ; RESTART CCP
REN4:    
        CALL    DLOGIN        ; LOG IN DEFAULT DRIVE
        JP    INVALID_COMMAND
        
;    
;    CCP    SET USER NUMBER FUNCTION
;    
MAXUSR:    EQU    15        ; MAXIMUM USER AREA ACCESSABLE
CMD_USER:    
        call    NUMBER        ; EXTRACT USER NUMBER FROM COMMAND LINE
        cp      MAXUSR+1    ; ERROR IF >= MAXUSR
        jp      NC, INVALID_COMMAND
        ld      E,A        ; PLACE USER NUMBER IN E
        ld      A,(FCB_FN)    ; CHECK FOR PARSE ERROR
        cp      ' '        ; <SP>=ERROR
        jp      Z, INVALID_COMMAND
        call    SETUSR        ; SET SPECIFIED USER
.restart:
        jp      RESTART_CCP.drive_changed        ; RESTART CCP (NO DEFAULT LOGIN)
        

; Send VT100 escape sequences to clear screen to terminal driver
CMD_CLS:    
        ld      hl, CLS_STR
        call    PRINT.string_at_hl
        jr      CMD_USER.restart                 ; RESTART CCP (NO DEFAULT LOGIN)
CLS_STR:
        db      KERNEL_KEYBOARD.ESC, "[H"   ; Move cursor home
        db      KERNEL_KEYBOARD.ESC, "[J", 0 ; Clear to end of screen

; End DP/M and return to NextZXOS through function $00 of DPM control in the
; BIOS jump table, found from the warm boot address at $0001, as EXIT.COM does
CMD_EXIT:
        ld      hl, (REBOOT_A+1)    ; The BIOS warm boot entry
        ld      de, BIOS_CONTROL_OFS
        add     hl, de
        ld      c, d                ; D = 0: function $00, exit
        jp      (hl)                ; Does not return
        ASSERT  BIOS_CONTROL_OFS < 256
        
;    
;    NOT    CCP-RESIDENT COMMAND -- PROCESS AS TRANSCIENT
;    
RUN_COM:
        call    GETUSR              ; Get the current User Number
        ld      (TMPUSR), A         ; And stash it for later ref
        ld      (TSELUSR), A        ; And in the Temp Selected User
        ld      A, (FCB_FN)         ; Load A with the first character of the FCB FileName
        cp      ' '                 ; Was it a space?
        jr      nz, .check_error    ; ...Nope. So Transient or "Not Found" Error
        ld      A, (TEMP_DR)        ; Get Drive Spec, current drive
        or      A                   ; Zero == Blank
        jp      Z, RESTART_CCP.drive_changed; We've set the new drive, now do the restart routine
        dec     A                   ; Decrement drive number, for absolute (A=0) not relative (A=1)
        ld      (TDRIVE), A         ; Set the new drive letter as the current default drive
        call    SETU0D              ; After a drive change, we default to user 0
        call    LOGIN               ; "Mount" the drive/virtual drive folder
        jr      CMD_USER.restart    ; Reroll CCP, drive already set, pointer to commandline
.check_error:    
        ld      A, (FCB_FT)         ; Get the FCB Filetype
        cp      ' '                 ; Is it a space? because Transients get called without an extension
        jp      nz, INVALID_COMMAND ; ...No! So can't be a transient (aka executable) therefore an error
.loadfile:
        call    SLOGIN              ; Log in the requested drive as parsed from command
        ld      hl, COM_EXT         ; Point at the default transient extension (src)
        ld      de, FCB_FT          ; Point to the current FCB file extension (dest)
        ld      bc, 3               ; Number of bytes to copy
        ldir                        ; Do copy
        call    OPENF               ; FBC now wants "TRANSIENT".COM file, open it.
        jr      nz, .set_load_address
;    ERROR ROUTINE TO SELECT USER 0 IF ALL ELSE FAILS
        ld      a, (TSELUSR)        ; Get the previously stored selected user
        or      a                   ; Set flags to match new value of A
        jr      z, .select_a
        xor     a        ; SELECT USER 0
        ld      e, a
        ld      (TSELUSR),A    ; RESET TEMPORARY USER NUMBER
        call    SETUSR
        jr      .loadfile
; Select A drive, and attempt to load command again
.select_a:
        LD      HL,TEMP_DR    ; GET DRIVE FROM CURRENT COMMAND
        XOR     A            ; A=0
        or      (HL)
        jp      nz, .error        ; ERROR IF ALREADY DISK A:
        LD      (HL),1        ; SELECT DRIVE a:
        jr      .loadfile
.set_load_address:
        ld      hl, TPA             ; Set start address of TPA space
.load_sector:
        push    hl                  ; Save address we're loading to
        ex      de, hl              ; ... Swap, so load address is now in DE
        call    DMASET              ; Point DMA at next sector in memory for TPA
        ld      de, FCB_DN          ; Load DE with Disk Name (drive letter)
        call    READ
        jr      nz, .load_complete
;                 push    hl
;                 push    af
;                 ; waste some time
;                 ld	hl,0
; .pause:
;                 dec	    hl
;                 ld	    a,h
;                 or	    l
;                 jp      nz,.pause
;                 pop     af
;                 pop     hl
        POP     HL                  ; GET ADDRESS OF NEXT SECTOR
        LD      DE,128              ; MOVE 128 BYTES PER SECTOR
        ADD     HL,DE               ; PT TO NEXT SECTOR IN HL
        LD      DE,ENTRY            ; WOULD THE NEXT SECTOR WRITE OVER THE CCP?
        LD      A,L                 ; COMPARE ADDRESS OF NEXT SECTOR (HL)
        SUB     E                   ;   TO START OF CCP (DE)
        LD      A, H
        SBC     A, D
        jr      nc, .load_error
        jr      .load_sector
.load_error:
        CALL    PRINT
        DEFB    'Bad Load',0
        jr      RESTART_CCP
.load_complete:
        pop     hl                  ; Load completed!
        dec     a
        jr      nz, .load_error
        call    RESETUSR            ; Revert usernumber
        call    DLOGIN              ; Login drive
        call    PARSECMD            ; Search commandline for parameters/token
        ld      hl, TEMP_DR         ; SAVE PTR TO DRIVE SPEC
        push    hl
        LD      A,(HL)              ; SET DRIVE SPEC
        LD      (FCB_DN),A
        LD      A,10H               ; Pointer offset for 2ed parameter
        CALL    PARSECMD.scan1      ; Scan for parameter, and save (offset 16)
        POP     HL        ; SET UP DRIVE SPECS
        LD      A,(HL)
        LD      (FCBDM), a
        xor     a                       ; Fast zero A
        ld      (FCBCR), a
        ld      de, TFCB                ; To: Default FCB
        ld      hl, FCB_DN              ; From: FCB Disk No
        ld      bc, 33                  ; Length
        ldir
        LD      hl, CIBUFF              ; HL = Address of Char Input Buffer
.find_params:
        ld      a, (hl)                 ; SKIP TO END OF 2ND FILE NAME
        or      a                       ; Null == End of Line
        jr      z, .copy_params
        cp      ' '                     ; Space == End of Token
        jr      z, .copy_params
        inc     hl
        jr      .find_params
.copy_params:                       ; Copy parameters into buffer
        ld      b, 0                    ; Character count
        ld      de, TBUFF_A+1           ; PT TO CHAR POS
.copy_params_char:
        LD      a, (hl)                 ; COPY COMMAND LINE TO TBUFF
        LD      (de), a
        or      a                       ; DONE IF ZERO
        jr      z, .exec
        inc     b        ; INCR CHAR COUNT
        inc     hl       ; PT TO NEXT
        inc     de
        jr      .copy_params_char
.exec:                              ; Run the freshly loaded transient (.COM) command
        ld      a, b                    ; Save character count
        ld      (TBUFF_A), a
	    call    CRLF                    ; Newline before we execute our command
        call    DEFDMA                  ; Set DMA to point to commandline buffer
        call    SETUD                   ; Set User/Disk
        call    TPA
        call    SETU0D                  ; Set default user+disk after return
        call    LOGIN                   ; Log in the disk
        jp      RESTART                 ; Restart CCP
        
;    TRANSCIENT LOAD ERROR
.error:
        CALL    RESETUSR    ; RESET CURRENT USER NUMBER
        ;   RESET MUST BE DONE BEFORE LOGIN
        CALL    DLOGIN        ; LOG IN DEFAULT DISK
        JP    INVALID_COMMAND
        
;    RESET    SELECTED USER NUMBER IF CHANGED
RESETUSR:    
        LD    A, (TMPUSR)    ; GET OLD USER NUMBER
        LD    E, A        ; PLACE IN E
        JP    SETUSR        ; RESET


;
; Static string extension for loading transient commands
COM_EXT:
        DEFB    'COM'
;
; Restart the CCP after setting/logging on the default drive
RESTART_CCP:
        call    DLOGIN          ; Log on the drive, and follow through
;    ENTRY    POINT FOR RESTARTING CCP WITHOUT LOGGING IN DEFAULT DRIVE
.drive_changed:
        call    PARSECMD        ; Extract token from commandline
        ld      A, (FCB_FN)     ; Get first character of it
        sub     ' '             ; Check it's a valid ASCII char
        ld      hl, TEMP_DR     ; Get pointer to Temp drive
        or      (hl)            ; Check if it's zero
        jp      nz, INVALID_COMMAND; If it's not, it's not valid
        jp      RESTART         ; Respin CCP with new drive spec
        
SUBEXEC:                                ; Is there currently a subfile executing?
        DEFB    0                       ; 0=$$$.SUB not in progress, 1==found, and processing
        
;    
;    FILE    CONTROL BLOCK (FCB), ONE
;    
SUBFCB:    
        db      0                       ; Disk Type
        db      '$$$     SUB'           ; Full Filename
        ;        nnnnnnnnxxx            ;  which is made up by
        ;        ^^^^^^^^+++---xxx      : Extension 
        ;        ++++++++------nnnnnnnn : Name
        db      0                       ; Extent Number (we don't really use these)
SUBFS1:    
        db      0                       ;S1
        
SUBFS2:    
        DEFS    1                       ;S2
SUBFRC:    
        DEFS    1                       ; Record Count
        DEFS    16                      ; Disk Group Map
SUBFCR:    
        DEFS    1                       ; File Record Count
        
;    
;    File Control Block - The FCB
;    
; FCB - Disk Name
FCB_DN:
        DEFS    1
; FCB - File Name
FCB_FN:
        DEFS    8
; FCB - File Type
FCB_FT:
        DEFS    3
; FCB - Extent Number
FCB_EX:
        db      0
; FCB - S1
FCB_S1:
        db      0 
; FCB - S2
FCB_S2:
        db      0
; FCB - Record Count
FCB_RC:
        db      0
; FCB - Disk Group Map
FCBDM:
        DEFS    16
; FCB - Current Record
FCBCR:
        DEFS    1
        

PRINT_FLAG:                 ; Printer enabled (0=No, $ff=Yes)
        DEFB    0
TDRIVE:                     ; Temp drive
        DEFB    1
TEMP_DR:        
        DEFB    0
TMPUSR:                    ; Temp User Number for Transient programs
        DEFB    0
TSELUSR:                   ; Temp user number for CCP
        DEFB    0
; OK:    
;         DEFB    28H
        
;
; Variables used by "TYPE" command
type_char_count:    
        db    0        ;CHAR COUNT FOR TYPE
type_line_count:    
        db      NLINES-2                ; Lines left on the page
        
        
        ENDMODULE
ccp_end:                                   ; after last machine code byte which should be part of the binary
;; Meta stuffs for build
        DISPLAY "ccp END\t:\t",/H,$

;-----------------------------------------------------------------------------
; -- Report size, export memory as binary
;-----------------------------------------------------------------------------
ccpBinSz   EQU     ccp_end-ccp_start      ; Shamelessly stolen clever reporting code from .DISPLAYEDGE by Ped7g
ccpBinPcHi EQU     (100*ccpBinSz)/(BDOS_A-CCP_A)
ccpBinPcLo EQU     ((100*ccpBinSz)%(BDOS_A-CCP_A))*10/(BDOS_A-CCP_A)
        DISPLAY "ccp LEN\t:\t",/D,ccpBinSz,"B\t(",/D,ccpBinPcHi,".",/D,ccpBinPcLo,"% of the space below the BDOS)"
        
        ASSERT  ccp_end <= BDOS_A           ; The kernel reads CCP.COM up to the BDOS
        ASSERT  CCP.ENTRY == CCP_RUN_A      ; The BIOS enters here at cold boot to run a line
        ASSERT  CCP.ENTRY+3 == CCP_PROMPT_A ; and here otherwise
        ASSERT  CCP.CBUFF == CCP_CBUFF_A    ; The kernel writes the line's length here
        ASSERT  CCP.CIBUFF == CCP_CIBUFF_A  ; and its text here
        ASSERT  CCP_CMD_MAX < CCP.BUFLEN    ; The line and its 0 fit the buffer
        SAVEBIN "../build/CCP.COM",ccp_start,ccpBinSz
        DISPLAY "======================================================= <"
;-----------------------------------------------------------------------------
; .DPM Memory Map Address Aliases
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------
    
    ;; Base addresses for various modules
ESX_A           EQU     $2000       ; Base address of ESXDOS loader
KERNEL_A        EQU     $8000       ; Base address of kernel
BIOS_A          EQU     $FE00       ; Base address of BIOS
BDOS_A          EQU     $FA00       ; Base address of BDOS
CCP_A           EQU     $F200       ; Base address of CCP
BDOS_ENTRY_A    EQU     BDOS_A+6    ; BDOS entry, the address at $0006: the top of the TPA

    ;; CCP layout, as CP/M 2.2's CCP has it
CCP_RUN_A       EQU     CCP_A       ; Entry that runs the command line in the buffer
CCP_PROMPT_A    EQU     CCP_A+3     ; Entry that empties the buffer and shows the prompt
CCP_CBUFF_A     EQU     CCP_A+7     ; Length of the command line in the buffer
CCP_CIBUFF_A    EQU     CCP_A+8     ; Text of the command line, ending in 0
CCP_CMD_MAX     EQU     99          ; Longest command line put in the buffer at cold boot
AUTOCMD_SIZE    EQU     CCP_CMD_MAX+2 ; That line as DP/M keeps it: length, text, 0

    ;; CPM hook addresses
REBOOT_A        EQU     $0000       ;reboot system
IOBYTE_A        EQU     $0003       ;i/o byte location
USERDRIVE_A     EQU     $0004       ;User/Drive flags
BDOSPTR_A       EQU     $0006       ;address field of jmp BDOS

    ;; BIOS entry that ends DP/M, as an offset from the warm boot address at $0001
BIOS_EXIT_OFS   EQU     84

TBUFF_A         EQU     $0080       ; DEFAULT DISK I/O BUFFER
TFCB_A          EQU     $005C       ; DEFAULT FCB BUFFER
TPA_A           EQU     $0100       ; BASE OF TPA

    ;; Tilemap Textmode
tilemapAddr             EQU     $6400
tilemapHiByte           EQU     $64
tileGfxAddr             EQU     $5C00       ; Tile definitions, 8 bytes per tile (NextReg $6F)

    ;; Console: consoleRows rows of the 80x32 tilemap from row consoleTop. A
    ;; 60 Hz display shows rows 1-30 only. Row 31 holds the DPM_DEBUG tracers.
consoleTop              EQU     1
consoleRows             EQU     30
consoleAddr             EQU     tilemapAddr+(consoleTop*80)

    ;; Text cursor: tile 0 is drawn over the cell at the cursor and shows the
    ;; character there in inverse. The character it covers is kept in tile 1's
    ;; first byte, so bank 5 alone holds the whole screen. Tiles 0-31 are never
    ;; printed, as codes below 32 are control codes.
cursorTile              EQU     0
cursorCharAddr          EQU     tileGfxAddr+8
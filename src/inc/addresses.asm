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
BIOS_A          EQU     $FA00       ; Base address of BIOS
BDOS_A          EQU     $E000       ; Base address of BDOS
CCP_A           EQU     $D000       ; Base address of CCP

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

    ;; Text cursor: tile 0 is drawn over the cell at the cursor and shows the
    ;; character there in inverse. The character it covers is kept in tile 1's
    ;; first byte, so bank 5 alone holds the whole screen. Tiles 0-31 are never
    ;; printed, as codes below 32 are control codes.
cursorTile              EQU     0
cursorCharAddr          EQU     tileGfxAddr+8
;-----------------------------------------------------------------------------
; .DPM constants
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------

; A long list of useful constants, mostly cribbed from Ped7g, SevenFFF & Rem.

;-----------------------------------------------------------------------------
; -- ULA Colour original colours
;-----------------------------------------------------------------------------
BLACK                               EQU 0
BLUE                                EQU 1
RED                                 EQU 2
MAGENTA                             EQU 3
GREEN                               EQU 4
CYAN                                EQU 5
YELLOW                              EQU 6
WHITE                               EQU 7
PAPER_BLACK                         EQU 0
PAPER_BLUE                          EQU 1<<3
PAPER_RED                           EQU 2<<3
PAPER_MAGENTA                       EQU 3<<3
PAPER_GREEN                         EQU 4<<3
PAPER_CYAN                          EQU 5<<3
PAPER_YELLOW                        EQU 6<<3
PAPER_WHITE                         EQU 7<<3
;-----------------------------------------------------------------------------
; -- ULA Attributes
;-----------------------------------------------------------------------------
ATTR_FLASH                          EQU 128
ATTR_BRIGHT                         EQU 64

;-----------------------------------------------------------------------------
; JOYSTICK
;-----------------------------------------------------------------------------
BIT_UP                              EQU 4    ; 16
BIT_DOWN                            EQU 5    ; 32
BIT_LEFT                            EQU 6    ; 64
BIT_RIGHT                           EQU 7    ; 128

DIR_NONE                            EQU %00000000
DIR_UP                              EQU %00010000
DIR_DOWN                            EQU %00100000
DIR_LEFT                            EQU %01000000
DIR_RIGHT                           EQU %10000000

DIR_UP_I                            EQU %11101111
DIR_DOWN_I                          EQU %11011111
DIR_LEFT_I                          EQU %10111111
DIR_RIGHT_I                         EQU %01111111

;-----------------------------------------------------------------------------
;-- SYSVARS for current state of machine, Next ZXOS, etc.
;-----------------------------------------------------------------------------
SYSVAR_BORDCR_5C48                  EQU $5C48


;-----------------------------------------------------------------------------
;-- ESXDOS constants and useful values
;-----------------------------------------------------------------------------
ESXDOS_MAX_PATH_LENGTH              EQU 262
;-----------------------------------------------------------------------------
;-- I/O ports - ZX Spectrum classic (48, 128, Timex, Pentagon, ...) ports
;-----------------------------------------------------------------------------
ULA_P_FE                            EQU $FE     ; BORDER + MIC + BEEP + read Keyboard
TIMEX_P_FF                          EQU $FF     ; Timex video control port

ZX128_MEMORY_P_7FFD                 EQU $7FFD   ; ZX Spectrum 128 ports
ZX128_MEMORY_P_DFFD                 EQU $DFFD
ZX128P3_MEMORY_P_1FFD               EQU $1FFD

AY_REG_P_FFFD                       EQU $FFFD
AY_DATA_P_BFFD                      EQU $BFFD

Z80_DMA_PORT_DATAGEAR               EQU $6B     ; on ZXN the zxnDMA handles this
Z80_DMA_PORT_MB02                   EQU $0B     ; only in Zilog DMA mode zxnDMA handles this

DIVMMC_CONTROL_P_E3                 EQU $E3
SPI_CS_P_E7                         EQU $E7
SPI_DATA_P_EB                       EQU $EB

KEMPSTON_MOUSE_X_P_FBDF             EQU $FBDF
KEMPSTON_MOUSE_Y_P_FFDF             EQU $FFDF
KEMPSTON_MOUSE_B_P_FADF             EQU $FADF   ; kempston mouse wheel+buttons

KEMPSTON_JOY1_P_1F                  EQU $1F
KEMPSTON_JOY2_P_37                  EQU $37

;-----------------------------------------------------------------------------
;-- I/O ports - ZX Spectrum NEXT specific ports
;-----------------------------------------------------------------------------

TBBLUE_REGISTER_SELECT_P_243B       EQU $243B
    ; -- port $243B = 9275  Read+Write (detection bitmask: %0010_0100_0011_1011)
    ;   -- selects NextREG mapped at port TBBLUE_REGISTER_ACCESS_P_253B

TBBLUE_REGISTER_ACCESS_P_253B       EQU $253B
    ; -- port $253B = 9531  Read?+Write? (detection bitmask: %0010_0101_0011_1011)
    ;   -- data for selected NextREG (read/write depends on the register selected)

I2C_SCL_P_103B                      EQU $103B   ; i2c bus port (clock) (write only?)
I2C_SDA_P_113B                      EQU $113B   ; i2c bus port (data) (read+write)
UART_TX_P_133B                      EQU $133B   ; UART tx port (read+write)
UART_RX_P_143B                      EQU $143B   ; UART rx port (read+write)

ZXN_DMA_P_6B                        EQU $6B
    ; -- port $6B = 107 Read+Write (detection bitmask: %xxxx_xxxx_0110_1011)
    ;   - The zxnDMA is mostly compatible with Zilog DMA chip (Z8410) (at least
    ;     as far as old ZX apps are concerned), but has many modifications.
    ;   - core3.0 update - specific behaviour details can be selected (PERIPHERAL_2_NR_06)

LAYER2_ACCESS_P_123B                EQU $123B
    ; -- port $123B = 4667 Read+Write (detection bitmask: %0001_0010_0011_1011)
    ;   -- bit 7-6 = write-Layer2-over-ROM bank selection (00, 01 or 10) (11 is 48kiB mode)
    ;   -- bit 3 = shadow banks "over ROM" (nextreg $13 banks instead of $12 banks)
    ;   -- bit 2 = read-Layer2-over-ROM (1 = read at $0000..$3FFF reads from Layer2)
    ;   -- bit 1 = Layer2 visibility (1 = visible, 0 = disabled) (always nextreg $12)
    ;   -- bit 0 = write-Layer2-over-ROM (1 = write at $0000..$3FFF writes into Layer2)
LAYER2_ACCESS_WRITE_OVER_ROM        EQU $01     ; map Layer2 bank into ROM area (0000..3FFF) for WRITE-only (reads as ROM)
LAYER2_ACCESS_L2_ENABLED            EQU $02     ; enable Layer2 (make banks form nextreg $12 visible)
LAYER2_ACCESS_READ_OVER_ROM         EQU $04     ; map Layer2 bank into ROM area (0000..3FFF) for READ-only
LAYER2_ACCESS_SHADOW_OVER_ROM       EQU $08     ; bank selected by bits 6-7 is from "shadow Layer 2" banks range (nextreg $13)
LAYER2_ACCESS_OVER_ROM_BANK_M       EQU $C0     ; (mask of) value 0..3 selecting bank mapped for R/W (Nextreg $12 or $13)
LAYER2_ACCESS_OVER_ROM_BANK_0       EQU $00     ; screen lines 0..63
LAYER2_ACCESS_OVER_ROM_BANK_1       EQU $40     ; screen lines 64..127
LAYER2_ACCESS_OVER_ROM_BANK_2       EQU $80     ; screen lines 128..191
LAYER2_ACCESS_OVER_ROM_48K          EQU $C0     ; maps all 0..191 lines into $0000..$BFFF region

SPRITE_STATUS_SLOT_SELECT_P_303B    EQU $303B
    ; -- port $303B = 12347  Read+Write (detection bitmask: %0011_0000_0011_1011)
    ;   -- write:
    ;     - sets both "sprite slot" (0..63) and "pattern slot" (0..63 +128)
    ;     - once the sprite/pattern slots are set, they act independently and
    ;     each port ($xx57 and $xx5B) will auto-increment its own slot index
    ;     (to resync one can write to this port again).
    ;     - the +128 flag will make the pattern upload start at byte 128 of pattern
    ;     slot (second half of slot)
    ;     - The sprite-slot (sprite-attributes) may be optionally interlinked with
    ;     NextReg $34 (feature controlled by NextReg $34)
    ;     - auto-increments of slot position from value 63 are officially
    ;     "undefined behaviour", wrap to 0 is not guaranteed. (only setting slots
    ;     explicitly back to valid 0..63 will make your code future-proof)
    ;   -- read (will also reset both collision and max-sprites flags):
    ;     - bit 1 = maximum sprites per line hit (set when sprite renderer ran
    ;               out of time when preparing next scanline)
    ;     - bit 0 = collision flag (set when any sprites draw non-transparent
    ;               pixel at the same location)
    ;     Both flags contain values for current scanline already at the beginning
    ;     of scanline (sprite engine renders one line ahead into buffer and updates
    ;     flags progressively as it renders the sprites)
SPRITE_STATUS_MAXIMUM_SPRITES       EQU $02
SPRITE_STATUS_COLLISION             EQU $01
SPRITE_SLOT_SELECT_PATTERN_HALF     EQU 128     ; add it to 0..63 index to make pattern upload start at second half of pattern

SPRITE_ATTRIBUTE_P_57               EQU $57
    ; -- port $xx57 = 87 write-only (detection bitmask: %xxxx_xxxx_0101_0111)
    ;  - writing 4 or 5 bytes long structures to control particular sprite
    ;  - after 4/5 bytes block the sprite slot index is auto-incremented
    ;  - for detailed documentation check official docs or wiki (too long)

SPRITE_PATTERN_P_5B                 EQU $5B
    ; -- port $xx5B = 91 write-only (detection bitmask: %xxxx_xxxx_0101_1011)
    ;  - each pattern slot is 256 bytes long = one 16x16 pattern of 8-bit pixels
    ;    or two 16x16 patterns of 4-bit pixels.
    ;  - Patterns are uploaded in "English" order (left to right, top to bottom),
    ;    one byte encodes single pixel in 8 bit mode and two pixels in 4 bit
    ;    mode (bits 7-4 are "left" pixel, 3-0 are "right" pixel)
    ;  - pixels are offset (index) into active sprite palette

TURBO_SOUND_CONTROL_P_FFFD          EQU $FFFD   ; write with bit 7 = 1 (port shared with AY)

;-----------------------------------------------------------------------------
;-- NEXT HW Registers (NextReg)
;-----------------------------------------------------------------------------
MACHINE_ID_NR_00                    EQU $00
NEXT_VERSION_NR_01                  EQU $01
NEXT_RESET_NR_02                    EQU $02
MACHINE_TYPE_NR_03                  EQU $03
ROM_MAPPING_NR_04                   EQU $04     ;In config mode, allows RAM to be mapped to ROM area.
PERIPHERAL_1_NR_05                  EQU $05     ;Sets joystick mode, video frequency and Scandoubler.
PERIPHERAL_2_NR_06                  EQU $06     ;Enables Acceleration, DivMMC, Multiface, Mouse and AY audio
CPU_SPEED_NR_07                     EQU $07
PERIPHERAL_3_NR_08                  EQU $08     ;ABC/ACB Stereo, Internal Speaker, SpecDrum, Timex Video Modes, Turbo Sound Next, RAM contention and [un]lock 128k paging.
PERIPHERAL_4_NR_09                  EQU $09     ;Sets scanlines, AY mono output, Sprite-id lockstep, disables Kempston and divMMC ports.
NEXT_VERSION_MINOR_NR_0E            EQU $0E
ANTI_BRICK_NR_10                    EQU $10
VIDEO_TIMING_NR_11                  EQU $11
LAYER2_RAM_BANK_NR_12               EQU $12     ;bank number where visible Layer 2 video memory begins.
LAYER2_RAM_SHADOW_BANK_NR_13        EQU $13     ;bank number for Layer2 "shadow" write-over-rom
GLOBAL_TRANSPARENCY_NR_14           EQU $14     ;Sets the color treated as transparent for ULA/Layer2/LoRes
SPRITE_CONTROL_NR_15                EQU $15     ;LoRes mode, Sprites configuration, layers priority
    ; bit 7: enable LoRes mode
    ; bit 6: sprite rendering (1=sprite 0 on top of other, 0=sprite 0 at bottom)
    ; bit 5: If 1, the clipping works even in "over border" mode
    ; 4-2: layers priority: 000=SLU, 001=LSU, 010=SUL, 011=LUS, 100=USL, 101=ULS, 110=S,mix(U+L), 111=S,mix(U+L-5)
    ; bit 1: enable sprites over border, bit 0: show sprites
LAYER2_XOFFSET_NR_16                EQU $16
LAYER2_YOFFSET_NR_17                EQU $17
CLIP_LAYER2_NR_18                   EQU $18
CLIP_SPRITE_NR_19                   EQU $19
CLIP_ULA_LORES_NR_1A                EQU $1A
CLIP_TILEMAP_NR_1B                  EQU $1B
CLIP_WINDOW_CONTROL_NR_1C           EQU $1C     ;set to 15 to reset all clip-window indices to 0
RASTER_LINE_MSB_NR_1E               EQU $1E
RASTER_LINE_LSB_NR_1F               EQU $1F
RASTER_INTERUPT_CONTROL_NR_22       EQU $22     ;Controls the timing of raster interrupts and the ULA frame interrupt.
RASTER_INTERUPT_VALUE_NR_23         EQU $23
ULA_XOFFSET_NR_26                   EQU $26     ;since core 3.0
ULA_YOFFSET_NR_27                   EQU $27     ;since core 3.0
HIGH_ADRESS_KEYMAP_NR_28            EQU $28
LOW_ADRESS_KEYMAP_NR_29             EQU $29
HIGH_DATA_TO_KEYMAP_NR_2A           EQU $2A
LOW_DATA_TO_KEYMAP_NR_2B            EQU $2B
DAC_B_MIRROR_NR_2C                  EQU $2C
DAC_AD_MIRROR_NR_2D                 EQU $2D     ;another alias for $2D
SOUNDDRIVE_DF_MIRROR_NR_2D          EQU $2D     ;Nextreg port-mirror of port 0xDF
DAC_C_MIRROR_NR_2E                  EQU $2E
TILEMAP_XOFFSET_MSB_NR_2F           EQU $2F
TILEMAP_XOFFSET_LSB_NR_30           EQU $30
TILEMAP_YOFFSET_NR_31               EQU $31
LORES_XOFFSET_NR_32                 EQU $32
LORES_YOFFSET_NR_33                 EQU $33
SPRITE_ATTR_SLOT_SEL_NR_34          EQU $34     ;Sprite-attribute slot index for $35-$39/$75-$79 port $57 mirrors
SPRITE_ATTR0_NR_35                  EQU $35     ;port $57 mirror in nextreg space (accessible to copper)
SPRITE_ATTR1_NR_36                  EQU $36
SPRITE_ATTR2_NR_37                  EQU $37
SPRITE_ATTR3_NR_38                  EQU $38
SPRITE_ATTR4_NR_39                  EQU $39
PALETTE_INDEX_NR_40                 EQU $40     ;Chooses a ULANext palette number to configure.
PALETTE_VALUE_NR_41                 EQU $41     ;Used to upload 8-bit colors to the ULANext palette.
PALETTE_FORMAT_NR_42                EQU $42     ;ink-mask for ULANext modes
PALETTE_CONTROL_NR_43               EQU $43     ;Enables or disables ULANext interpretation of attribute values and toggles active palette.
PALETTE_VALUE_9BIT_NR_44            EQU $44     ;Holds the additional blue color bit for RGB333 color selection.
TRANSPARENCY_FALLBACK_COL_NR_4A     EQU $4A     ;8-bit colour to be drawn when all layers are transparent
SPRITE_TRANSPARENCY_I_NR_4B         EQU $4B     ;index of transparent colour in sprite palette (only bottom 4 bits for 4-bit patterns)
TILEMAP_TRANSPARENCY_I_NR_4C        EQU $4C     ;index of transparent colour in tilemap graphics (only bottom 4 bits)
MMU0_0000_NR_50                     EQU $50     ;Set a Spectrum RAM page at position 0x0000 to 0x1FFF
MMU1_2000_NR_51                     EQU $51     ;Set a Spectrum RAM page at position 0x2000 to 0x3FFF
MMU2_4000_NR_52                     EQU $52     ;Set a Spectrum RAM page at position 0x4000 to 0x5FFF
MMU3_6000_NR_53                     EQU $53     ;Set a Spectrum RAM page at position 0x6000 to 0x7FFF
MMU4_8000_NR_54                     EQU $54     ;Set a Spectrum RAM page at position 0x8000 to 0x9FFF
MMU5_A000_NR_55                     EQU $55     ;Set a Spectrum RAM page at position 0xA000 to 0xBFFF
MMU6_C000_NR_56                     EQU $56     ;Set a Spectrum RAM page at position 0xC000 to 0xDFFF
MMU7_E000_NR_57                     EQU $57     ;Set a Spectrum RAM page at position 0xE000 to 0xFFFF
COPPER_DATA_NR_60                   EQU $60
COPPER_CONTROL_LO_NR_61             EQU $61
COPPER_CONTROL_HI_NR_62             EQU $62
COPPER_DATA_16B_NR_63               EQU $63     ; same as $60, but waits for full 16b before write
ULA_CONTROL_NR_68                   EQU $68
DISPLAY_CONTROL_NR_69               EQU $69
LORES_CONTROL_NR_6A                 EQU $6A
TILEMAP_CONTROL_NR_6B               EQU $6B
TILEMAP_DEFAULT_ATTR_NR_6C          EQU $6C
TILEMAP_BASE_ADR_NR_6E              EQU $6E     ;Tilemap base address of map
TILEMAP_GFX_ADR_NR_6F               EQU $6F     ;Tilemap definitions (graphics of tiles)
LAYER2_CONTROL_NR_70                EQU $70
SPRITE_ATTR0_INC_NR_75              EQU $75     ;port $57 mirror in nextreg space (accessible to copper) (slot index++)
SPRITE_ATTR1_INC_NR_76              EQU $76
SPRITE_ATTR2_INC_NR_77              EQU $77
SPRITE_ATTR3_INC_NR_78              EQU $78
SPRITE_ATTR4_INC_NR_79              EQU $79
USER_STORAGE_0_NR_7F                EQU $7F
EXPANSION_BUS_CONTROL_NR_80         EQU $80
INTERNAL_PORT_DECODING_0_NR_82      EQU $82     ;bits 0-7
INTERNAL_PORT_DECODING_1_NR_83      EQU $83     ;bits 8-15
INTERNAL_PORT_DECODING_2_NR_84      EQU $84     ;bits 16-23
INTERNAL_PORT_DECODING_3_NR_85      EQU $85     ;bits 24-31
EXPANSION_BUS_DECODING_0_NR_86      EQU $86     ;bits 0-7 mask
EXPANSION_BUS_DECODING_1_NR_87      EQU $87     ;bits 8-15 mask
EXPANSION_BUS_DECODING_2_NR_88      EQU $88     ;bits 16-23 mask
EXPANSION_BUS_DECODING_3_NR_89      EQU $89     ;bits 24-31 mask
EXPANSION_BUS_PROPAGATE_NR_8A       EQU $8A     ;Monitoring internal I/O or adding external keyboard
PI_GPIO_OUT_ENABLE_0_NR_90          EQU $90     ;pins 0-7
PI_GPIO_OUT_ENABLE_1_NR_91          EQU $91     ;pins 8-15
PI_GPIO_OUT_ENABLE_2_NR_92          EQU $92     ;pins 16-23
PI_GPIO_OUT_ENABLE_3_NR_93          EQU $93     ;pins 24-27
PI_GPIO_0_NR_98                     EQU $98     ;pins 0-7
PI_GPIO_1_NR_99                     EQU $99     ;pins 8-15
PI_GPIO_2_NR_9A                     EQU $9A     ;pins 16-23
PI_GPIO_3_NR_9B                     EQU $9B     ;pins 24-27
PI_PERIPHERALS_ENABLE_NR_A0         EQU $A0
PI_I2S_AUDIO_CONTROL_NR_A2          EQU $A2
PI_I2S_CLOCK_DIVIDE_NR_A3           EQU $A3
DIVMMC_ENTRY_POINTS_0_NR_B8         EQU $B8
DIVMMC_ENTRY_POINTS_VALID_0_NR_B9   EQU $B9
DIVMMC_ENTRY_POINTS_TIMING_0_NR_BA  EQU $BA
DIVMMC_ENTRY_POINTS_1_NR_BB         EQU $BB
INTERRUPT_CONTROL_NR_C0             EQU $C0     ;IM2 vector offset, stackless NMI, the IM mode (read only), hardware IM2
INT_EN_0_NR_C4                      EQU $C4     ;Interrupt enables: expansion bus, line, ULA
INT_EN_1_NR_C5                      EQU $C5     ;Interrupt enables: CTC channels 0-7
INT_EN_2_NR_C6                      EQU $C6     ;Interrupt enables: UART 0 and 1

DEBUG_LED_CONTROL_NR_FF             EQU $FF     ;Turns debug LEDs on and off on TBBlue implementations that have them.

;-----------------------------------------------------------------------------
;-- common memory addresses
;-----------------------------------------------------------------------------
MEM_ROM_CHARS_3C00                  EQU $3C00   ; actual chars start at $3D00 with space
MEM_ZX_SCREEN_4000                  EQU $4000
MEM_ZX_ATTRIB_5800                  EQU $5800
MEM_LORES0_4000                     EQU $4000
MEM_LORES1_6000                     EQU $6000
MEM_TIMEX_SCR0_4000                 EQU $4000
MEM_TIMEX_SCR1_6000                 EQU $6000

;-----------------------------------------------------------------------------
;-- Copper commands
;-----------------------------------------------------------------------------
COPPER_NOOP                         EQU %00000000
COPPER_WAIT_H                       EQU %10000000
COPPER_HALT_B                       EQU $FF   ; 2x $FF = wait for (511,63) = infinite wait

;-----------------------------------------------------------------------------
; DMA (Register 6)
;-----------------------------------------------------------------------------
DMA_RESET                           EQU $C3
DMA_RESET_PORT_A_TIMING             EQU $C7
DMA_RESET_PORT_B_TIMING             EQU $CB
DMA_LOAD                            EQU $CF
DMA_CONTINUE                        EQU $D3
DMA_DISABLE_INTERUPTS               EQU $AF
DMA_ENABLE_INTERUPTS                EQU $AB
DMA_RESET_DISABLE_INTERUPTS         EQU $A3
DMA_ENABLE_AFTER_RETI               EQU $B7
DMA_READ_STATUS_BYTE                EQU $BF
DMA_REINIT_STATUS_BYTE              EQU $8B
DMA_START_READ_SEQUENCE             EQU $A7
DMA_FORCE_READY                     EQU $B3
DMA_DISABLE                         EQU $83
DMA_ENABLE                          EQU $87
DMA_READ_MASK_FOLLOWS               EQU $BB

;-----------------------------------------------------------------------------
; -- ZX Character Set
;-----------------------------------------------------------------------------
TAB                                 EQU     $09
ESC                                 EQU     $1B     ;      NEEDS A DIFFERENT CHARACTER
                                                    ;      TO CLEAR THE SCREEN
SPACE                               EQU     $20

COPYRIGHT                           EQU     $7F


;-----------------------------------------------------------------------------
; -- ZX Tokens - used by keyboard driver
;-----------------------------------------------------------------------------
udgA                                EQU     144
token_sin                           EQU     $b2
token_to                            EQU     $cc
token_new                           EQU     $e6



;-----------------------------------------------------------------------------
; -- Types and Generics
;-----------------------------------------------------------------------------
FALSE                             EQU    0
TRUE                                EQU    NOT FALSE
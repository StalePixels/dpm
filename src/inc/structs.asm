;-----------------------------------------------------------------------------
; .DPM Memory Structures
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------

    STRUCT S_PRESERVE
        ; WORDs used, first byte is register number, second byte is preserved value
turbo_07            WORD    CPU_SPEED_NR_07
spr_CTR_15         WORD    SPRITE_CONTROL_NR_15
transp_fallback_4A  WORD    TRANSPARENCY_FALLBACK_COL_NR_4A
tile_transp_4C      WORD    TILEMAP_TRANSPARENCY_I_NR_4C
ula_CTR_68         WORD    ULA_CONTROL_NR_68
display_CTR_69     WORD    DISPLAY_CONTROL_NR_69
tile_CTR_6B        WORD    TILEMAP_CONTROL_NR_6B
tile_def_attr_6C    WORD    TILEMAP_DEFAULT_ATTR_NR_6C
tile_map_adr_6E     WORD    TILEMAP_BASE_ADR_NR_6E
tile_gfx_adr_6F     WORD    TILEMAP_GFX_ADR_NR_6F
tile_xofs_msb_2F    WORD    TILEMAP_XOFFSET_MSB_NR_2F
tile_xofs_lsb_30    WORD    TILEMAP_XOFFSET_LSB_NR_30
tile_yofs_31        WORD    TILEMAP_YOFFSET_NR_31
pal_CTR_43         WORD    PALETTE_CONTROL_NR_43
pal_idx_40          WORD    PALETTE_INDEX_NR_40
mmu2_52             WORD    MMU2_4000_NR_52
mmu3_53             WORD    MMU3_6000_NR_53
mmu4_54             WORD    MMU4_8000_NR_54
mmu5_55             WORD    MMU5_A000_NR_55
mmu6_56             WORD    MMU6_C000_NR_56
mmu7_57             WORD    MMU7_E000_NR_57

    ENDS
    
    STRUCT S_STATE
.s_state_start
argsPtr             WORD    0
mmu2backup          BYTE    0           ; 16k to stash BANK5 contents
mmu3backup          BYTE    0           ; 16k to stash BANK5 contents
kernel0             BYTE    0
kernel1             BYTE    0
mmu0                BYTE    $0
mmu1                BYTE    $1
mmu2                BYTE    $2
mmu3                BYTE    $3
mmu4                BYTE    $4
mmu5                BYTE    $5
mmu6                BYTE    $6
mmu7                BYTE    $7
.s_state_end
    ENDS
    
STATE_SIZE          EQU      .s_state_end-.s_state_start
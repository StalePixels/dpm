;-----------------------------------------------------------------------------
; .DPM ESX DOS functions
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------

FA_OPEN_EXISTING                EQU     $00     ; Open an existing file, but error if not existing.
FA_READ                         EQU     $01
FA_WRITE                        EQU     $02

FA_CREATE                       EQU     $04     ; Create a new file, or error if it already exists.

FA_OPEN                         EQU     $08     ; Open an existing file, or create a new one.

FA_CREATE_NEW                   EQU     $0C     ; Create a new file, overwriting it if it already exists.

FA_RWP3HDR                      EQU     $40     ; Include +3 dos header.

M_DOSVERSION                    EQU     $88
M_GETSETDRV                     EQU     $89     ; get current drive (or use A='*'/'$' for current/system drive!)

M_GETHANDLE                     EQU     $8D     ; get file handle of current dot command

M_DRVAPI                        EQU     $92
M_GETERR                        EQU     $93
M_P3DOS                         EQU     $94     ; +3 DOS function call
M_ERRH                          EQU     $95

F_OPEN                          EQU     $9A
F_CLOSE                         EQU     $9B
F_SYNC                          EQU     $9C
F_READ                          EQU     $9D
F_WRITE                         EQU     $9E
F_SEEK                          EQU     $9F
F_FGETPOS                       EQU     $A0
F_FSTAT                         EQU     $A1
F_FTRUNCATE                     EQU     $A2     ; Truncate/Extend open file
F_OPENDIR                       EQU     $A3
F_READDIR                       EQU     $A4
F_TELLDIR                       EQU     $A5
F_SEEKDIR                       EQU     $A6
F_REWINDDIR                     EQU     $A7
F_GETCWD                        EQU     $A8
F_CHDIR                         EQU     $A9
F_MKDIR                         EQU     $AA
F_RMDIR                         EQU     $AB
F_STAT                          EQU     $AC
F_UNLINK                        EQU     $AD
F_TRUNCATE                      EQU     $AE     ; Truncate/Extend unopen file
F_CHMOD                         EQU     $AF
F_RENAME                        EQU     $B0
F_GETFREE                       EQU     $BA

;; B=access mode for directories - add together any or all of:
esx_mode_short_only             EQU     $00 
esx_mode_lfn_only               EQU     $10 
esx_mode_lfn_and_short          EQU     $18 
esx_mode_use_wildcards          EQU     $20
esx_mode_use_header             EQU     $40
esx_mode_sf_enable              EQU     $80

;; C=sort/filter mode (if enabled in access mode) – add together:
esx_sf_sort_lfn                 EQU     $00
esx_sf_sort_short               EQU     $01
esx_sf_sort_date                EQU     $02
esx_sf_sort_size                EQU     $03
esx_sf_sort_reverse             EQU     $04
esx_sf_sort_enable              EQU     $08
esx_sf_exclude_sys              EQU     $10
esx_sf_exclude_dots             EQU     $20
esx_sf_exclude_dirs             EQU     $40
esx_sf_exclude_files            EQU     $80

;; B=access mode for file - add together any or all of:
esx_mode_read                   EQU     $01
esx_mode_write                  EQU     $02
;; **AND** one of
esx_mode_open_exist             EQU     $00
esx_mode_open_creat             EQU     $08
esx_mode_creat_noexist          EQU     $04
esx_mode_creat_trunc            EQU     $0c

esx_seek_set                    EQU     $00
esx_seek_fwd                    EQU     $01
esx_seek_bwd                    EQU     $02
; DE=null-terminated wildcard string, if esx_mode_use_wildcards
; The same string must also be passed when calling F_READDIR, in case
; sorting is not possible and a fall back to unsorted mode is made.

IDE_BANK                        EQU     $01bd   ; NextZXOS function to manage memory

m_esxdos    MACRO   func
        rst     $08
        db      func
	ENDM
;-----------------------------------------------------------------------------
; .DPM bootROM/kernel dynamic data
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------

    MODULE KERNEL

;; STATIC DATAs
strings:
.path: 
        DB "Checking:", 0x0D, " ", 0
.error: 
        DB "ERROR: ", 0
        
.greeting:
        DB DPMname, " v", DPMversion, " ZXNext CPM Emulator", 10, 13
        DB COPYRIGHT, "lGPLv3 2022 D. 'Xalior' Rimron-Soutter", 10, 13, 10, 13
        DB "ESXDOS Bootstrapping...", 10, 13, 0

.unimplimented:
        DB "UNIMPLIMENTED kr_", 0
.called:
        DB "CALLED kr_", 0

.restarting:
        DB      "Restarting...", 10, 13, 0

; ccp_image:
;         DISPLAY "kernel CCPimg\t:\t",/H,$
;         INCBIN "../build/CCP"

;         DISPLAY "kernel CCPend\t:\t",/H,$
cp437_font:
        DISPLAY "kernel glyphs\t:\t",/H,$
        INCBIN "../assets/CP437-256.UDG"
    ; ORG cp437_font+1024                                 // WHY DOES THIS CAUSE A FAIL IN FFIRST?

        DISPLAY "kernel data\t:\t",/H,$
        
dynamic_data:
.dot_stack
        DW  $AAAA                           ; SO we can switch back to the ESXDOS stack
        
.working_path
        DS  ESXDOS_MAX_PATH_LENGTH, $00     ; 261bytes of temp space for file access
        DB  0

.sfn
        DS  13, $00                         ; Short Filename "cache", 12char+NULL byte
.currdir
        DS  ESXDOS_MAX_PATH_LENGTH, $00                        ; Buffer for "Current Working Dir"
.subdir
        DB 'A', 0
.state S_STATE

.current_file
        DB  0

.console_cache
        DB  0

;    
;    FILE    CONTROL BLOCK
;    
.fcb_diskname:
        ds    1        ; Disk Name
.fcb_filename:
        ds    8        ; File Name
.fcb_filetype:
        ds    3        ; File Extension
.fcb_extent_num
        ds    1        ;EXTENT NUMBER
.fcb_s12:
        ds    2        ;S1 AND S2
.fcb_reccount:
        ds    1        ;RECORD COUNT
.fcb_groupmap:
        ds    16        ;DISK GROUP MAP
.fcb_current_rec:
        ds    1        ;CURRENT RECORD NUMBER

.store_source:
        dw 0


config:
.install_path
        DB "C:/DPM/"                       ; Default install location - ideally changable via INI file (one day)
        DS ESXDOS_MAX_PATH_LENGTH, $00     ; Buffer space for a very long path, if loaded from INI file
    ENDMODULE
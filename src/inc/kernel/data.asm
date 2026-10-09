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

CONFIG_MAX      EQU     1024                ; The longest config.ini that DPM control rewrites

;; STATIC DATAs
strings:
.path: 
        DB "Checking:", 0x0D, " ", 0
.error: 
        DB "ERROR: ", 0
        
.greeting:
        DB DPMname, " v", DPMversion, " ZXNext CPM Emulator", 10, 13
        DB COPYRIGHT, "lGPLv3 ",DPMyear," D. 'Xalior' Rimron-Soutter", 10, 13, 10, 13
        DB "ESXDOS Bootstrapping...", 10, 13, 0

.unimplimented:
        DB "UNIMPLIMENTED kr_", 0
.called:
        DB "CALLED kr_", 0

.ccp_name:
        DB "CCP.COM", 0                     ; The CCP, loaded from config.install_path
.config_name:
        DB "config.ini", 0                  ; DP/M's settings, in config.install_path
.console_section:
        DB "[console]", 0
.key_ink:
        DB "ink=", 0
.key_paper:
        DB "paper=", 0
.colour_names:                              ; The colours in SGR order, 8 bytes each
        DB "black", 0, 0, 0
        DB "red", 0, 0, 0, 0, 0
        DB "green", 0, 0, 0
        DB "yellow", 0, 0
        DB "blue", 0, 0, 0, 0
        DB "magenta", 0
        DB "cyan", 0, 0, 0, 0
        DB "white", 0, 0, 0
        ASSERT  $-.colour_names == 8*8

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

.console_queue                              ; Console input, a ring: keys and terminal replies
        DS  16, $00
.console_head                               ; Index of the next byte out
        DB  0
.console_tail                               ; Index of the next byte in; head == tail is empty
        DB  0
.console_last                               ; The last byte taken from the queue
        DB  0

.tilemap_palette                            ; NextZXOS's tilemap first palette, put back
        DS  512, $00                        ; at exit: per colour, bits 8-1 then bit 0

.config_text                               ; config.ini as read, ending in 0
        DS  CONFIG_MAX+1, $00
.config_end                                 ; The address of the 0 that ends config_text
        DW  0
.config_new                                 ; The [console] section, as it is written
        DS  40, $00
.config_handle                              ; config.ini, while it is written
        DB  0
.config_error                               ; $FF after an error writing config.ini
        DB  0

.autocmd                                    ; Command line from the dot command's arguments, run
        DS  AUTOCMD_SIZE, $00               ; by the CCP at cold boot: length, text, 0

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
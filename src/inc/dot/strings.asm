
;-----------------------------------------------------------------------------
; .DPM Static strings
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------

;-----------------------------------------------------------------------------
;-- Messages used during normal startup and shutdown                (Null Term)
;-----------------------------------------------------------------------------
    MODULE DotMsg
Startup: 
        DB CR, DPMname, " v", DPMversion, " ZX Next CP/M Emulator", CR
        DB COPYRIGHT, "2024 D. 'Xalior' Rimron-Soutter", CR, CR, 0
Shutdown:
        DB CR, "Returning to NextBASIC", CR, 0
        
        
        
TAB                                 EQU     09H     ;tab
LF                                  EQU     $0A     ;line feed
FF                                  EQU     $0C     ;form feed
CR                                  EQU     $0D     ;carriage return
    ENDMODULE
    
;-----------------------------------------------------------------------------
;-- Error messaged used for unsuccesful start, displayed at exit   (Hibit Term)
;-----------------------------------------------------------------------------
    MODULE DotErr
;       DC      "123456789012345678901234567890" ; DC == DB "strin",'g'|128
NextRequired:
        DC      "Spectrum Next required"
NotEnoughMemory:
        DC      "Not enough free memory banks"
CannotLoad:                             ; The kernel adds the CCP's path (Null Term)
        DB      "Cannot load ", 0
CannotLoadLen   EQU     $-CannotLoad-1
MissingFolder:                          ; The kernel adds the folder's path (Null Term)
        DB      "Missing folder ", 0
MissingFolderLen EQU    $-MissingFolder-1
PrefixMax       EQU     16              ; Room for the longest prefix above, in error_report
        ASSERT  CannotLoadLen <= PrefixMax
        ASSERT  MissingFolderLen <= PrefixMax
    ENDMODULE
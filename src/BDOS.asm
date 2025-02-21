;-----------------------------------------------------------------------------
; .DPM main memory BDOS
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FSB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------
    
    ORG     BDOS_A

bdos_start:
    DISPLAY "BDOS ORG\t:\t",/H,$

    MODULE  BDOS
entry:
        ; The function number is passed in Register C.
        ; The parameter is passed in DE.
        ; Result returned in A or HL. Also, A=L and B=H on return for compatibility reasons.
        ; If function number is unknown we return A=0.

        ld      a, c                    ; copy parameter from C to A
        cp      49
        jr      c, .exec_func

        ; db 'BAD BDOS CALL: ',0
        jr $
        jp      $0000                    ; Totally abandon anything after a bad BDOS call!

.exec_func:
        ld      (BIOS.internal_TEARDOWN.SMC_exitstack), sp
        ld      sp, BIOS.stack

        push    hl
        push    de
        
        ld      hl, kernel_jump_table        ; Base entry in jump table
        ld      e, c                         ; Function number into DE
        ld      d, 0                         ;
        add     hl, de                       ; Add it to HL...
        add     hl, de                       ; ...twice - to get right (16bit) address

        ld      e, (hl)
        inc     hl
        ld      d, (hl)                      ; ld de, (hl)
        ex      de, hl                       ; hl now holds address of the BDOS call
        
        pop     de
        ; pop hl occours in the BIOS.internal_KERNEL_call
        call    BIOS.internal_KERNEL_call
       
        ; Now return. So anything that wants to return a value in HL should do ld a,l ld b,h first
        ld      l, a                         ; This is how the BDOS returns values.
        ld      h, b                         ; Note: that it is important to some 
        ret                             ; programs that both A and B are set.

; internal_TEARDOWN:
internal_TEARDOWN.SMC_MMU4 EQU $+3
        nextreg	MMU4_8000_NR_54, 0xAA
internal_TEARDOWN.SMC_MMU5 EQU $+3
        nextreg	MMU5_A000_NR_55, 0xAA
        ;; return stack to original location
internal_TEARDOWN.SMC_exitstack EQU $+1
        ld      sp, 0xAAAA                  ; restore original stack pointer, as above 0xAAAA is SMC.


; Copy FCB (pointed to by HL) to cache in BDOS
;   Source FCB can be anywhere in RAM. Should only be called while kernel is paged in.
cache_current_fcb_for_kernel:
        push    de
        push    bc
        ;; Ensure that all the userland memory is available, incase HL resides behind kernel
.SMC_MMU4_userland EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_userland EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        ld      de, fcb_cache               ; Copy To
        ld      bc, 36                      ; Length of Copy
        ldir                                ; ldi repeat. Go.
        ;; Restore kernel
.SMC_MMU4_kernel EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_kernel EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        pop     bc
        pop     de
        ret
;
; Copy DMA cache to DMA address
copy_dma_out_kernel:
        push    af
        push    de
        push    bc
        ;; Ensure that all the userland memory is available, incase HL resides behind kernel
.SMC_MMU4_userland EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_userland EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        ld      hl, dma_cache               ; Copy From
        ld      de, (BDOS.dma_address)      ; Copy To
        ld      bc, 128                     ; Length of Copy
        ldir                                ; ldi repeat. Go.
        ;; Restore kernel
.SMC_MMU4_kernel EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_kernel EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        pop     bc
        pop     de
        pop     af
        ret

; Copy DMA cache to DMA address
copy_dma_in_kernel:
        push    de
        push    bc
        ;; Ensure that all the userland memory is available, incase HL resides behind kernel
.SMC_MMU4_userland EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_userland EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        ld      hl, (BDOS.dma_address)      ; Copy From
        ld      de, dma_cache               ; Copy To
        ld      bc, 128                     ; Length of Copy
        ldir                                ; ldi repeat. Go.
        ;; Restore kernel
.SMC_MMU4_kernel EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_kernel EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        pop     bc
        pop     de
        ret

filesize_buffer:
        ds 6

filesize_buffer_copy:
        ds 6

filesize_units:
        ds 1


;-----------------------------------------------------------------------------
; Caches ensure we have somewhere to R/W when kernel+ROM pagedin
;-----------------------------------------------------------------------------
fcb_cache:
.diskname:
        ds      1           ; Disk Name (Drive letter)
.filename:
        ds      8           ; File Name
.filetype:
        ds      3           ; File Extension
.ex
        ds      1           ; Extent Number
.s1:
        db      0           ; S1
.s2:
        db      0           ; S1
.rc:
        ds      1           ; Record Count
.groupmap:
        ds      16          ; Disk Group Map
.cr:
        db      0           ; Current Record Number
.extra_bytes:
        ds      3
        

dma_cache:

        ds  $80, $00
        

dpblk:
; Fake disk parameter block for all disks
        ; defw	80		;sectors per track
        ; defb	5		;block shift factor	(5 & 31 = 4K Block Size)
        ; defb	31		;block mask
        ; defb	3		;extent mask
        ; defw	196		;disk size 197 * 4k = 788k
        ; defw	127		;directory max
        ; defb	$80		;alloc 0	((DRM + 1) * 32) / 4096 = 1, so 80H
        ; defb	0		;alloc 1
        ; defw	0		;check size ( 0 = fixed disk )
        ; defw	0		;track offset ( 0 = no reserved system tracks )

; These ones were copied from runCPM!
        dw	64		;sectors per track
        db	5		;block shift factor	(5 & 31 = 4K Block Size)
        db	$1F		;block mask
        db	1		;extent mask
        db	$FF		;disk size
        db	$07		;disk size
        db	$FF		;directory max
        db	$03		;directory max
        db	$FF		;alloc 0	((DRM + 1) * 32) / 4096 = 1, so 80H
        db	0		;alloc 1
        dw	0		;check size ( 0 = fixed disk )
        dw	2		;track offset ( 0 = no reserved system tracks )

diskalloc:
        db 0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0
        db 0,0,0,0,0,0,0,0,0
    
dma_address:
        ds 2

current_disk:
        db 0
current_user:
        db 0
        
temp_fcb:
        ds 36


store_target:
        dw 0
    
greeting:
        DB "Fake BDOS Banner", 0

kernel_jump_table:
        dw KERNEL.BDOS_P_TERMCPM                   ;EQU 0        00
        dw KERNEL.BDOS_C_READ                      ;EQU 1        01
        dw KERNEL.BDOS_C_WRITE                     ;EQU 2        02
        dw KERNEL.BDOS_A_READ                      ;EQU 3        03
        dw KERNEL.BDOS_A_WRITE                     ;EQU 4        04
        dw KERNEL.BDOS_L_WRITE                     ;EQU 5        05
        dw KERNEL.BDOS_C_RAWIO                     ;EQU 6        06
        dw KERNEL.BDOS_IO_GET                      ;EQU 7        07
        dw KERNEL.BDOS_IO_SET                      ;EQU 8        08
        dw KERNEL.BDOS_C_WRITESTR                  ;EQU 9        09
        dw KERNEL.BDOS_C_READSTR                   ;EQU 10       0A
        dw KERNEL.BDOS_C_STAT                      ;EQU 11       0B
        dw KERNEL.BDOS_S_BDOSVER                   ;EQU 12       0C
        dw KERNEL.BDOS_DRV_ALLRESET                ;EQU 13       0D
        dw KERNEL.BDOS_DRV_SET                     ;EQU 14       0E
        dw KERNEL.BDOS_F_OPEN                      ;EQU 15       0F
        dw KERNEL.BDOS_F_CLOSE                     ;EQU 16       10
        dw KERNEL.BDOS_F_SFIRST                    ;EQU 17       11
        dw KERNEL.BDOS_F_SNEXT                     ;EQU 18       12
        dw KERNEL.BDOS_F_DELETE                    ;EQU 19       13
        dw KERNEL.BDOS_F_READ                      ;EQU 20       14
        dw KERNEL.BDOS_F_WRITE                     ;EQU 21       15
        dw KERNEL.BDOS_F_MAKE                      ;EQU 22       16
        dw KERNEL.BDOS_F_RENAME                    ;EQU 23       17
        dw KERNEL.BDOS_DRV_LOGINVEC                ;EQU 24       18
        dw KERNEL.BDOS_DRV_GET                     ;EQU 25       19
        dw KERNEL.BDOS_F_DMAOFF                    ;EQU 26       1A
        dw KERNEL.BDOS_DRV_ALLOCVEC                ;EQU 27       1B
        dw KERNEL.BDOS_DRV_SETRO                   ;EQU 28       1C
        dw KERNEL.BDOS_DRV_ROVEC                   ;EQU 29       1D
        dw KERNEL.BDOS_F_ATTRIB                    ;EQU 30       1E
        dw KERNEL.BDOS_DRV_DPB                     ;EQU 31       1F
        dw KERNEL.BDOS_F_USERNUM                   ;EQU 32       20
        dw KERNEL.BDOS_F_READRAND                  ;EQU 33       21
        dw KERNEL.BDOS_F_WRITERAND                 ;EQU 34       22
        dw KERNEL.BDOS_F_SIZE                      ;EQU 35       23
        dw KERNEL.BDOS_F_RANDREC                   ;EQU 36       24
        dw KERNEL.BDOS_DRV_RESET                   ;EQU 37       25
        dw KERNEL.BDOS_38  ; DRV_ACCESS    MP/M    ;
        dw KERNEL.BDOS_39  ; DRV_FREE      MP/M    ;
        dw KERNEL.BDOS_F_WRITEZF                   ;EQU 40       28
        dw KERNEL.BDOS_41  ; Test and write record ;
        dw KERNEL.BDOS_42  ; F_LOCK        MP/M    ;
        dw KERNEL.BDOS_43  ; F_UNLOCK      MP/M    ;
        dw KERNEL.BDOS_44  ; F_MULTISEC    MP/M2   ;
        dw KERNEL.BDOS_F_ERRMODE                   ; eq 45       2D
        dw KERNEL.BDOS_46  ; DRV_SPACE     MP/M2   ;
        dw KERNEL.BDOS_47  ; P_CHAIN       MP/M2   ;
        dw KERNEL.BDOS_48  ; DRV_FLUSH     MP/M2   ;
    ENDMODULE
    
    DISPLAY "BDOS END\t:\t",/H,$
bdos_end:
;-----------------------------------------------------------------------------
; -- Report size, export memory as binary
;-----------------------------------------------------------------------------
bdosBinPcHi     EQU     (100*bdosBinSz)/(256*14)
bdosBinSz       EQU     bdos_end-bdos_start

bdosBinPcLo     EQU     ((100*bdosBinSz)%(256*14))*10/(256*14)
    DISPLAY "BDOS LEN\t:\t",/D,bdosBinSz,"B\t(",/D,bdosBinPcHi,".",/D,bdosBinPcLo,"% of 6.5kiB)"
    
    SAVEBIN "../build/BDOS",bdos_start,bdosBinSz
    DISPLAY "======================================================= <"
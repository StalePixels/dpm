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
        ; A function number past the end of the table returns A=L=0, B=H=0,
        ; as the CP/M 2.2 manual gives for a number out of range.

        ld      a, c                    ; copy parameter from C to A
        cp      49
        jr      c, .exec_func
        xor     a
        ld      b, a
        ld      h, a
        ld      l, a
        ret

.exec_func:
        ld      (.exit_stack), sp            ; Keep the caller's stack pointer, for the way out
        ld      sp, BIOS.stack

        push    de
        ld      hl, kernel_jump_table        ; Base entry in jump table
        ld      e, c                         ; Function number into DE
        ld      d, 0                         ;
        add     hl, de                       ; Add it to HL...
        add     hl, de                       ; ...twice - to get right (16bit) address

        ld      e, (hl): inc hl: ld d, (hl)  ; ld de, (hl)
        ex      de, hl                       ; HL now holds address of the BDOS call
        ld      (.SMC_kernel_func), hl
        pop     de                           ; & DE the parameters for the call

.SMC_MMU4_kernel EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_kernel EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA

    IF DPM_DEBUG
            ld      a, l : call KERNEL_DEBUG.tm_a_loc76
            ld      a, h : call KERNEL_DEBUG.tm_a_loc78
    ENDIF

.SMC_kernel_func EQU $+1
        call    0xAAAA                       ; Kernel routine to call, 0xAAAA is SMC.

.SMC_MMU4_userland EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_userland EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        ld      sp, (.exit_stack)            ; Back to the caller's stack

        ; Kernel routines return their value in A, and B for the high byte of
        ; a 16-bit value. The BDOS returns A = L and B = H in all cases.
        ld      l, a
        ld      h, b
        ret

.exit_stack:
        dw      0


; Copy FCB (pointed to by DE) to cache in BDOS
;   Source FCB can be anywhere in RAM. Should only be called by kernel operations.
;   Returns new FCB in DE, all other registers unchanged
cache_calling_fcb:
        push    af
        ; ld      (.SMC_SOURCE_FCB_COPY), de
        ld      (restore_calling_fcb.SMC_ORIGINAL_FCB_COPY), de
        push    bc      ; Save these ...
        push    hl      ; ... and restore later
        ex      de, hl
        ;; Ensure that all the userland memory is available, incase HL resides behind kernel
.SMC_MMU4_userland EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_userland EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
; .SMC_SOURCE_FCB_COPY EQU $+1
;         ld      hl, (0xAAAA)                ; SMC copy from    
        ld      de, fcb_cache               ; Copy To
        ld      bc, 36                      ; Length of Copy
        ldir                                ; ldi repeat. Go.
        ;; Restore kernel
.SMC_MMU4_kernel EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_kernel EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        ;; And the saved registers
        pop     hl
        pop     bc
        ld      de, fcb_cache               ; Leave DE pointing at new FCB in BDOS
        pop     af
        ret

; Copy FCB from cache in BDOS to address on stack
;   Source FCB can be anywhere in RAM. Should only be called while kernel is paged in.
restore_calling_fcb:
        push     af
        push    de
        push    bc
        ;; Ensure that all the userland memory is available, incase HL resides behind kernel
.SMC_MMU4_userland EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_userland EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        ld      hl, fcb_cache               ; Copy from
.SMC_ORIGINAL_FCB_COPY EQU $+1
        ld      de, 0xAAAA                ; SMC copy from    
        ld      bc, 36                      ; Length of Copy
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

;
; Copy BC bytes from HL to DE with userland paged in over $8000-$BFFF. One end
; is a userland address anywhere in 64K, the other must be always-mapped
; memory here in the BDOS. Should only be called while the kernel is paged in.
; Dirties HL, DE, BC
copy_userland:
        push    af
        ;; Ensure that all the userland memory is available, incase the userland end resides behind kernel
.SMC_MMU4_userland EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_userland EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        ldir                                ; ldi repeat. Go.
        ;; Restore kernel
.SMC_MMU4_kernel EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_kernel EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        pop     af
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
.r0:
        db      0           ; Random Record Number, low byte
.r1:
        db      0           ; ...middle byte
.r2:
        db      0           ; ...high byte
        

dma_cache:

        ds  $80, $00
        
; Console strings (function 9) and edited lines (function 10) are staged here:
; for function 10, +0 is the count read and +1 on the characters.
con_cache:
        ds  $100, $00


; Disk parameter block for every drive (function 31), RunCPM's values: an
; 8 MB disk of 4K blocks with 1024 directory entries. The values are a
; plausible fake; they do not describe the FAT card.
DPB_DSM         EQU     2039            ; Blocks on the disk, less one
dpblk:
        dw	256		;sectors per track
        db	5		;block shift factor	(5 & 31 = 4K Block Size)
        db	$1F		;block mask
        db	1		;extent mask: a directory entry holds two 16K extents
        dw	DPB_DSM		;disk size in blocks, less one
        dw	1023		;directory entries, less one
        db	$FF		;alloc 0	((DRM + 1) * 32) / 4096 = 8 directory blocks
        db	0		;alloc 1
        dw	0		;check size ( 0 = fixed disk )
        dw	1		;track offset

; Allocation vector for every drive (function 27): one bit per block of the
; DPB above. Only the directory blocks are marked in use.
diskalloc:
        db      $FF
        ds      DPB_DSM/8, 0

dma_address:
        ds 2

current_disk:
        db 0
current_user:
        db 0
        
temp_fcb:
        ds 36

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
    DISPLAY "BDOS LEN\t:\t",/D,bdosBinSz,"B\t(",/D,bdosBinPcHi,".",/D,bdosBinPcLo,"% of 3.5kiB)"
    
    SAVEBIN "../build/BDOS",bdos_start,bdosBinSz
    DISPLAY "======================================================= <"
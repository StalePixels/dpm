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
; Six bytes where CP/M 2.2 keeps its serial number, so the entry is at
; BDOS_A+6 as in CP/M 2.2. A program may use them: they hold nothing.
serial:
        ds      6, 0

entry:
        ; The function number is passed in Register C.
        ; The parameter is passed in DE.
        ; Result returned in A or HL. Also, A=L and B=H on return for compatibility reasons.
        ; KERNEL.bdos_dispatch finds the function and handles a number out of range.
        ld      (.exit_stack), sp            ; Keep the caller's stack pointer, for the way out
        ld      sp, BIOS.stack

.SMC_MMU4_kernel EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_kernel EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA

        call    KERNEL.bdos_dispatch         ; Function C, parameter DE

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
        ASSERT  entry == BDOS_ENTRY_A


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
        ld      de, (KERNEL_BDOS.dma_address) ; Copy To, read while the kernel is paged in
        ;; Ensure that all the userland memory is available, incase DE resides behind kernel
.SMC_MMU4_userland EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_userland EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
        ld      hl, dma_cache               ; Copy From
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

; Copy DMA address to DMA cache
copy_dma_in_kernel:
        push    de
        push    bc
        ld      hl, (KERNEL_BDOS.dma_address) ; Copy From, read while the kernel is paged in
        ;; Ensure that all the userland memory is available, incase HL resides behind kernel
.SMC_MMU4_userland EQU $+3:
        nextreg	MMU4_8000_NR_54, 0xAA
.SMC_MMU5_userland EQU $+3:
        nextreg	MMU5_A000_NR_55, 0xAA
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
        

; One CP/M record. Records read and written, directory entries, and console
; strings and lines (functions 9 and 10) pass through it.
DMA_CACHE_LEN   EQU     $80
dma_cache:

        ds  DMA_CACHE_LEN, $00


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
    ENDMODULE
    
    DISPLAY "BDOS END\t:\t",/H,$
bdos_end:
;-----------------------------------------------------------------------------
; -- Report size, export memory as binary
;-----------------------------------------------------------------------------
bdosBinPcHi     EQU     (100*bdosBinSz)/(BIOS_A-BDOS_A)
bdosBinSz       EQU     bdos_end-bdos_start

bdosBinPcLo     EQU     ((100*bdosBinSz)%(BIOS_A-BDOS_A))*10/(BIOS_A-BDOS_A)
    DISPLAY "BDOS LEN\t:\t",/D,bdosBinSz,"B\t(",/D,bdosBinPcHi,".",/D,bdosBinPcLo,"% of the space below the BIOS)"
    ASSERT  bdos_end <= BIOS_A                  ; The BDOS ends below the BIOS
    
    SAVEBIN "../build/BDOS",bdos_start,bdosBinSz
    DISPLAY "======================================================= <"
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
        di                                   ; The kernel runs with interrupts off
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
        ei                                   ; Back in the CP/M program, the cursor blinks
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


;-----------------------------------------------------------------------------
; The frame interrupt: type-ahead and the cursor blink. DP/M runs the Z80 in
; IM 2 with the Next's hardware IM2 vectors (NextReg $C0 bit 0), and only the
; ULA frame interrupt enabled (NextReg $C4). Interrupts are on while a CP/M
; program runs and while the BIOS waits for a key, and off while the kernel
; runs. The vectors and the routine are here because slot 7 holds this page
; in every mapping.
;-----------------------------------------------------------------------------
    MODULE  BLINK
frames          EQU     25                  ; Frames between flips: half a second at 50 Hz

; I is the table's page and NextReg $C0 bits 7:5 its offset in the page.
; Vector n is at 2n; vector 11 is the ULA frame interrupt.
    ALIGN   32
vectors:
        DUP     11
        DW      ignore
        EDUP
        DW      frame
        DUP     4
        DW      ignore
        EDUP
        ASSERT  (vectors & $1F) == 0 && $-vectors == 32

; While a CP/M program runs, scan the keyboard for a new key and put its
; bytes in the console queue (KERNEL.console_scan), so a key pressed while
; the program is busy waits there until it is read. The kernel goes into
; slots 4 and 5 for the scan, and the userland pages go back after. While
; BIOS_CONIN waits (waiting is not 0) the kernel is mapped and scans the
; keyboard itself, so the keyboard state and the queue are left alone: the
; kernel touches them only with interrupts off or in that wait.
; Every frames frames, flip the reverse bit of the cursor's cell, with bank
; 5 in slots 2 and 3, and the userland pages back after.
; The pages change with NEXTREG, which leaves the NextReg select port $243B
; alone. The routine runs on its own stack, so the interrupted stack holds
; only the return address.
frame:
        ld      (interrupted_sp), sp
        ld      sp, stack
        push    af
        push    hl
        ld      a, (waiting)
        or      a                           ; Is BIOS_CONIN waiting?
        jr      nz, .blink                  ; ...Yes, it scans the keyboard
        push    bc
        push    de
.SMC_MMU4_kernel EQU $+3:
        nextreg MMU4_8000_NR_54, $AA        ; The kernel, $AA replaced at setup
.SMC_MMU5_kernel EQU $+3:
        nextreg MMU5_A000_NR_55, $AA
        call    KERNEL.console_scan         ; A new key into the console queue
.SMC_MMU4_userland EQU $+3:
        nextreg MMU4_8000_NR_54, $AA        ; Userland, $AA replaced at setup
.SMC_MMU5_userland EQU $+3:
        nextreg MMU5_A000_NR_55, $AA
        pop     de
        pop     bc
.blink:
        ld      hl, count
        dec     (hl)
        jr      nz, .done
        ld      (hl), frames
        ld      hl, (cell)
        ld      a, h
        or      l
        jr      z, .done                    ; No cursor
        nextreg MMU2_4000_NR_52, $0A        ; Bank 5, the tilemap
        nextreg MMU3_6000_NR_53, $0B
        ld      a, (hl)
        xor     attrReverse
        ld      (hl), a
.SMC_MMU2 EQU $+3:
        nextreg MMU2_4000_NR_52, $AA        ; Userland, $AA replaced at setup
.SMC_MMU3 EQU $+3:
        nextreg MMU3_6000_NR_53, $AA
.done:
        pop     hl
        pop     af
        ld      sp, (interrupted_sp)
ignore:
        ei
        reti

count:                                      ; Frames to the next flip
        db      frames
cell:                                       ; The cursor's attribute byte, 0 for no cursor
        dw      0
waiting:                                    ; Not 0 while BIOS_CONIN waits for a key
        db      0
interrupted_sp:                             ; The interrupted program's stack pointer
        dw      0
        ds      32, $AA                     ; The routine's stack: its registers and console_scan
stack:
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
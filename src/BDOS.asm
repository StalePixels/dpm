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
        ld      (restore_calling_fcb.SMC_ORIGINAL_FCB_COPY), de
        push    bc      ; Save these ...
        push    hl      ; ... and restore later
        ex      de, hl
        ld      de, fcb_cache               ; Copy To
        ld      bc, 36                      ; Length of Copy
        call    copy_userland
        pop     hl
        pop     bc
        ld      de, fcb_cache               ; Leave DE pointing at new FCB in BDOS
        ret

; Copy FCB from cache in BDOS to address on stack
;   Source FCB can be anywhere in RAM. Should only be called while kernel is paged in.
restore_calling_fcb:
        push    de
        push    bc
        ld      hl, fcb_cache               ; Copy from
.SMC_ORIGINAL_FCB_COPY EQU $+1
        ld      de, 0xAAAA                ; SMC copy from    
        ld      bc, 36                      ; Length of Copy
        call    copy_userland
        pop     bc
        pop     de
        ret

;
; Copy DMA cache to DMA address
copy_dma_out_kernel:
        push    de
        push    bc
        ld      de, (KERNEL_BDOS.dma_address) ; Copy To, read while the kernel is paged in
        ld      hl, dma_cache               ; Copy From
        ld      bc, 128                     ; Length of Copy
        call    copy_userland
        pop     bc
        pop     de
        ret

; Copy DMA address to DMA cache
copy_dma_in_kernel:
        push    de
        push    bc
        ld      hl, (KERNEL_BDOS.dma_address) ; Copy From, read while the kernel is paged in
        ld      de, dma_cache               ; Copy To
        ld      bc, 128                     ; Length of Copy
        call    copy_userland
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
; The interrupts: the frame interrupt, for type-ahead and the cursor blink,
; and the two UART Rx interrupts, which empty a UART's Rx buffer into its
; ring. DP/M runs the Z80 in IM 2 with the Next's hardware IM2 vectors
; (NextReg $C0 bit 0), with the ULA frame interrupt (NextReg $C4) and the
; UARTs' Rx near full interrupts (NextReg $C6) enabled. Interrupts are on
; while a CP/M program runs and while the BIOS waits for a key or a UART,
; and off while the kernel runs. The vectors and the routines are here
; because slot 7 holds this page in every mapping.
;-----------------------------------------------------------------------------
    MODULE  BLINK
frames          EQU     25                  ; Frames between flips: half a second at 50 Hz

; I is the table's page and NextReg $C0 bits 7:5 its offset in the page.
; Vector n is at 2n; vector 1 is the ESP's UART Rx, 2 the Pi's, 11 the ULA
; frame interrupt.
    ALIGN   32
vectors:
        DW      ignore
        DW      esp_rx
        DW      pi_rx
        DUP     8
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
; the kernel waits for a key or a UART (waiting is not 0) the kernel is
; mapped and scans the keyboard itself, so the keyboard state and the queue
; are left alone: the kernel touches them only with interrupts off or in
; that wait.
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
        or      a                           ; Is the kernel waiting?
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

; A UART's Rx interrupt: move every byte in its Rx buffer to the end of its
; ring (see esp_ring). With the ring full, the byte is read and dropped, and
; dropped is set. The ring's pages go into slot 6 for this and the userland
; page back after; while interrupts are on, slot 6 always holds userland.
; Port $153B is put back as it was, so the interrupted code keeps the UART
; it had selected. The routine runs on the frame interrupt's stack.
esp_rx:
        ld      (interrupted_sp), sp
        ld      sp, stack
        push    af
        push    ix
        ld      ix, esp_ring
        ld      a, %00000000                ; $153B: the ESP
        jr      rx
pi_rx:
        ld      (interrupted_sp), sp
        ld      sp, stack
        push    af
        push    ix
        ld      ix, pi_ring
        ld      a, %01000000                ; $153B: the Pi
rx:
        push    bc
        push    de
        push    hl
        ld      bc, $153B                   ; UART select
        ld      e, a
        in      a, (c)
        and     %01000000
        push    af                          ; The UART selected as found
        out     (c), e
        ld      e, (ix+0)
        ld      d, (ix+1)                   ; DE = head
        ld      l, (ix+2)
        ld      h, (ix+3)                   ; HL = tail, where the next byte goes
.next:
        ld      b, $13                      ; $133B, status
        in      a, (c)
        rrca                                ; A byte waiting?
        jr      nc, .empty                  ; ...No
        push    hl
        ld      a, h
        rlca
        rlca
        rlca
        and     RING_PAGES-1                ; The page the tail is in, tail bits 15:13
        add     a, esp_ring.pages-esp_ring
        push    ix
        pop     hl
        add     hl, a
        ld      a, (hl)
        nextreg MMU6_C000_NR_56, a
        pop     hl
        push    hl
        ld      a, h
        and     $1F
        or      $C0                         ; Its address in slot 6
        ld      h, a
        inc     b                           ; $143B
        in      a, (c)
        ld      (hl), a                     ; The tail is free whether the ring is full or not
        pop     hl
        inc     hl                          ; The next tail, round the ring
        ld      a, l
        cp      e
        jr      nz, .next
        ld      a, h
        cp      d
        jr      nz, .next
        dec     hl                          ; Full: the byte is dropped
        ld      a, $FF
        ld      (dropped), a
        jr      .next
.empty:
        ld      (ix+2), l                   ; The new tail
        ld      (ix+3), h
.SMC_MMU6 EQU $+3:
        nextreg MMU6_C000_NR_56, $AA        ; Userland, $AA replaced at setup
        pop     af
        ld      b, $15                      ; $153B
        out     (c), a                      ; The UART selected as it was
        pop     hl
        pop     de
        pop     bc
        pop     ix
        pop     af
        ld      sp, (interrupted_sp)
        ei
        reti

; Each UART's ring is 64K in RING_PAGES 8K pages of its own: head, the
; oldest byte, and tail, where the next byte goes, both offsets in the ring,
; 0 to $FFFF, and equal when the ring is empty; then the page numbers, set
; at setup. Offset n is in page n >> 13, at $C000 + (n AND $1FFF) with that
; page in slot 6. The interrupt moves the tail and the kernel the head.
    ASSERT  RING_PAGES == 8                 ; 64K: the offsets wrap round with 16-bit arithmetic
esp_ring:
        dw      0, 0
.pages:
        ds      RING_PAGES, 0
pi_ring:
        dw      0, 0
.pages:
        ds      RING_PAGES, 0
dropped:                                    ; $FF once a full ring has dropped a byte
        db      0
ring:                                       ; The ring of the UART KERNEL_SERIAL.select chose
        dw      pi_ring

; Z if the ring at HL is empty, else NZ.
;     Dirties AF, HL
ring_empty:
        ld      a, (hl)
        inc     hl
        inc     hl
        cp      (hl)                        ; Head and tail, low bytes
        ret     nz
        dec     hl
        ld      a, (hl)
        inc     hl
        inc     hl
        cp      (hl)                        ; High bytes
        ret

; Takes the oldest byte from the selected UART's ring (ring). Returns NC
; with the byte in A, or C if the ring is empty. Runs with interrupts off,
; which keeps the Rx interrupts out of the ring meanwhile.
;     Dirties AF, BC, DE, HL
ring_take:
        ld      hl, (ring)
        call    ring_empty
        scf
        ret     z                           ; Empty
        ld      hl, (ring)
        ld      e, (hl)
        inc     hl
        ld      d, (hl)                     ; DE = head
        ld      a, d
        rlca
        rlca
        rlca
        and     RING_PAGES-1                ; The page the head is in, head bits 15:13
        add     a, esp_ring.pages-esp_ring-1
        add     hl, a
        ld      a, (hl)
        nextreg MMU6_C000_NR_56, a
        ld      a, d
        and     $1F
        or      $C0                         ; Its address in slot 6
        ld      h, a
        ld      l, e
        ld      c, (hl)                     ; The byte
.SMC_MMU6 EQU $+3:
        nextreg MMU6_C000_NR_56, $AA        ; Userland, $AA replaced at setup
        inc     de                          ; The next head, round the ring
        ld      hl, (ring)
        ld      (hl), e
        inc     hl
        ld      (hl), d
        ld      a, c
        or      a                           ; NC
        ret

; With CON: on BAT: and RDR: on the ESP (PTR:) or the Pi (UR1:), selects
; that UART and its ring as KERNEL_SERIAL.select does and returns NC, BC =
; $133B, and Z with A = 0 if the ring is empty or NZ with A = $FF if not.
; Otherwise returns C. C is the IOBYTE XOR 2 on return. bat_uart.rdr is the
; same with that already in A and C, and CON: on BAT:.
;     Dirties AF, BC, HL
bat_uart:
        ld      a, (IOBYTE_A)
        xor     %00000010                   ; CON: BAT: gives 0 in bits 1:0
        ld      c, a
.rdr:
        and     %00001111                   ; CON: and RDR:
        cp      %00000100                   ; BAT: and PTR:, the ESP
        jr      nz, .pi
        ld      hl, esp_ring
        xor     a                           ; $153B: the ESP
        jr      .select
.pi:
        cp      %00001000                   ; BAT: and UR1:, the Pi
        jr      nz, .other
        ld      hl, pi_ring
        ld      a, %01000000                ; $153B: the Pi
        jr      .select
.other:                                     ; Not BAT:, or RDR: on TTY: or UR2:
        scf
        ret
.select:
        ld      bc, $153B
        out     (c), a
        ld      (ring), hl
        ld      b, $13                      ; $133B
        ld      a, (hl)                     ; As ring_empty
        inc     hl
        inc     hl
        cp      (hl)                        ; Head and tail, low bytes
        jr      nz, .bytes
        dec     hl
        ld      a, (hl)
        inc     hl
        inc     hl
        cp      (hl)                        ; High bytes
        jr      nz, .bytes
        ld      a, 0                        ; Empty: Z, NC
        ret
.bytes:
        or      $FF                         ; NZ, NC
        ret

count:                                      ; Frames to the next flip
        db      frames
cell:                                       ; The cursor's attribute byte, 0 for no cursor
        dw      0
waiting:                                    ; Not 0 while the kernel waits for a key or a UART
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
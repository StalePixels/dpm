;-----------------------------------------------------------------------------
; -- DPM BDOS functions
; 
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FCB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------
    MODULE KERNEL_BDOS

; The portions of the BDOS+helpers unique to it, stored in the kernel memoryspace


; Open files are kept in handle_table, keyed by drive, user and name. The FCB
; is the only record of a file's position: every read seeks from it, so a
; slot holds nothing but the esxdos handle. When every slot is in use, the
; least recently used file is closed to make room.
;
; Each slot is HANDLE_SIZE bytes:
HANDLE.in_use   EQU     0               ; HANDLE_RW or HANDLE_RO when the slot holds an open file, else 0
HANDLE.esx      EQU     1               ; esxdos file handle
HANDLE.rank     EQU     2               ; 0 = most recently used ... HANDLE_SLOTS-1 = least
HANDLE.key      EQU     3               ; Drive (0-15), user (0-15), 8+3 name
HANDLE_KEY_LEN  EQU     13
HANDLE_SIZE     EQU     16
HANDLE_RW       EQU     1               ; HANDLE.in_use: opened read+write
HANDLE_RO       EQU     2               ; HANDLE.in_use: opened read only
;
; esxdos has 15 file handles for DP/M (directory handles are counted apart).
; The table uses fewer, leaving the rest for files opened briefly by other
; functions.
HANDLE_SLOTS    EQU     8

;
; Build handle_key for the FCB pointed to by DE: drive (0-15, a drive byte of
; 0 means the current disk), current user, and the 8+3 name with attribute
; bits (bit 7) masked off and lower case folded to upper.
; Preserves DE. Dirties AF, BC, HL
handle_make_key:
        push    de
        ld      hl, handle_key
        ld      a, (de)                     ; Drive byte, 0 = current disk, 1-16 = A-P
        or      a
        jr      nz, .drive_given
        ld      a, (current_disk)      ; Current disk is indexed from 0...
        inc     a                           ; ...so adjust it to match the FCB
.drive_given:
        dec     a                           ; Drives indexed from 0 again
        and     %00001111
        ld      (hl), a
        inc     hl
        ld      a, (current_user)      ; FCBs don't carry the user
        ld      (hl), a
        inc     hl
        ld      b, 11                       ; 8+3 name
.name_char:
        inc     de
        ld      a, (de)
        and     %01111111                   ; Drop the attribute bit
        cp      'a'
        jr      c, .store
        cp      'z'+1
        jr      nc, .store
        and     %01011111                   ; Fold lower case to upper
.store:
        ld      (hl), a
        inc     hl
        djnz    .name_char
        pop     de
        ret

;
; Find the slot in use whose key matches handle_key.
; Returns Z with HL = slot, or NZ if no slot matches. Dirties AF, BC, DE
handle_find:
        ld      hl, handle_table
        ld      b, HANDLE_SLOTS
.slot:
        push    bc
        push    hl
        ld      a, (hl)                     ; HANDLE.in_use
        or      a
        jr      z, .next                    ; Free slot, skip it
        ld      de, HANDLE.key
        add     hl, de
        ld      de, handle_key
        ld      b, HANDLE_KEY_LEN
.compare:
        ld      a, (de)
        cp      (hl)
        jr      nz, .next
        inc     de
        inc     hl
        djnz    .compare
        pop     hl                          ; Match, HL = slot
        pop     bc
        xor     a                           ; Z
        ret
.next:
        pop     hl
        pop     bc
        ld      de, HANDLE_SIZE
        add     hl, de
        djnz    .slot
        or      1                           ; NZ, not found
        ret

;
; Make the slot at HL the most recently used: each slot used more recently
; than it moves one rank older, and it takes rank 0. The ranks stay a
; permutation of 0 to HANDLE_SLOTS-1.
; Preserves HL. Dirties AF, BC, DE
handle_touch:
        push    hl
        ld      de, HANDLE.rank
        add     hl, de
        ld      c, (hl)                     ; This slot's rank
        ld      (hl), 0                     ; ...becomes the newest
        ld      hl, handle_table+HANDLE.rank
        ld      de, HANDLE_SIZE
        ld      b, HANDLE_SLOTS
.age:
        ld      a, (hl)
        cp      c                           ; Newer than this slot was?
        jr      nc, .keep                   ; ...No (or it is this slot)
        inc     (hl)                        ; ...Yes, one rank older
.keep:
        add     hl, de
        djnz    .age
        pop     hl
        ret

;
; Find a slot for a new file: a free one if there is one, else the least
; recently used, after closing its file.
; Returns HL = slot. Dirties AF, BC, DE
handle_alloc:
        ld      hl, handle_table
        ld      de, HANDLE_SIZE
        ld      b, HANDLE_SLOTS
.free:
        ld      a, (hl)                     ; HANDLE.in_use
        or      a
        ret     z                           ; Free slot
        add     hl, de
        djnz    .free
        ld      hl, handle_table+HANDLE.rank
        ld      b, HANDLE_SLOTS
.oldest:
        ld      a, (hl)
        cp      HANDLE_SLOTS-1              ; Least recently used?
        jr      z, .found
        add     hl, de
        djnz    .oldest
.found:
        ld      de, -HANDLE.rank
        add     hl, de                      ; HL = slot
        ; Fall through to close it

;
; Close the file held by the slot at HL, if any, and free the slot.
; Preserves HL. Dirties AF, BC, DE
handle_close_slot:
        ld      a, (hl)                     ; HANDLE.in_use
        or      a
        ret     z                           ; Already free
        ld      (hl), 0                     ; Free it
        push    hl
        inc     hl
        ld      a, (hl)                     ; HANDLE.esx
        m_kr_esxdos F_CLOSE
        pop     hl
        ret

;
; Close every file in the table.
; Preserves DE. Dirties AF, BC, HL
handle_close_all:
        push    de
        ld      hl, handle_table
        ld      b, HANDLE_SLOTS
.slot:
        push    bc
        call    handle_close_slot
        ld      de, HANDLE_SIZE
        add     hl, de
        pop     bc
        djnz    .slot
        pop     de
        ret

;
; Close every file in the table that is on a drive whose bit is set in DE
; (bit 0 drive A to bit 15 drive P).
; Preserves DE. Dirties AF, BC, HL
handle_close_drives:
        ld      hl, handle_table
        ld      b, HANDLE_SLOTS
.slot:
        push    bc
        push    de
        push    hl
        ld      a, (hl)                     ; HANDLE.in_use
        or      a
        jr      z, .next                    ; Free slot
        ld      bc, HANDLE.key
        add     hl, bc
        ld      a, (hl)                     ; The file's drive
        call    drive_bit                   ; HL = its vector bit
        ld      a, l
        and     e
        ld      c, a
        ld      a, h
        and     d
        or      c
        pop     hl
        push    hl                          ; Slot
        call    nz, handle_close_slot       ; On a drive being reset
.next:
        pop     hl
        pop     de
        ld      bc, HANDLE_SIZE
        add     hl, bc
        pop     bc
        djnz    .slot
        ret

;
; Close the table's handle on the file named by the FCB at DE, if it has one.
; Preserves DE. Dirties AF, BC, HL
handle_close_fcb:
        call    handle_make_key
        push    de
        call    handle_find
        call    z, handle_close_slot
        pop     de
        ret

;
; Get the esxdos handle for the file named by the FCB at DE: the table's
; handle if it has one, else the file is opened into a slot, read+write, or
; read only when esxdos refuses write access (a FAT read-only file).
; Reads and writes through one FCB share the handle, because esxdos opens a
; file read+write only once.
; Returns A = handle with carry clear, and io_readonly non-zero when the
; handle is read only; or carry set if the file cannot be opened.
; Preserves DE. Dirties BC, HL
handle_open_fcb:
        call    handle_make_key
        push    de
        call    handle_find                 ; HL = slot, Z if the file is open
        jr      nz, .open
        call    handle_touch
        pop     de
        ld      a, (hl)                     ; HANDLE.in_use
        sub     HANDLE_RW                   ; 0 when read+write
        ld      (io_readonly), a
        inc     hl
        ld      a, (hl)                     ; HANDLE.esx
        or      a                           ; Clear carry
        ret
.open:
        pop     de
        xor     a
        ld      (io_readonly), a
        ld      c, esx_mode_read + esx_mode_write + esx_mode_open_exist ; Open Read+Write, if file exists
        call    handle_open_slot
        ret     nc
        ld      c, esx_mode_read + esx_mode_open_exist ; Open read only, if file exists
        call    handle_open_slot            ; HL = slot
        ret     c
        ld      (hl), HANDLE_RO
        push    af
        ld      a, 1
        ld      (io_readonly), a
        pop     af                          ; A = handle, carry clear
        ret

;
; Create the file named by the FCB at DE, which must not exist yet, and open
; it read+write into a slot.
; Returns A = handle with carry clear, or carry set if the file exists or
; cannot be created. Preserves DE. Dirties BC, HL
handle_create_fcb:
        call    handle_close_fcb            ; Builds handle_key; a slot left on the name is given up
        ld      c, esx_mode_read + esx_mode_write + esx_mode_creat_noexist ; Create Read+Write, if no such file
        ; Fall through to open it

;
; Open the file named by the FCB at DE with esxdos access mode C into a free
; slot (handle_alloc), keyed by handle_key, which must already be the FCB's.
; Returns A = handle with carry clear and HL = the slot, which is marked
; HANDLE_RW; or carry set if esxdos fails, and the slot stays free.
; Preserves DE. Dirties BC
handle_open_slot:
        push    de
        push    bc
        call    handle_alloc                ; HL = free slot
        pop     bc
        pop     de                          ; FCB
        push    de
        push    hl
        push    bc
        call    copy_fcb_to_buffers         ; Parse the relevent filedir and filename out of the FCB
        xor     a                           ; Flag to denote source of filename. 0==buffer
        call    copy_buffers_to_fullpath    ; And join them together for an ESXDOS file call
        pop     bc
        ld      b, c                        ; Access mode
        ld      a, '*'                      ; This doesn't matter, pathspec overrides it
        ld      hl, current_esxdos.fullpath ; Full drive/path/filename combi, by copy_buffers_to_fullpath
        m_kr_esxdos F_OPEN
        pop     hl                          ; Slot
        pop     de                          ; FCB
        ret     c                           ; Not opened, the slot stays free
        ld      (hl), HANDLE_RW             ; HANDLE.in_use
        inc     hl
        ld      (hl), a                     ; HANDLE.esx
        dec     hl
        push    af
        push    de
        push    hl
        ld      de, HANDLE.key
        add     hl, de
        ex      de, hl                      ; DE = slot's key
        ld      hl, handle_key
        ld      bc, HANDLE_KEY_LEN
        ldir
        pop     hl
        call    handle_touch
        pop     de
        pop     af
        or      a                           ; Clear carry, A = handle
        ret

;
; Copy the current_esxdos.filepath and current_esxdos.filename to current_esxdos.pullpath
; uses A to denote filename source, 0=buffers, 1=buffered entry. Preserves DE, HL. Dirties AF
copy_buffers_to_fullpath:
        push    de
        push    hl
        push    af                                  ; Preserve the filename source flag in A
        ld      de, KERNEL_BDOS.current_esxdos.filepath; Point DE to start of filepath
        ld      hl, KERNEL_BDOS.current_esxdos.fullpath; Point HL to start of destination
.find_end_of_path:
        ld      a, (de)                             ; Get character pointed to by DE
        cp      0                                   ; End of string?
        jr      z, .end_of_path                     ; ...Yes! Let's append the filename
        ld      (hl), a                             ; ...No! Append char to destination
        inc     de                                  ; Move both pointers
        inc     hl                                  ;    along one byte
        jr      .find_end_of_path
.end_of_path:
        pop     af                                  ; Restore A, filename source. 0=Buff, 1=ESXDOS entry
        or      a                                   ; Set flags properly for A value
        cp      0                                   ; Is the source set to be filename buffer?
        jr      z, .use_filename_buffer             ; ....Yes!
        ld      de, KERNEL_BDOS.current_esxdos.entry+1; ....No. Use ESXDOS entry+1 (bypass attr byte)
        jr      .append_filename
.use_filename_buffer:
        ld      de, KERNEL_BDOS.current_esxdos.filename; Point HL to start of filename
.append_filename:
        ld      a, (de)                             ; Get byte
        ld      (hl), a                             ; Save byte (before nullcheck, as want nulls too)
        cp      0                                   ; End of string?
        jr      z, .filename_done                   ; ...Yep! Move along to delete
        inc     de                                  ; Move pointer along in filepath
        inc     hl                                  ; Move pointer along in filename
        jr      .append_filename                    ;  -- and loop!
.filename_done:
        pop     hl
        pop     de
        ret                                         ; Fin!
;
; Transfer all the filename from fcb. pointed to by DE to the filename_buffer.
; Skip NULLs spaces and add in the ".", and terminate with NULL. The
; attribute bit (bit 7) of each name character is dropped. The drive is
; marked as logged in (function 24).
; Preserves DE. Dirties A, B, C, HL
copy_fcb_to_buffers:
        push    de                          ; Save FCB pointer on stack
        ld      a, (de)                     ; First byte in FCB is 0 or 1-16. We want 0=>A, 15=>P
        ld      (KERNEL_BDOS.current_esxdos.diskname), a; Save this into the cache, to go with file and path
        cp      0                           ; 0 = no explicit drive passed
        jr      nz, .drive_and_user_to_path ;   Yes, use that
        ld      a, (current_disk)      ;   No, load default, which is indexed from 0
        inc     a                           ;       Adjust 0-15 to 1-16
.drive_and_user_to_path:
        dec     a                           ; +1&-1 Hack works, drives indexed from 0 again.
        and     %00001111
        ld      b, a                        ; Copy drive letter into B
        call    set_login_drive
        ld      a, (current_user)      ; Load current user, FCBs don't carry this
        ld      c, a                        ; Copy User number letter into c
        
        ld      hl, KERNEL_BDOS.current_esxdos.filepath

        ; Setup drive in B, 0==A, 1==B, etc.   User in C, 0 thru 15.  HL==buffer start.
        call    KERNEL_BDOS.drive_and_user_to_path; Call the converter, returns with HL = end of Path
        ; Fall through to filename
        
.filename
        pop     hl : push hl                ; hl = FCB, again, keep original DE on stack
        inc     hl                          ; hl now points to filename start
        ld      de, KERNEL_BDOS.current_esxdos.filename; de = filename_buffer
        ld      b, 8
        ld      c, 0
.fcb_append_filename:                   ; Part 1== filename
        ld      a, (hl)                     ; a contains filename char
        inc     hl
        and     %01111111                   ; Drop the attribute bit
        cp      0                           ; is A==NULL, EoFilepart
        jr      z, .fcb_append_dot
        cp      ' '                         ; or A==" ", also EoFilepart
        jr      z, .fcb_append_dot
        ld      (de), a                     ; append valid char to buffer
        inc     de                          ; extend string
        djnz    .fcb_append_filename        ; do it all again, hl already +1ed
.fcb_append_dot:                       ; Part 2==dot
        ld      a, '.'                      ; ...seperator dot
        ld      (de), a                     ; ...Append to filename cache
        inc     de                          ; Extend filename cache String
        pop     hl : push hl                ; Put FCB in HL, again
        ld      bc, 9                       ; Move along by 9 places (drive no+filename)
        add     hl, bc                      ; HL now points at extension

        ld      b, 3
.fcb_append_fileext:                    ; Part 3==Extension
        ld      a, (hl)                     ; Load character
        inc     hl                          ; move pointer
        and     %01111111                   ; Drop the attribute bit
        cp      0                           ; Is A==NULL, EoFileext
        jr      z, .done
        cp      ' '                         ; or A==" ", also EoFileext
        jr      z, .done
        ld      (de), a
        inc     de
        djnz    .fcb_append_fileext
.done:
        xor     a                           ; A=0
        ld      (de),a                      ; Terminate string
        pop     de                          ; Restore DE, balance stack
        ret
        

;
;-----------------------------------------------------------------------------
; Drives: login and read-only vectors
;-----------------------------------------------------------------------------

;
; HL = the vector bit for drive A (0-15): 1 for A:, 2 for B: ... $8000 for P:.
; Preserves BC, DE. Dirties AF
drive_bit:
        push    bc
        and     %00001111
        ld      b, a
        inc     b
        ld      hl, 1
        jr      .count
.shift:
        add     hl, hl
.count:
        djnz    .shift
        pop     bc
        ret

;
; Mark drive A (0-15) as logged in (function 24).
; Preserves BC, DE, HL. Dirties AF
set_login_drive:
        push    hl
        push    de
        call    drive_bit
        ld      de, (login_vector)
        ld      a, l
        or      e
        ld      l, a
        ld      a, h
        or      d
        ld      h, a
        ld      (login_vector), hl
        pop     de
        pop     hl
        ret

;
; A = the drive (0-15) the cached FCB names: its drive byte, or the current
; disk when that is 0.
fcb_drive:
        ld      a, (BDOS.fcb_cache)
        or      a
        jr      nz, .given
        ld      a, (current_disk)      ; Current disk is indexed from 0...
        inc     a                           ; ...so adjust it to match the FCB
.given:
        dec     a
        and     %00001111
        ret

;
; Give the R/O error, which does not return, if the drive the cached FCB
; names is read-only (function 28).
; Returns A = the drive. Preserves BC, DE. Dirties HL
check_drive_writable:
        call    fcb_drive
        push    af
        call    drive_bit
        ld      a, (ro_vector)
        and     l
        ld      l, a
        ld      a, (ro_vector+1)
        and     h
        or      l
        jr      nz, .read_only
        pop     af
        ret
.read_only:
        pop     af
        jp      KERNEL.error_ro_drive

;
;-----------------------------------------------------------------------------
; Records: the file I/O shared by sequential and random access
;-----------------------------------------------------------------------------

;
; Read the record at the cached FCB's position into the DMA address. The
; position is not moved. A short last record is padded with ^Z.
; Returns A=0, or A=1 with the DMA untouched when the file has no record
; there or cannot be opened.
read_record:
        ld      de, BDOS.fcb_cache
        call    handle_open_fcb             ; A = esxdos handle of the file
        jr      c, .none                    ; ...File cannot be opened, no data
        ld      (io_handle), a
        ld      de, BDOS.fcb_cache
        call    get_block_num_from_fcb      ; BCDE = record number
        call    KERNEL_MATHS.mul_bcde_by_128; BCDE = byte offset
        call    seek_io
        jr      nz, .none                   ; The file ends before the record
        ld      a, (io_handle)
        call    read_128_bytes_to_dma       ; A = 0, or 1 when no bytes are left
        ret     nc
.none:
        ld      a, 1
        ret

;
; Write the 128 byte record at the DMA address to the file at the cached
; FCB's position. The position is not moved. A position past the end of the
; file first extends it with zeroes (esxdos F_FTRUNCATE erases what it adds).
; A read-only drive or file gives the R/O error, which does not return.
; Returns A=0, 2 when the write fails (disk full), or 255 when the file does
; not exist.
write_record:
        call    check_drive_writable
        ld      de, BDOS.fcb_cache
        call    handle_open_fcb             ; A = esxdos handle of the file
        jr      c, .missing
        ld      (io_handle), a
        ld      a, (io_readonly)
        or      a
        jr      nz, .read_only
        ld      de, BDOS.fcb_cache
        call    get_block_num_from_fcb      ; BCDE = record number
        call    KERNEL_MATHS.mul_bcde_by_128; BCDE = byte offset
        call    seek_io
        jr      z, .write                   ; At the record
        ld      de, (io_offset)             ; esxdos stops a seek at the end of the file
        ld      bc, (io_offset+2)
        ld      a, (io_handle)
        m_kr_esxdos F_FTRUNCATE             ; Extend the file to the record, with zeroes
        jr      c, .fail
        call    seek_io_offset
        jr      nz, .fail
.write:
        call    BDOS.copy_dma_in_kernel     ; The record, into dma_cache
        ld      a, (io_handle)
        ld      hl, BDOS.dma_cache
        ld      bc, 128
        m_kr_esxdos F_WRITE
        jr      c, .fail
        ld      a, b
        or      a
        jr      nz, .fail
        ld      a, c
        cp      128
        jr      nz, .fail                   ; Not all of the record was written
        xor     a
        ret
.fail:
        ld      a, 2                        ; 2 = disk full
        ret
.missing:
        ld      a, 255
        ret
.read_only:
        call    fcb_drive
        jp      KERNEL.error_ro_file

;
; Shorten the file held by the slot at HL to the cached FCB's rc, as CP/M's
; close does when it writes a lowered rc to the directory (the CCP shortens
; $$$.SUB this way). Only when the file ends within the extent the FCB names
; and rc records from that extent's start are fewer than the file holds; a
; read-only handle is left alone. cr is kept.
; Returns carry set if esxdos fails. Dirties AF, BC, DE, HL
truncate_to_rc:
        ld      a, (hl)                     ; HANDLE.in_use
        cp      HANDLE_RW
        ret     nz                          ; Read only (carry clear)
        inc     hl
        ld      a, (hl)                     ; HANDLE.esx
        ld      (io_handle), a
        ld      hl, current_esxdos.stats
        m_kr_esxdos F_FSTAT
        ret     c
        ld      a, (BDOS.fcb_cache.cr)
        push    af                          ; The caller's cr
        ld      a, 128
        ld      (BDOS.fcb_cache.cr), a
        ld      de, BDOS.fcb_cache
        call    get_block_num_from_fcb
        call    KERNEL_MATHS.mul_bcde_by_128; BCDE = byte offset of the extent's end
        ex      de, hl
        ld      de, (current_esxdos.stats+7); File size, low word
        or      a
        sbc     hl, de
        ld      h, b
        ld      l, c
        ld      de, (current_esxdos.stats+9); File size, high word
        sbc     hl, de
        jr      c, .keep                    ; The file goes on past this extent
        ld      a, (BDOS.fcb_cache.rc)
        ld      (BDOS.fcb_cache.cr), a
        ld      de, BDOS.fcb_cache
        call    get_block_num_from_fcb
        call    KERNEL_MATHS.mul_bcde_by_128; BCDE = byte offset of the end of rc
        ld      (io_offset), de
        ld      (io_offset+2), bc
        ex      de, hl
        ld      de, (current_esxdos.stats+7)
        or      a
        sbc     hl, de
        ld      h, b
        ld      l, c
        ld      de, (current_esxdos.stats+9)
        sbc     hl, de
        jr      nc, .keep                   ; rc does not cut the file short
        ld      de, (io_offset)
        ld      bc, (io_offset+2)
        ld      a, (io_handle)
        m_kr_esxdos F_FTRUNCATE
        jr      c, .fail
.keep:
        pop     af
        ld      (BDOS.fcb_cache.cr), a
        or      a                           ; Clear carry
        ret
.fail:
        pop     af
        ld      (BDOS.fcb_cache.cr), a
        scf
        ret

;
; Seek the file io_handle to the byte offset BCDE, which is kept in
; io_offset; seek_io_offset seeks to io_offset again. esxdos stops a seek at
; the end of the file.
; Returns Z when the file position is the offset, NZ when the file ends
; before it or the seek fails. Dirties AF, BC, DE, HL
seek_io:
        ld      (io_offset), de
        ld      (io_offset+2), bc
seek_io_offset:
        ld      de, (io_offset)
        ld      bc, (io_offset+2)
        ld      a, (io_handle)
        ld      l, esx_seek_set             ; Absolute position
        m_kr_esxdos F_SEEK                  ; BCDE = the position reached
        jr      c, .fail
        ld      hl, (io_offset)
        or      a
        sbc     hl, de
        ret     nz
        ld      hl, (io_offset+2)
        sbc     hl, bc
        ret
.fail:
        or      1                           ; NZ
        ret

;
; Set the cached FCB's cr, ex and s2 to the random record r0, r1 (functions
; 33, 34 and 40). s2's bit 7 is kept.
; Returns Z, or NZ with the FCB unchanged when r2 is not zero.
random_to_position:
        ld      a, (BDOS.fcb_cache.r2)
        or      a
        ret     nz
        ld      de, (BDOS.fcb_cache.r0)     ; r0, r1
        ld      bc, 0
        ld      hl, BDOS.fcb_cache
        call    set_block_num_in_fcb
        xor     a                           ; Z
        ret

;
;-----------------------------------------------------------------------------
; Directory search (functions 17 and 18, and 19's matching)
;-----------------------------------------------------------------------------
; A search lists the files in one user's folder, or in every user's folder
; when the FCB's drive byte is "?". Each file is shown as CP/M directory
; entries made from its size. With the disk parameter block's extent mask
; of 1, an entry holds two 16K extents (256 records): entry k ends at extent
; 2k+1 with rc = 128, and the last entry ends at the file's last extent with
; the records in it. An ex of "?" returns every entry of a file; any other ex
; returns the entry that holds extent ex. The entry's d0-d15 are eight fake
; 16-bit block numbers, one per 4K block the entry's records fill.

;
; Start a search with the cached FCB's drive, name and ex, and return the
; first entry, as search_next does.
search_first:
        call    search_close
        ld      hl, 0+DPB_DIR_BLOCKS        ; First block after the directory
        ld      (search.block), hl
        xor     a
        ld      (search.all_users), a
        ld      a, (BDOS.fcb_cache)
        cp      '?'
        jr      nz, .one_user
        xor     a
        ld      (BDOS.fcb_cache), a         ; The current disk...
        inc     a
        ld      (search.all_users), a       ; ...and every user
.one_user:
        ld      a, (BDOS.fcb_cache.ex)
        cp      '?'
        ld      a, 1
        jr      z, .all_extents
        ld      a, (BDOS.fcb_cache.ex)
        and     %00011111
        srl     a                           ; The entry that holds extent ex
        ld      (search.group), a
        xor     a
.all_extents:
        ld      (search.all_extents), a
        ld      de, BDOS.fcb_cache
        call    copy_fcb_to_buffers         ; current_esxdos.filename = the name to match
        ld      hl, current_esxdos.filename
        ld      de, search.pattern
        ld      bc, SEARCH_PATTERN_LEN
        ldir                                ; Kept apart, so files used between calls do not change it
        call    fcb_drive
        ld      (search.drive), a
        cp      2
        jr      c, .virtual_drive
        xor     a
        ld      (search.all_users), a       ; Drives C: on have no user folders
.virtual_drive:
        ld      a, (current_user)
        ld      b, a
        ld      a, (search.all_users)
        or      a
        jr      z, .user
        ld      b, 0                        ; Every user, from user 0
.user:
        ld      a, b
        ld      (search.user), a
        call    search_open_dir
        jr      nc, search_next
        ld      a, 255                      ; No such drive or user folder
        ret

;
; Return the next directory entry of the search in dma_cache.
; Returns A=0, or A=255 when there are no more.
search_next:
        ld      a, (search.open)
        or      a
        jp      z, .none
        ld      a, (search.pending)
        or      a
        jr      nz, .more_entries
.read:
        ld      a, (search.handle)
        ld      hl, current_esxdos.entry    ; Buffer for the entry
        ld      de, search.pattern          ; Wildcard name to match
        m_kr_esxdos F_READDIR
        jr      c, .folder_done
        or      a
        jr      z, .folder_done
        ld      a, (current_esxdos.entry)   ; FAT attributes
        and     fat_attr_directory + fat_attr_volume
        jr      nz, .read                   ; Not a file
        call    search_size
        ld      a, (search.all_extents)
        or      a
        jr      z, .one_entry
        xor     a                           ; Every entry, from the first
        jr      .emit
.one_entry:
        call    search_last_entry
        ld      b, a
        ld      a, (search.group)
        cp      b
        jr      z, .emit
        jr      nc, .read                   ; The file has no such entry
        jr      .emit
.more_entries:
        ld      a, (search.next)
.emit:                                      ; A = the entry to return
        ld      (search.next), a
        call    search_build_entry
        xor     a
        ld      (search.pending), a
        ld      a, (search.all_extents)
        or      a
        ret     z                           ; A = 0
        call    search_last_entry
        ld      b, a
        ld      a, (search.next)
        cp      b
        jr      nc, .found                  ; That was the file's last entry
        inc     a
        ld      (search.next), a
        ld      a, 1
        ld      (search.pending), a
.found:
        xor     a
        ret
.folder_done:
        call    search_close
        ld      a, (search.all_users)
        or      a
        jr      z, .none
        ld      a, (search.user)
        cp      15
        jr      nc, .none
        inc     a
        ld      (search.user), a
        call    search_open_dir
        jr      c, .folder_done             ; No folder for that user
        jp      .read
.none:
        call    search_close
        ld      a, 255
        ret

;
; Open the folder of search.drive and search.user for F_READDIR.
; Returns carry set if it cannot be opened.
search_open_dir:
        ld      a, (search.drive)
        ld      b, a
        ld      a, (search.user)
        ld      c, a
        ld      hl, current_esxdos.filepath
        call    drive_and_user_to_path
        ld      a, '*'                      ; Not important, the path overrides it
        ld      b, esx_mode_short_only + esx_mode_use_wildcards + esx_mode_sf_enable
        ld      c, esx_sf_exclude_dirs + esx_sf_exclude_dots
        ld      hl, current_esxdos.filepath
        ld      de, search.pattern
        m_kr_esxdos F_OPENDIR
        ret     c
        ld      (search.handle), a
        ld      a, 1
        ld      (search.open), a
        or      a                           ; Clear carry
        ret

;
; Close the search's folder, if it is open.
; Dirties AF
search_close:
        ld      a, (search.open)
        or      a
        ret     z
        xor     a
        ld      (search.open), a
        ld      (search.pending), a
        ld      a, (search.handle)
        push    bc
        push    de
        push    hl
        m_kr_esxdos F_CLOSE
        pop     hl
        pop     de
        pop     bc
        ret

;
; Take the size of the file in current_esxdos.entry: search.empty is
; non-zero for an empty file, else search.last_rec is its last record
; number, (size - 1) / 128, at most 65535.
search_size:
        ld      hl, current_esxdos.entry+1  ; The name...
        xor     a
        ld      bc, SEARCH_PATTERN_LEN
        cpir                                ; ...and its terminator
        inc     hl
        inc     hl
        inc     hl
        inc     hl                          ; Past the time and date
        ld      e, (hl)
        inc     hl
        ld      d, (hl)
        inc     hl
        ld      c, (hl)
        inc     hl
        ld      b, (hl)                     ; BCDE = file size
        ld      a, b
        or      c
        or      d
        or      e
        jr      nz, .not_empty
        inc     a
        ld      (search.empty), a
        ret
.not_empty:
        ld      a, e                        ; BCDE = size - 1
        sub     1
        ld      e, a
        ld      a, d
        sbc     a, 0
        ld      d, a
        ld      a, c
        sbc     a, 0
        ld      c, a
        ld      a, b
        sbc     a, 0
        jr      nz, .largest                ; Past 65536 records
        bit     7, c
        jr      nz, .largest
        sla     e                           ; C:D = (size - 1) / 128
        rl      d
        rl      c
        ld      l, d
        ld      h, c
        jr      .store
.largest:
        ld      hl, $FFFF                   ; CP/M's largest file
.store:
        ld      (search.last_rec), hl
        xor     a
        ld      (search.empty), a
        ret

;
; A = the number of the current file's last directory entry.
search_last_entry:
        ld      a, (search.empty)
        or      a
        ld      a, 0
        ret     nz
        ld      a, (search.last_rec+1)      ; 256 records to an entry
        ret

;
; Build directory entry A of the file in current_esxdos.entry in dma_cache:
; byte 0 the user number, the name with the FAT read-only attribute as t1'
; and the system and hidden attributes as t2', then ex, s1, s2, rc and d0-d15.
; The rest of the record is filled with $E5, the mark of an unused entry.
search_build_entry:
        push    af
        ld      hl, current_esxdos.entry
        ld      de, BDOS.dma_cache
        call    esxdos_to_FCB               ; Bytes 0 to 11
        ld      a, (search.user)
        ld      (BDOS.dma_cache), a
        ld      a, (current_esxdos.entry)   ; FAT attributes
        ld      b, a
        and     fat_attr_readonly
        jr      z, .writable
        ld      hl, BDOS.dma_cache+9
        set     7, (hl)                     ; t1'
.writable:
        ld      a, b
        and     fat_attr_hidden + fat_attr_system
        jr      z, .not_system
        ld      hl, BDOS.dma_cache+10
        set     7, (hl)                     ; t2'
.not_system:
        ld      hl, BDOS.dma_cache+12
        ld      b, 32-12
.zero:
        ld      (hl), 0
        inc     hl
        djnz    .zero
        ld      b, 128-32
.unused:
        ld      (hl), $E5
        inc     hl
        djnz    .unused
        pop     af
        ld      c, a                        ; C = entry number k
        rrca
        rrca
        rrca
        rrca
        and     %00001111
        ld      (BDOS.dma_cache+14), a      ; s2 = k / 16 (two extents an entry)
        ld      a, (search.empty)
        or      a
        ret     nz                          ; Empty: ex, rc and d0-d15 are 0
        ld      a, (search.last_rec+1)
        cp      c
        jr      z, .last
        ld      a, c                        ; A full entry: extents 2k and 2k+1
        add     a, a
        inc     a
        and     %00011111
        ld      (BDOS.dma_cache+12), a      ; ex
        ld      a, 128
        ld      (BDOS.dma_cache+15), a      ; rc
        ld      b, 8                        ; Blocks
        jr      .blocks
.last:
        ld      a, (search.last_rec)
        rlca
        and     1                           ; 1 when the last record is in extent 2k+1
        ld      b, a
        ld      a, c
        add     a, a
        or      b
        and     %00011111
        ld      (BDOS.dma_cache+12), a      ; ex
        ld      a, (search.last_rec)
        and     %01111111
        inc     a
        ld      (BDOS.dma_cache+15), a      ; rc, 1 to 128
        ld      a, (search.last_rec)
        rlca
        rlca
        rlca
        and     %00000111
        inc     a
        ld      b, a                        ; Blocks, 1 to 8
.blocks:
        ld      hl, BDOS.dma_cache+16
        ld      de, (search.block)
.block:
        ld      (hl), e
        inc     hl
        ld      (hl), d
        inc     hl
        inc     de
        djnz    .block
        ld      (search.block), de
        ret

;
;-----------------------------------------------------------------------------
; ESXDOS <-> FCB helpers
;-----------------------------------------------------------------------------

;
; Read the next 128 bytes of the file with esxdos handle A, from its current
; position, to the DMA address. A short last record is padded with ^Z.
; Returns A=0 with the record copied out, A=1 with the DMA untouched when no
; bytes remain, or carry set on an esxdos error.
read_128_bytes_to_dma:
        ld      hl, BDOS.dma_cache          ; Where to read it into
        ld      bc, $80                     ; 128 Bytes
        m_kr_esxdos F_READ
        ret     c                           ; Return if there's a carryflag (error)
        ld      a, b
        or      c
        jr      nz, .got_data
        inc     a                           ; A=1: end of file, nothing read
        ret
.got_data:
        ld      a, 128
        cp      c
        jr      z, .copy_dma
.pad_data:
        ld      hl, BDOS.dma_cache          ; HL points to start of DMA buffer
        add     hl, bc                      ; Increase pointer by bytes read
        sub     c                           ; Subtract bytes read from 128
        ld      b, a                        ; Bytes short (in A) to B
.pad_loop
        ld      (hl), $1a                   ; Set DMA at pointer to ^Z
        inc     hl                          ; Move pointer along
        djnz    .pad_loop                   ; Do we have padding left to do?
.copy_dma:
        call    BDOS.copy_dma_out_kernel
        xor     a
        ret

;
; Set the rc of the cached FCB to the number of records the file has in the
; extent the FCB names (ex, and s2 without its bit 7): 0 to 128. The file size
; is the one esxdos F_FSTAT left in current_esxdos.stats.
set_rc_from_size:
        ld      a, (BDOS.fcb_cache.s2)
        and     %01111111
        ld      l, a
        ld      h, 0
        add     hl, hl
        add     hl, hl
        add     hl, hl
        add     hl, hl
        add     hl, hl                      ; S2 * 32
        ld      a, (BDOS.fcb_cache.ex)
        ld      e, a
        ld      d, 0
        add     hl, de                      ; HL = extent number
        ld      a, l                        ; The extent starts at extent * 16K bytes:
        and     %00000011
        rrca
        rrca
        ld      d, a
        ld      e, 0                        ; DE = low word of extent * 16K
        srl     h
        rr      l
        srl     h
        rr      l
        ld      b, h
        ld      c, l                        ; BC = high word of extent * 16K
        ld      hl, (current_esxdos.stats+7); File size, low word
        or      a
        sbc     hl, de
        ex      de, hl                      ; DE = low word of bytes from the extent start
        ld      hl, (current_esxdos.stats+9); File size, high word
        sbc     hl, bc
        jr      c, .none                    ; File ends before this extent
        ld      a, h
        or      l
        jr      nz, .full                   ; 64K or more beyond its start
        ld      a, d
        cp      $40
        jr      nc, .full                   ; 16K or more beyond its start
        ld      hl, 127                     ; Records = (bytes + 127) / 128
        add     hl, de
        add     hl, hl
        ld      a, h
        jr      .store
.full:
        ld      a, 128
        jr      .store
.none:
        xor     a
.store:
        ld      (BDOS.fcb_cache.rc), a
        ret

;
; Convert a spec to a file access path.
; Drive in B, 0==A, 1==B, etc.   User in C, 0 thru 15.  HL==buffer start.
drive_and_user_to_path:
        push    af
        push    bc
 ;.detect_drive_type:
        ld      a, b
        add     a, 'A'                      ; Turn drive into ASCII (now it's index1ed)
        cp      'C'                         ; Is drive letter less than 'C'?
        jr      c, .virtual_drive           ; Virtual drives, these need special paths
 ;.physical_drive
 
            ; push hl : ld hl, str_SDCARD : call KERNEL.kr_print_string_hl : pop hl
        ld      (hl), a
        inc     hl                          ; Extend string
        ld      (hl), ':'                   ; ...Append to filepath cache
            ; Don't append a slash for physical drives, we want relative paths to CWD
        jr      .finish_path
.virtual_drive
            ; push hl : ld hl, str_VDRIVE : call KERNEL.kr_print_string_hl : pop hl
            ; push hl : ld hl, KERNEL.config.install_path : call KERNEL.kr_print_string_hl : pop hl
            ; ; push hl : call KERNEL_DEBUG.print_crlf :  ld  a, '>' : call KERNEL_TERM.process : call KERNEL_DEBUG.print_crlf : pop hl
            
        ld      de, KERNEL.config.install_path
        call    KERNEL.strcpy               ; Copy install path to filepath cache
        
            ; push hl : ld hl, KERNEL.config.install_path : call KERNEL.kr_print_string_hl : pop hl
        pop     bc : push bc                ; Restore Drive+User
        ld      a, b
        add     a, 'A'                      ; Turn drive into ASCII (now it's index1ed)
        ld      (hl), a                     ; Append drive letter to filepath cache
        inc     hl                          ; Extend string
        ld      (hl), '/'                   ; ...Append to filepath cache
        inc     hl                          ; Extend string
 ;.user number                           ; only virtual drives support this
        pop     bc : push bc
        ld      a, c                        ; Load current user, FCBs don't carry this
        cp      10                          ; Is user number greater than 10?
        jr      nc, .user_above_9
 ;.user_under_10                         ; single digit
        add     a, '0'                      ; Turn user into ASCII
        ld      (hl), a                     ; Append drive letter to filepath cache
        jr      .final_slash
.user_above_9                           ; double digit, starts with 1.
        ld      (hl), '1'                   ; Append 1 from user 10+ to filepath cache
        inc     hl                          ; Extend string
        add     a, '0'-10                   ; Second digit of the user in A,
        ld      (hl), a                     ; Append drive letter to filepath cache
            ; Fall through to finish the path
.final_slash
        inc     hl                          ; Extend string
        ld      (hl), '/'                   ; ...Append to filepath cache
.finish_path
        inc     hl                          ; Extend string
        ld      (hl), 0                     ; ...Terminate filepath cache
            ; Fall through to filename
        pop     bc
        pop     af
        ret
                    
            ; str_VDRIVE:
            ;         DB "VDRIVE:", 0
            ; str_SDCARD:
            ;         DB "SDCARD:", 0
;
; Calculate the record number from the FCB (Pointer in DE), as CP/M does:
;     Record = ((S2 & $7F) * 32 + EX) * 128  +  CR
; S2's bit 7 is a flag, not part of the position.
; 32-bit result is returned in BCDE
get_block_num_from_fcb:
        ex      de, hl                  ; Swap DE & HL
        ld      bc, 12                  ; First part, EX, is offset 12 bytes in
        add     hl, bc                  ; So move pointer to FCB along by that
        ld      e, (hl)                 ; And load the value of EX into E
        inc     hl                      ; Next is S2....
        inc     hl                      ; ....Which is 2 bytes further along
        ld      d, (hl)                 ; Load value of S2 into D
        ld      bc, 18                  ; and the value of CR is another 18 bytes
        add     hl, bc                  ; HL now points to the CR record
        ld      c, (hl)                 ; Finally, load CR into C - that's our data
        ld      b, 0                    ; Reset B to zero
        push    bc                      ; Stash CR
        ld      a, d
        and     %01111111               ; S2 without its flag bit
        ld      l, a
        ld      h, 0
        add     hl, hl
        add     hl, hl
        add     hl, hl
        add     hl, hl
        add     hl, hl                  ; S2 * 32
        ld      d, 0
        add     hl, de                  ; Plus EX: the extent number
        ex      de, hl
        ld      bc, 0                   ; 32-bit value of DE is now in BCDE
        call    KERNEL_MATHS.mul_bcde_by_128; Mul128
        pop     hl                      ; Get 16-bit version of CR back into HL
        add     hl, de                  ; And add DE to it
        ex      de, hl                  ; Swap with DE, now has least signif 16bit
        ld      h, b                    ; B into H
        ld      l, c                    ; C into L, HL now contains BC
        ld      bc, 0                   ; Wipe BC
        adc     hl, bc                  ; Add BC+Carry to HL
        ld      b, h                    ; Put H into B...
        ld      c, l                    ; ... and L into C, BCDE now 32bit offset
        ret
        
;
; Set's "offset" in FCB  -- HL->FCB, record number in BCDE, stored as CP/M does:
;     CR = record & $7F, EX = (record / 128) & $1F, S2 = record / 4096
; S2's bit 7 flag is kept as it was.
;     Preserves HL
set_block_num_in_fcb:                  ; WAS: set_file_pointer_in_fcb
        push    hl                          ; Stash HL for exit
        ld      a, e                        ; Least significant byte into A
        and     %01111111                   ; Mask least significant 7 bits from E into A
        push    af                          ; A destined for CR, stash for now
        sla     e                           ; Shift E left by 1 (bit 8 into carry)
        rl      d                           ; Shift D left by 1 (bit 8 into carry, carry from E into bit 0)
        rl      c                           ; Shift C left by 1 (bit 8 into carry, carry from D into bit 0)
        rl      b                           ; C:D is now record / 128, the extent number
        ld      a, d
        and     %00011111
        ld      e, a                        ; E = FCB->EX, extent within the module
        ld      a, d
        srl     c
        rra
        srl     c
        rra
        srl     c
        rra
        srl     c
        rra
        srl     c
        rra                                 ; A = extent number / 32
        and     %01111111
        ld      d, a                        ; D = FCB->S2, without its flag bit
        ld      bc, 12                      ; Offset into FCB for EX
        add     hl, bc                      ; move FCB pointer in HL->EX
        ld      (hl), e                     ; E into EX
        inc     hl                          ; inc pointer, skip S1
        inc     hl                          ; inc pointer, HL now FCB->S2
        ld      a, (hl)
        and     %10000000                   ; Keep S2's flag bit
        or      d
        ld      (hl), a                     ; D into S2
        ld      bc, 18                      ; Offset futher into FCB for "Current Record", CR
        add     hl, bc                      ; hl = FCB->CR
        pop     af                          ; Restore CR into A.
        ld      (hl), a                     ; A into CR
        pop     hl                          ; Restore HL=Pointer to start of FCB
        ret

;
; Convert an ESXDOS entry(23bytes) pointed to by HL, to a FCB pointed to by DE
esxdos_to_FCB:
        push    af                          ; Stash all entry registers we use
        push    bc                          ;  so we can use this function anywhere
        push    de                          ;  in a clean and safe manner
        push    hl                          ;  This means we can preserve DE and HL on exit
        
        ld      a, (KERNEL_BDOS.current_esxdos.diskname); Get the diskname, as parsed out by SFIRST
        ld      (de), a                     ;        and write it to our FCB cache
        ld      b, 8                        ; Length of filename(without .ext)
.copy_filename_char:
        inc     hl                          ; Move along (first run skips a byte by design) to data
        inc     de                          ; And destination
        ld      a, (hl)                     ; Get char
        cp      '.'                         ; Is it a dot?
        jr      z, .pad_filename            ; ...Yes, pad rest of chars (len in b) with spaces
        cp      0                           ; Is it a NULL?
        jr      z, .pad_both                ; ...Yes, pad, and pad for the extension bit too.
        ld      (de), a                     ; ...No, write this char to DE pointed location
        djnz    .copy_filename_char         ; And loop if not 8 bytes yet
        inc     de                          ; Move DE along to point at first char for new extension
        inc     hl                          ; Move HL along to point at next char in ESXDOS buffer
        
        ld      a, (hl)                     ; Get char
        cp      0                           ; Is it a NULL - handle special case when filename is 8.0
        jr      z, .pad_both                ; ...Yes, pad, and pad for the extension bit too.
        jr      .skip_dot                   ; It was 8 bytes, now skip the dot
.pad_filename:
        ld      a, ' '
        ld      (de), a                     ; String was under 8bytes long, pad with a space
        inc     de                          ; Move the destination pointer
        djnz    .pad_filename               ; And if still not 8 bytes, pad again
        ; fall through to skipping the dot
.skip_dot
        inc     hl                          ; Skip the dot
        ld      b, 3                        ; Length of file extension
.copy_fileext:
        ld      a, (hl)                     ; Get char
        inc     hl
        cp      0                           ; Is it a NULL?
        jr      z, .pad_fileext             ; ...Yes, filename.ext done
        ld      (de), a                     ; ...No, write this char to DE pointed location
        inc     de                          ; Move the destination pointer
        djnz    .copy_fileext               ; And if not 3 bytes, get next char
        jr      .ext_done
.pad_fileext:
        ld      a, ' '
        ld      (de), a                     ; String was under 8bytes long, pad with a space
        inc     de                          ; Move the destination pointer
        djnz    .pad_fileext               ; And if still not 8 bytes, pad again
        jr      .ext_done
.pad_both:
        ld      a, ' '
        inc     b : inc b : inc b           ; Add three chars to the padding length, to cover ext
.pad_both_actual:
        ld      (de), a                     ; String was under 8bytes long, pad with a space
        inc     de                          ; Move the destination pointer
        djnz    .pad_both_actual            ; And if still not full length, pad again
.ext_done
        ; xor     a                           ; A=0 (terminator)
        ; ld      (de), a                     ; Terminate string - do we need this?
        ; push    de                          ; DE currently points at FCB->EX
        
        
        
        
        ; ; ld      a, 1
        ; ; call    KERNEL_BDOS.copy_buffers_to_fullpath; Create an ESXDOS access path
                

        ; ld      a, '*'                              ; Not important, filepath overrides it.
        ; ld      hl, KERNEL_BDOS.current_esxdos.fullpath; Full path of file to get stats
        ; m_kr_esxdos F_OPEN
        ; push    af                                  ; Preserve file-handle
        ; ld      hl, KERNEL_BDOS.current_esxdos.stats; 11byte stats buffer
        ; m_kr_esxdos F_FSTAT
        ; pop     af                                  ; Restore file-handle
        ; m_kr_esxdos F_CLOSE
        
        ; pop     de
        ; Fill in a few more details. File size into normal place, plus random record info.
        pop     hl
        pop     de
        pop     bc
        pop     af
        
        ret

esxdos_stats_handle:        ; Handle used when reading ESXDOS stats in esxdos_to_FCB:
        db      0

;
;-----------------------------------------------------------------------------
; Open file handles, see handle_make_key and the routines after it
;-----------------------------------------------------------------------------
handle_key:                     ; Key of the FCB being looked up
        ds      HANDLE_KEY_LEN, 0
io_handle:                      ; esxdos handle of the file being read or written
        db      0
io_offset:                      ; Byte offset in that file of the record being written
        ds      4, 0
handle_table:
handle_rank = 0
        DUP     HANDLE_SLOTS
        db      0, 0, handle_rank           ; HANDLE.in_use, .esx, .rank
        ds      HANDLE_KEY_LEN, 0           ; HANDLE.key
handle_rank = handle_rank + 1
        EDUP
;
;-----------------------------------------------------------------------------
; Drives
;-----------------------------------------------------------------------------
login_vector:                   ; Drives logged in since the last reset (function 24)
        dw      0
ro_vector:                      ; Drives set read-only (function 28)
        dw      0
io_readonly:                    ; Non-zero when handle_open_fcb's handle is read only
        db      0
current_disk:                   ; Drive selected (function 14), 0=A to 15=P
        db      0
current_user:                   ; User number (function 32)
        db      0
dma_address:                    ; DMA address (function 26)
        dw      0

;
;-----------------------------------------------------------------------------
; Directory search state, see search_first
;-----------------------------------------------------------------------------
DPB_DIR_BLOCKS          EQU     8       ; Directory blocks of the DPB (AL0 = $FF)
SEARCH_PATTERN_LEN      EQU     14      ; As current_esxdos.filename
search:
.open:                          ; Non-zero while a folder is open for search_next
        db      0
.handle:                        ; Its esxdos directory handle
        db      0
.drive:                         ; Drive searched, 0-15
        db      0
.user:                          ; User whose folder is open
        db      0
.all_users:                     ; Non-zero for a drive byte of "?"
        db      0
.all_extents:                   ; Non-zero for an ex of "?"
        db      0
.group:                         ; Otherwise, the entry to return: ex / 2
        db      0
.pending:                       ; Non-zero when the current file has another entry to return
        db      0
.next:                          ; That entry's number
        db      0
.empty:                         ; Non-zero when the current file is empty
        db      0
.last_rec:                      ; Else the number of its last record
        dw      0
.block:                         ; Next fake block number for d0-d15
        dw      0
.pattern:                       ; Wildcard name for F_READDIR
        ds      SEARCH_PATTERN_LEN, 0

;
;-----------------------------------------------------------------------------
; ESXDOS pathname (plus FCB drive metadata) - generated from FCB+FIND/etc
;-----------------------------------------------------------------------------
current_esxdos:
.entry:                         ; 23byte buffer for ESXDOS to write filename into
        ds      23, $00
.stats:                         ; 11byte byffer for ESXDOS to write filestats into
        ds      11, $00         
.diskname:                      ; Drive byte, extracted from FCB
        db      0
.filename:                      ; Filespec, extracted from FCB 
        ds      $0e, $AA
.filepath:                      ; Drive+Path, extracted from FCB
        ds      262, $AA
;
;-----------------------------------------------------------------------------
; ESXDOS full path, generated from above
;-----------------------------------------------------------------------------
.fullpath:                      ; Drive+Path+Filename
        ds  262, $AA

;
;-----------------------------------------------------------------------------
; ESXDOS full path, generated from above
;-----------------------------------------------------------------------------
.delete_flag:                   ; If file has been deleted already
        db      0

;
;-----------------------------------------------------------------------------
; Line input (function 10) state
;-----------------------------------------------------------------------------
readstr:
.dest:                          ; Userland buffer address passed in DE
        dw      0
.max:                           ; Its maximum length, mx
        db      0
.column:                        ; Screen column where the line began
        db      0
.line:                          ; The line: +0 the count read, +1 on the characters
        ds      256, 0

    ENDMODULE
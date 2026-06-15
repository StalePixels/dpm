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


; Closes any filepointer attached to the current_fcb
close_file:
        ld      a, (KERNEL_BDOS.current_esxdos.file_handle)
        m_kr_esxdos F_CLOSE
        ret
;
; Clears the entire current FCB
clear_current_fcb:
        ld de, KERNEL_BDOS.current_fcb+1
        ld hl, KERNEL_BDOS.current_fcb
        xor a
        ld (hl), a
        ld bc, 36
        ldir
        ret
;
; Copies the current FCB, pointed to by DE, into the "Current Open FCB"
;     referenced by BDOS functions for future file operations on open file 
;     Dirties HL, AF, BC. Preserves DE
copy_fcb_to_current_fcb:
        push    de                          ; Keep original FCB safe
                        ; call    KERNEL_DEBUG.print_crlf
                        ; ld hl, KERNEL_DEBUG.copy__string : call KERNEL.kr_print_string_hl
                        ; ld      a, '1' : call KERNEL_TERM.process
                        ; push    de : inc de : push de : pop hl : call KERNEL.kr_print_string_hl : pop de
                        ; ld      hl, KERNEL_BDOS.current_fcb+1 : call KERNEL.kr_print_string_hl
        ld      hl, KERNEL_BDOS.current_fcb ; Destination
        xor     a                           ; Wipe A
        ld      (hl), a                     ; Set first byte to zero
        ex      hl, de                      ; LDIR copies HL to DE, so swap them
        ld      bc, 36                       ; Length of copy
        ldir                                ; Do copy
        ex      hl, de                      ; LDIR done. swap them back.
        pop     de                          ; Get original FCB back off stack
                        ; ld      a, '>' : call KERNEL_TERM.process
                        ; ld      hl, KERNEL_BDOS.current_fcb+1 : call KERNEL.kr_print_string_hl
        ret
;
; Compares the FCB(pointed to with DE) to current one
match_current_fcb_name:
        push    de                          ; Keep DE Safe
        ld      hl, KERNEL_BDOS.current_fcb ; HL points to current_fcb
        ld      b, 12                       ; Names are 12 bytes long
.loop:
                        ; ld      a, (de) : call KERNEL_TERM.process
                        ; ld      a, '=' : call KERNEL_TERM.process
                        ; ld      a, (hl) : call KERNEL_TERM.process
                        ; ld      a, '?' : call KERNEL_TERM.process
        ld      a, (de)                     ; Char from "New" FCB into A
        cp      (hl)                        ; Compare to pointer to old
        jr      nz, KERNEL_BDOS.match_current_fcb.fail; No match
        inc     de                          ; Move pointer along in New
        inc     hl                          ; ...and in old
        djnz    .loop                       ; If we've not comapred 12 chars, do again
        pop     de                          ; Restore DE
        cp      a                           ; set zero flag for success
        ret
;
; Compares EX, S2 and CR
match_current_fcb_pointer:
        push    de                          ; Save pointer to FCB
        ld      hl, current_fcb             ; Get pointer to current FCB
        ld      bc, 12                      ; EX is 12 bytes offset into FCB, so...
        add     hl, bc                      ; Move pointer for current FCB
        ex      de, hl                      ; Swap DE & HL for a moment
        add     hl, bc                      ; Move pointer for new FCB
        ld      a, (de)                     ; Get Current FCB EX
        cp      (hl)                        ; Compare to New EX.  Same?
        jr      nz, KERNEL_BDOS.match_current_fcb.fail; Nope!
        inc     hl                          ; Scoot along...
        inc     hl                          ; Two bytes...
        inc     de                          ; Both pointers...
        inc     de                          ; to find the S2 address
        ld      a, (de)                     ; Get the value of Current S2
        cp      (hl)                        ; Compare to new S2. Same?
        jr      nz, KERNEL_BDOS.match_current_fcb.fail; Nope!
        ld      bc, 18                      ; Number of bytes until we get to CR
        add     hl, bc                      ; Move New FCB pointer
        ex      de, hl                      ; Swap them back, HL now Current FCB
        add     hl, bc                      ; Move pointer along again
        ld      a, (de)                     ; Get the value of S2 in New
        
        cp      (hl)                        ; Compare to current fcb S2. Same?
        jr      nz, KERNEL_BDOS.match_current_fcb.fail; Nope!
        pop     de                          ; Restore DE to start of new FCB
        cp      a                           ; set zero flag for success
        ret
;
; Compare FCB (pointed to by DE) with the one in current_fcb. 
;     Returns Zero if matched. Preserves original DE.
match_current_fcb:
                        ; ld      a, '~' : call KERNEL_TERM.process
        call    KERNEL_BDOS.match_current_fcb_name
        ret     nz
                        ; ld      a, '~' : call KERNEL_TERM.process
        jr      KERNEL_BDOS.match_current_fcb_pointer
.fail:          ; Only gotten to if jumped to directly, for a match fail
                        ; ld      a, ':' : call KERNEL_TERM.process
                        ; ld      a, '(' : call KERNEL_TERM.process
        pop     de
        or      1                                ; Ensure zero flag is not set
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
; Skip NULLs spaces and add in the ".", and terminate with NULL.
; Preserves DE. Dirties A, B, C, HL
copy_fcb_to_buffers:
        push    de                          ; Save FCB pointer on stack
        ld      a, (de)                     ; First byte in FCB is 0 or 1-16. We want 0=>A, 15=>P
        ld      (KERNEL_BDOS.current_esxdos.diskname), a; Save this into the cache, to go with file and path
        cp      0                           ; 0 = no explicit drive passed
        jr      nz, .drive_and_user_to_path ;   Yes, use that
        ld      a, (BDOS.current_disk)      ;   No, load default, which is indexed from 0
        inc     a                           ;       Adjust 0-15 to 1-16
.drive_and_user_to_path:
        dec     a                           ; +1&-1 Hack works, drives indexed from 0 again.
        ld      b, a                        ; Copy drive letter into B
        ld      a, (BDOS.current_user)      ; Load current user, FCBs don't carry this
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
; pass in de -> fcb
; Pass hl = random pointer value
; Random pointer goes to fcb + 33 & 34. fcb + 35 gets 0.
; preserve de
set_random_pointer_in_fcb:
	push de
	ex de, hl
	ld bc, 33
	add hl, bc
	ld (hl), e
	inc hl
	ld (hl), d
	inc hl
	ld (hl), 0
	ex de, hl
	pop de
	ret


;
;-----------------------------------------------------------------------------
; ESXDOS <-> FCB helpers
;-----------------------------------------------------------------------------

;
; Read 128bytes from KERNEL_BDOS.current_esxdos.file_handle, at seek location,
; into dma address
read_128_bytes_to_dma:
                    ; ld      a, '(' : call KERNEL_TERM.process
                    ; ld      a, 'R' : call KERNEL_TERM.process
        ld      a, (KERNEL_BDOS.current_esxdos.file_handle); Where to read data from
        ld      hl, BDOS.dma_cache          ; Where to read it into
        ld      bc, $80                     ; 128 Bytes
        m_kr_esxdos F_READ
        ret     c                           ; Return if there's a carryflag (error)
        ld      a, 128
        cp      c
        jr      z, .copy_dma
.pad_data:
                    ; ld      a, 'P' : call KERNEL_TERM.process
        ld      hl, BDOS.dma_cache          ; HL points to start of DMA buffer
        add     hl, bc                      ; Increase pointer by bytes read
        sub     c                           ; Subtract bytes read from 128
        ld      b, a                        ; Bytes short (in A) to B
.pad_loop
        ld      (hl), $1a                   ; Set DMA at pointer to ^Z (should this be one and then null?)
        inc     hl                          ; Move pointer along
        djnz    .pad_loop                   ; Do we have padding left to do?
.copy_dma:
                    ; ld      a, ')' : call KERNEL_TERM.process
        call    BDOS.copy_dma_out_kernel
        xor     a
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
        ld      a, (BDOS.current_user)      ; Load current user again
        add     a, '0'-10                   ; Add 36 to the value of the user,
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
; Calculate the file-offset from the FCB (Pointer in DE)
;     Offset =  (S2 * 256 + EX) * 128  +  CR
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
; Set's "offset" in FCB  -- HL->FCB, File offset (128b records) in BCDE, and stored in S2, EX & CR
; CR = e & %01111111, BCDE then divided by 128 with results stored as EX = e, S2 = d
;     Preserves HL
set_block_num_in_fcb:                  ; WAS: set_file_pointer_in_fcb
        push    hl                          ; Stash HL for exit
        ld      a, e                        ; Most significant byte into A
        and     %01111111                   ; Mask least significant 7 bits from E into A
        push    af                          ; A destined for CR, stash for now
        sla     e                           ; Shift E left by 1 (bit 8 into carry)
        rl      d                           ; Shift D left by 1 (bit 8 into carry, carry from E into bit 0)
        rl      c                           ; Shift C left by 1 (bit 8 into carry, carry from D into bit 0)
        rl      b                           ; Shift B left by 1 (bit 8 into carry, carry from C into bit 0)
        ld      e, d                        ; Stick D into E    E = FCB->EX
        ld      d, c                        ; Stick C into D    D = FCB->S2
        ld      c, b                        ; Stick B into C
        ld      b, 0                        ; Wipe B.  We've now basically done BCDE>>7 (rl's+ld's)
        pop     af                          ; Restore CR into A.   
        ld      bc, 12                      ; Offset into FCB for EX
        add     hl, bc                      ; move FCB pointer in HL->EX
        ld      (hl), e                     ; E into EX
        inc     hl                          ; inc pointer, skip S1
        inc     hl                          ; inc pointer, HL now FCB->S2
        ld      (hl), d                     ; D into S2
        ld      bc, 18                      ; Offset futher into FCB for "Current Record", CR
        add     hl, bc                      ; hl = FCB->CR
        ld      (hl), a                     ; A into CR
        pop     hl                          ; Restore HL=Pointer to start of FCB
        ret                             ; Is this correct? Logic in set_file_size_in_fcb is not same
                                        ; Differences would only show up for files over 496k anyways...

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
; The current FCB we have open, used as part of file emulation layer handler
;-----------------------------------------------------------------------------
current_fcb:
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
.dir_handle:                    ; Cached ESXDOS directory handle
        db  0
.file_handle:                   ; Cached ESXDOS file handle
        db      0
.delete_flag:                   ; If file has been deleted already
        db      0

    ENDMODULE
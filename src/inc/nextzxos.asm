
zxn_AllocatePageInA:               ; Allocate a new page
        push hl
        ld hl, $0001                ; Parameter for H = memtype, L = operationtype
        jr zxn_CallP3DOS
zxn_FreePage:                   ; Free bank number stored in E, modifies HL
        push hl
        ld hl, $0003                ; Parameter for H = memtype, L = operationtype
        jr zxn_CallP3DOS

zxn_AvailablePages:             ; Return number of pages free, modifies HL
        push hl
        ld hl, $0004                ; Parameter for H = memtype, L = operationtype
        jr zxn_CallP3DOS

zxn_CallP3DOS:
        push    ix
        push    bc
        push    de
        exx                         ; Function parameters are switched to alternative registers.
        ld      de,IDE_BANK         ; Choose the function.
        ld      c,7                 ; IDE_BANK RAM back to page in 
        rst     0x08                ; Perform ROM restart call
        db      M_P3DOS             ; Call the function
        ld      a,e
        pop     de
        pop     bc
        pop     ix
        pop     hl
        ret                         ; Return leaving response in A
                        ;   A=8K bank ID (0..total-1), for rc_bank_alloc
                        ;   A=total number of 8K banks of specified type, for rc_bank_total
                        ;   A=available number of 8K banks of specified type, for rc_bank_available
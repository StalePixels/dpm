/*-----------------------------------------------------------------------------
 * fat.h
 *-----------------------------------------------------------------------------
 * © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
 *
 * The DPM control call the FAT programs share: BIOS jump table entry 29,
 * BIOS_CONTROL_OFS (84) bytes past the warm boot entry, whose address is at
 * $0001. C = function, B = drive (0 = A:), DE = a path ending in 0 or a
 * 263-byte buffer, HL as the function needs it: the index of the directory
 * for DPM_LIST. Returns A = 0, or an esxDOS error code; DPM_LIST returns
 * $FF when there is no such directory. Also the console output and the
 * esxDOS error messages both programs print. Include <cpm.h> first.
 *---------------------------------------------------------------------------*/
#ifndef FAT_H
#define FAT_H

#define DPM_CHDIR       0x02
#define DPM_GETCWD      0x03
#define DPM_LIST        0x04

#define FAT_PATH_LEN    263

/* bc = (drive << 8) | function. The call's address goes into the CALL. */
static unsigned char dpm_control(unsigned int bc, const void *de, void *hl) __naked __z88dk_callee
{
    (void)bc; (void)de; (void)hl;
    __asm
        pop     af                      ; The return address
        pop     bc                      ; C = function, B = drive
        pop     de
        pop     hl
        push    af
        push    ix
        push    iy
        push    hl
        ld      hl, (1)                 ; The warm boot entry
        push    de
        ld      de, 84
        add     hl, de
        pop     de
        ld      (dpm_control_call+1), hl
        pop     hl
    dpm_control_call:
        call    0
        pop     iy
        pop     ix
        ld      l, a
        ld      h, 0
        ret
    __endasm;
}

static const char errors[] =
    "Unknown error\0OK\0Nonsense in esxDOS\0Statement end error\0"
    "Wrong file type\0No such file or dir\0I/O error\0Invalid filename\0"
    "Access denied\0Drive full\0Invalid i/o request\0No such drive\0"
    "Too many files open\0Bad file number\0No such device\0"
    "File pointer overflow\0Is a directory\0Not a directory\0"
    "Already exists\0Invalid path\0Missing system\0Path too long\0"
    "No such command\0In use\0Read only\0Verify failed\0"
    "Sys file load error\0Directory in use\0MAPRAM is active\0"
    "Drive busy\0Unknown filesystem\0Device busy";
#define ERRORS          32

static void print(const char *s)
{
    while (*s)
        bdos(CPM_WCON, *s++);
}

static void println(const char *s)
{
    print(s);
    print("\r\n");
}

/* The esxDOS error message for code e */
static void error(unsigned char e)
{
    const char *s = errors;

    if (e >= ERRORS) {
        print("Error ");
        bdos(CPM_WCON, '0' + e / 100);
        bdos(CPM_WCON, '0' + e / 10 % 10);
        bdos(CPM_WCON, '0' + e % 10);
        print("\r\n");
        return;
    }
    while (e--)
        while (*s++)
            ;
    println(s);
}

#endif

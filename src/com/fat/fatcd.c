/*-----------------------------------------------------------------------------
 * FATCD.COM
 *-----------------------------------------------------------------------------
 * © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
 *
 * FATCD d:         prints the FAT directory of drive d:
 * FATCD d: path    changes it, to an absolute path or one relative to it
 *
 * The path is the rest of the command line after the drive and the spaces
 * that follow it, spaces inside it kept, trailing spaces dropped. It is read
 * from the command tail at $0080, as the CCP left it, in upper case.
 *
 * Drives C: and up are NextZXOS drives, and DP/M uses each one's directory
 * as the drive. It is changed and read through DPM control functions $02
 * and $03 (fat.h). A: and B: are DP/M's own drives and are refused. A P3DOS
 * drive, such as the RAMdisk, has no directories: its directory is / and
 * cannot be changed. The path prints without the drive and without a
 * closing slash, except the root, which is /. With no arguments it prints
 * its usage.
 *
 * Built with z88dk: zcc +cpm -compiler=sdcc.
 *---------------------------------------------------------------------------*/
#pragma output CRT_ENABLE_COMMANDLINE = 0

#include <cpm.h>
#include "fat.h"

int main(void)
{
    char path[FAT_PATH_LEN];
    const char *end = (const char *)0x81 + *(unsigned char *)0x80;
    const char *t = (const char *)0x81;
    const char *d;
    char *p;
    unsigned char drive, e;

    while (t < end && *t == ' ')
        t++;
    if (t == end) {
        println("Usage: FATCD d: [path]");
        println("Prints or changes the FAT directory of drive d:, C: to P:.");
        return 0;
    }
    if (end - t < 2 || t[0] < 'A' || t[0] > 'P' || t[1] != ':' || (end - t > 2 && t[2] != ' ')) {
        println("Give a drive, C: to P:");
        return 1;
    }
    drive = t[0] - 'A';
    if (drive < 2) {
        println("A: and B: are DP/M's own drives");
        return 1;
    }
    t += 2;
    while (t < end && *t == ' ')
        t++;
    while (end > t && end[-1] == ' ')
        end--;
    if (t < end) {
        p = path;
        while (t < end)
            *p++ = *t++;
        *p = 0;
        e = dpm_control((drive << 8) | DPM_CHDIR, path, 0);
        if (e) {
            error(e);
            return 1;
        }
        return 0;
    }
    e = dpm_control((drive << 8) | DPM_GETCWD, path, 0);
    if (e) {
        error(e);
        return 1;
    }
    p = path;
    if (p[0] && p[1] == ':')
        p += 2;
    d = p;
    while (*p)
        p++;
    if (p - d > 1 && p[-1] == '/')
        p[-1] = 0;
    println(d);
    return 0;
}

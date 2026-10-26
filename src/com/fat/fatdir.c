/*-----------------------------------------------------------------------------
 * FATDIR.COM
 *-----------------------------------------------------------------------------
 * © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
 *
 * FATDIR d:        prints the FAT directory of drive d:, then the
 *                  directories in it, one name to a line
 *
 * The directory prints as FATCD d: prints it. The names come one at a time
 * from DPM control function $04 (fat.h), in the order esxDOS reads them,
 * with .. first in a subdirectory. A name is the long name, or the 8.3 name
 * of a directory that has none; FATCD takes either. A: and B: are DP/M's
 * own drives and are refused. A P3DOS drive, such as the RAMdisk, prints /
 * and no names. With no arguments it prints its usage.
 *
 * Built with z88dk: zcc +cpm -compiler=sdcc.
 *---------------------------------------------------------------------------*/
#include <cpm.h>
#include "fat.h"

int main(int argc, char *argv[])
{
    char path[FAT_PATH_LEN];
    const char *d;
    char *p;
    unsigned int n;
    unsigned char drive, e;

    if (argc != 2) {
        println("Usage: FATDIR d:");
        println("Lists the directories in the FAT directory of drive d:, C: to P:.");
        return 0;
    }
    d = argv[1];
    if (d[0] < 'A' || d[0] > 'P' || d[1] != ':' || d[2]) {
        println("Give a drive, C: to P:");
        return 1;
    }
    drive = d[0] - 'A';
    if (drive < 2) {
        println("A: and B: are DP/M's own drives");
        return 1;
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
    for (n = 0; ; n++) {
        e = dpm_control((drive << 8) | DPM_LIST, path, (void *)n);
        if (e == 0xFF)
            return 0;
        if (e) {
            error(e);
            return 1;
        }
        println(path);
    }
}

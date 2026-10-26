/*-----------------------------------------------------------------------------
 * CONCOLOR.COM
 *-----------------------------------------------------------------------------
 * © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
 *
 * CONCOLOR ink paper
 *
 * Sets DP/M's default console colours, which SGR 0, 39 and 49 and ESC c give,
 * through function $01 of DPM control. DP/M keeps them in the [console]
 * section of config.ini in its install folder, and uses them from then on.
 * The colours are named in SGR order: black, red, green, yellow, blue,
 * magenta, cyan, white. After the call it clears the screen, so all of it,
 * the border too, shows the new colours. With no arguments it prints its
 * usage.
 *
 * Built with z88dk: zcc +cpm.
 *---------------------------------------------------------------------------*/
#include <stdio.h>
#include <string.h>
#include <cpm.h>

/* DPM control: BIOS jump table entry 29, BIOS_CONTROL_OFS (84) bytes past
 * the warm boot entry. bios() finds it from the address at $0001. */
#define DPM_CONTROL     29
#define CONTROL_CONSOLE 1

static const char *colours[] = {
    "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"
};

/* The colour number of name, 0-7, or -1 if it is not a colour */
static int colour(const char *name)
{
    int i;

    for (i = 0; i < 8; i++)
        if (stricmp(name, colours[i]) == 0)
            return i;
    return -1;
}

static void usage(void)
{
    int i;

    printf("Usage: CONCOLOR ink paper\n");
    printf("Sets the default console colours, kept in config.ini.\n");
    printf("Colours:");
    for (i = 0; i < 8; i++)
        printf(" %s", colours[i]);
    printf("\n");
}

int main(int argc, char *argv[])
{
    int ink, paper;

    if (argc == 1) {
        usage();
        return 0;
    }
    if (argc != 3) {
        printf("Give two colours, ink and paper\n");
        return 1;
    }
    ink = colour(argv[1]);
    if (ink < 0) {
        printf("%s is not a colour\n", argv[1]);
        return 1;
    }
    paper = colour(argv[2]);
    if (paper < 0) {
        printf("%s is not a colour\n", argv[2]);
        return 1;
    }
    if (bios(DPM_CONTROL, CONTROL_CONSOLE, (ink << 8) | paper) != 0) {
        printf("Cannot write config.ini\n");
        return 1;
    }
    printf("\033[H\033[2J");
    return 0;
}

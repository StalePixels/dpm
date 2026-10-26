Display Program/Monitor
=======================

Synopsis
--------

A long time ago, I made a NextZXOS based CP/M emulator, called CPemu. It
had a number of failings, one of which was it was closed source, another
was that it didn't support CCP replacements, and was the CLI as well as
the kernel. This turned out to be quite the bottleneck for later
enhancement.

DP/M tackles it differently, and keeps the bits and ideas from the
former code that I like.

The bits from the emulator that DP/M keeps:

 * The filesystem - CPemu, and the reason that DP/M is called DP/M is
   that NextZXOS should still remain in control of the computer. So, for
   filesystems that means using the NextZXOS file system layer. And FAT32
   native file support. So, that also means BDOS level compatability with
   CP/M, not BIOS - so anything that expected to do direct sector or low
   level hardware access is out of scope. CPemu did this with some complex
   bank switching, and hoop jumping.

 * The technology - CPemu was a dot command - and the whole of the CP/M
   environment ran within that dot command. DP/M is also one
   continuously running dot command, so it can cleanly exit back to
   NextZXOS, as is the "user expectation" with a dot command. At exit
   DP/M frees every memory page it allocated, and puts back the pages
   NextZXOS had in MMU slots 2-7, the contents of $4000-$7FFF, the
   NextRegs it changed (NextReg $A0, the Pi's GPIO functions, and
   NextReg $06, the NMI buttons, among them), the UART select port
   $153B, the tilemap palette, the CPU speed, the border colour, the I
   register, interrupt mode 1 and the interrupt enable state. It does not
   put back the current directory of a drive that a program changed with
   DPM control function $02, as FATCD does (see doc/dpm_architecture.md),
   the UARTs' baud rate and frame (both stay at 115,200 baud, 8N1), or the
   NextReg select port $243B.

 * The memory management - CPemu did this with the Next's MMU to keep
   most code out of the linear memory space, and DP/M does the same, for
   maximum TPA. DP/M uses the NextZXOS APIs for all bank allocation and
   deallocation, so it can exit to NextZXOS.

 * The display - CPemu used the tilemap, and DP/M does too. With extra
   memory from NextZXOS, returned at exit, DP/M saves both 8K halves of
   $4000-$7FFF ($4000-$5FFF, the ULA screen and system variables, which
   hold the tile definitions while DP/M runs, and $6000-$7FFF, which
   holds the tilemap), so it restores the display at exit.

Memory
------

DP/M needs 28 free 8K pages (224K) from NextZXOS: eight for the CP/M
64K, two for the kernel, two for a copy of $4000-$7FFF, and eight for
each UART's receive buffer. With fewer, it ends with the error "Not
enough free memory banks".

Keyboard
--------

CAPS SHIFT and SYMBOL SHIFT pressed and released with no other key select
Extended mode for the next key. Extended mode, then a letter, gives CTRL
and that letter: Extended mode, then B, is CTRL-B. Extended mode, then 1
to 4, gives PF1 to PF4. The cursor keys send VT100 cursor sequences. The
DRIVE and M1 buttons do nothing while DP/M runs.

FAT directories
---------------

Drives C: to P: are the NextZXOS drives with the same letter, each one at
its current directory in NextZXOS. Two programs on drive A: show and
change these directories:

    A0>FATCD C: /GAMES/Long Folder Name
    A0>FATCD C:
    /GAMES/LONGFO~1
    A0>FATDIR C:

 * FATCD d: prints the current directory of drive d:, and FATCD d: path
   changes it. The path is absolute or relative, with long or 8.3 names,
   and needs no quotes around spaces. The change stays after DP/M ends.

 * FATDIR d: prints the current directory, then the directories in it,
   one to a line. DIR lists the files.

Devices
-------

The CP/M devices CON:, RDR:, PUN: and LST: follow the IOBYTE. STAT on
drive A: shows and sets them:

    A0>STAT DEV:
    A0>STAT LST:=TTY:

 * CON: TTY:, CRT: and UC1: are the screen and keyboard. BAT: takes
   input from the RDR: device and sends output to the LST: device.
 * RDR: TTY: is the keyboard, PTR: the ESP, UR1: the Pi, UR2: no device.
 * PUN: TTY: is the screen, PTP: the ESP, UP1: the Pi, UP2: no device.
 * LST: TTY: and CRT: are the screen, LPT: the Pi, UL1: the ESP.

At a cold boot IOBYTE is $95: CON: CRT:, RDR: PTR:, PUN: PTP:, LST: LPT:.
So LIST prints to the Pi, and the reader and punch are the ESP. A warm
boot keeps any change. CP/M terminal programs that use IOBYTE, such as
Kermit-80's generic build, work through these devices.

Both UARTs, the ESP WiFi module and the Pi, run at 115,200 baud, 8N1,
with no flow control. DP/M does not change the ESP's own baud rate, so
the ESP must be at 115,200 baud, the Next's default. DP/M keeps up to 64K
of received bytes for each UART.

TELNET
------

TELNET.COM on drive A: connects to a host through the ESP. The ESP must
already be on a WiFi network.

    A0>TELNET bbs.example.org
    A0>TELNET 192.168.1.10 2323

The port is 23 when there is none. The screen is a VT100 with ANSI
colours. DELETE sends BS (8). CTRL-B (Extended mode, then B) closes the
connection and returns to the CCP.

doc/dpm_architecture.md has the details of everything above.

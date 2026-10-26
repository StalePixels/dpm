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
   NextRegs it changed, the tilemap palette, the CPU speed, the border
   colour, the I register, interrupt mode 1 and the interrupt enable
   state. It does not put back the current directory of a drive that a
   program changed with DPM control function $02, as FATCD does (see
   doc/dpm_architecture.md), or the NextReg select port $243B.

 * The memory management - CPemu did this with the Next's MMU to keep
   most code out of the linear memory space, and DP/M does the same, for
   maximum TPA. DP/M uses the NextZXOS APIs for all bank allocation and
   deallocation, so it can exit to NextZXOS.

 * The display - CPemu used the tilemap, and DP/M does too. With extra
   memory from NextZXOS, returned at exit, DP/M saves both 8K halves of
   $4000-$7FFF ($4000-$5FFF, the ULA screen and system variables, which
   hold the tile definitions while DP/M runs, and $6000-$7FFF, which
   holds the tilemap), so it restores the display at exit.

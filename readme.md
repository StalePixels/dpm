Display Program/Monitor
=======================

Synopsis
--------

A long time ago, I made a NextZXOS based CP/M emulator, called CPemu. It
had a number of failings, one of which was it was closed source, another
was that it didn't support CCP replacements, and was the CLI as well as
the kernel. This turned out to be quite the bottleneck for later
enhancement.

This time I want to tackle it differntly, while still keeping the bits
and ideas from the former code that I like.

So, bits from the emulator that I want to keep:

 * The filesystem - CPemu, and the reason that DP/M is called DP/M is
   that NextZXOS should still remain in control of the computer. So, for
   filesystems that means using the NextZXOS file system layer. And FAT32
   native file support. So, that also means BDOS level compatability with
   CP/M, not BIOS - so anything that expected to do direct sector or low
   level hardware access is out of scope. CPemu did this with some complex
   bank switching, and hoop jumping.

 * The technology - CPemu was a dot command - and the whole of the CP/M
   environment ran within that dot command. I still want to do the entire
   operation as a continiously running dot command, this means that we can
   cleanly exit back to NextZXOS and have 100% state preservation, as is
   the "user expectation" with a dot command.

 * The memory management - CPemu did this with the Next's MMU to keep
   most code out of the linear memory space, and I plan to keep that idea
   - for maximum TPA. But using the NextZXOS APIs for all bank allocation
   and deallocation faciliating the exiting to NextZXOS.

 * The display - CPemu used the tilemap, we're still doing that - and by
   using extra memory from NextZXOS, returned when done, we'll be banking
   up both ULA areas (one for display, one for tiles) so we can even
   restore the display once finished.

Bits I want to change:

 * I am determined to release more stuff in 2025 than I did in 2024, so
   I'm developing this entirely in the open. That means expect irregular
   progress, if and when I get time.
 * "Release early. Release often." Basically same as the first point but
   in this case it means you'll get lots of broken code - this readme
   will change a LOT before you can use this project for anything useful.
 * CPemu was very much designed to be a single purpose hack, I am hoping
   this can be a little bit more versatile, useful, and be code one can use
   for other system utility and development or productivity software for
   running on the Next in the future.

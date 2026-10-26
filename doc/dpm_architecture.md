# DP/M architecture

DP/M is a CP/M 2.2 emulator for the ZX Spectrum Next. It emulates CP/M at the BDOS level: programs make CP/M 2.2 BDOS calls, and DP/M does the file work with NextZXOS's esxDOS calls.

DP/M is one dot command, `DPM`. It stays running for the whole CP/M session, and when it ends it returns to NextZXOS.

## Starting

The `DPM` file is the dot command, followed by three binaries: the kernel, the BIOS and the BDOS (`Makefile` target `dot`). NextZXOS loads the dot command at `$2000`. The dot command (`src/DPM.asm`):

1. Saves the dot command's arguments as a command line for the CCP (`save_args`).
2. Checks for a Z80N CPU, and ends with an error if it is not there.
3. Saves the machine state that it changes (`backup_state`): the CPU speed, the border, the I register, the interrupt state and the pages in MMU slots 2 to 7. It then sets the CPU to 28 MHz.
4. Allocates its memory pages from NextZXOS (`allocate_memory`), and copies `$4000`-`$7FFF` into two of them.
5. Reads the kernel, the BIOS and the BDOS from the end of its own file into their pages.
6. Calls `KERNEL.setup`, and then jumps to `BIOS.entry_BOOTROM`.

`KERNEL.setup` (`src/inc/kernel/ROM.asm`) saves every NextReg it changes, checks the install folder, makes any missing drive folder, reads `config.ini`, sets up the tilemap, the font, the palette and the frame interrupt, and writes the page zero jumps.

The install folder is `C:/DPM/`. The path is fixed when DP/M is assembled (`config.install_path` in `src/inc/kernel/data.asm`). If the folder is missing, DP/M ends with the error "Missing folder" and the path.

## Memory

DP/M allocates every page it uses through NextZXOS (`IDE_BANK` through `M_P3DOS`, in `src/inc/nextzxos.asm`), and gives them all back at exit. The pages are:

- Eight 8K pages that make the CP/M 64K.
- Two 8K pages for the kernel.
- Two 8K pages that keep a copy of `$4000`-`$7FFF` from before DP/M started.

### The CP/M 64K

While a CP/M program runs, the eight CP/M pages are in all eight MMU slots. The layout (`src/inc/addresses.asm`) is:

| Address | Contents |
|---|---|
| `$0000`-`$00FF` | Page zero: the jump to the BIOS warm boot at `$0000`, IOBYTE, the drive and user byte, the jump to the BDOS at `$0005`, the default FCB and the default DMA buffer |
| `$0100`-`$F1FF` | The TPA, where programs load |
| `$F200`-`$F9FF` | The CCP, loaded from `CCP.COM` |
| `$FA00`-`$FDFF` | The resident part of the BDOS (`src/BDOS.asm`) |
| `$FE00`-`$FFFF` | The BIOS jump table and stack (`src/BIOS.asm`) |

The address at `$0006` is `$FA06`, the BDOS entry. This is the top of the TPA.

The resident BDOS is a small part of the BDOS that must stay in the 64K. It has the BDOS entry, the FCB and DMA caches (`fcb_cache`, `dma_cache`), the disk parameter block and allocation vector that functions 31 and 27 return, and the frame interrupt's vector table and handler (`BLINK`).

### The kernel

Most of DP/M is the kernel (`src/kernel.asm` and `src/inc/kernel/`): the BDOS functions, the BIOS functions, the terminal and keyboard drivers and the configuration. It is assembled for `$8000`-`$BFFF`, with its stack at the top.

The kernel is in its own two pages, outside the CP/M 64K. Each BDOS call and each BIOS call that goes to the kernel:

1. Disables interrupts and changes to the BIOS stack.
2. Puts the kernel pages in MMU slots 4 and 5 (`$8000`-`$BFFF`).
3. Calls the kernel routine.
4. Puts the CP/M pages back in slots 4 and 5, changes back to the caller's stack and enables interrupts.

The BDOS entry is `BDOS.entry`, and it calls `KERNEL.bdos_dispatch`. The BIOS entries use `internal_KERNEL_call`, through the macro `m_BIOSStackAndCall`.

The program's memory at `$8000`-`$BFFF` is not visible while the kernel is mapped. So the kernel copies FCBs, records and strings through the caches in the resident BDOS (`cache_calling_fcb`, `copy_dma_out_kernel`, `copy_dma_in_kernel`, `copy_userland`).

### $4000-$7FFF and the display

While DP/M runs, the ULA display is off and the tilemap uses bank 5: the tile definitions are at `$4000` and the tilemap is at `$6400`. The kernel maps bank 5 into slots 2 and 3 when it writes to the screen (`KERNEL_TERM.map_graphics_mem`), and puts the CP/M pages back after.

## Calls to NextZXOS

Every file operation is an esxDOS call. For each call the kernel pages the DivMMC back in at `$0000`-`$3FFF`, with the dot command's memory at `$2000`, and changes to the dot command's stack (macro `m_kr_esxdos`, with `enable_esxdos_rom` and `disable_esxdos_rom`).

## BIOS

The BIOS jump table is at `$FE00`. Only the console entries do work:

- CONST, CONIN and CONOUT use DP/M's own keyboard and terminal drivers.
- LIST and PUNCH send the character to CONOUT.
- READER, LISTST and the disk entries (HOME, SELDSK, SETTRK, SETSEC, SETDMA, READ, WRITE, SECTRAN) are not implemented. Each one prints a message that names the entry and returns A = `$FF`.
- Entries 17 to 28 return at once.
- Entry 29 is DPM control (see below).

Cold boot and warm boot both load `CCP.COM` again. A warm boot also closes all open files and the directory search, writes the page zero jumps again and sets the DMA address to `$0080`. The CCP starts on the drive and user in the byte at `$0004`.

## BDOS

The BDOS returns version 2.2 (function 12). Functions 38, 39 and 41 to 48, which belong to MP/M and CP/M 3, return A = 0. Function 3 (reader input) returns `^Z` at once, function 4 (punch output) discards the character, and function 5 (list output) writes to the console.

### Drives

DP/M has drives A: to P:.

- A: and B: are folders in the install folder, one for each user number: `C:/DPM/A/0/` to `C:/DPM/A/15/`, and the same for `B`. `KERNEL.setup` makes any of these folders that is missing.
- C: to P: are the NextZXOS drives with the same letter. DP/M uses each one relative to that drive's current directory in NextZXOS. The user number has no effect on these drives. `FATCD.COM` shows and changes that directory (see FAT directories below).

Selecting a drive that NextZXOS does not have gives "BDOS Error on d: Select". The path for each file is made by `KERNEL_BDOS.drive_and_user_to_path` (`src/inc/kernel/BDOS.asm`).

## The CCP

The CCP is the file `CCP.COM` in the install folder. The kernel loads it at `$F200` at every cold boot and every warm boot (`KERNEL.BOOTROM` and `load_ccp` in `src/inc/kernel/ROM.asm`). If the file cannot be loaded, or it is empty, DP/M ends with the error "Cannot load" and the path.

The file name and its folder are fixed when DP/M is assembled. A different CCP can replace `CCP.COM` if it has this layout:

- At `$F200`, a jump that runs the command line in its buffer.
- At `$F203`, a jump that shows the prompt with an empty buffer.
- At `$F207`, the length of the command line, and from `$F208` its text, ending in 0.
- It fits below the BDOS at `$FA00`. A longer file is cut off there.

DP/M starts the CCP with the drive and user in register C. At cold boot, if the dot command had arguments, DP/M puts them in the CCP's buffer as one command line and starts the CCP at `$F200`, so the line runs once. At other times DP/M starts the CCP at `$F203`. `src/CCP.asm` is DP/M's own CCP.

## Console

The console is a VT100 terminal with ANSI colours on the tilemap, 80x32 text mode, using 30 rows from row 1 so that a 60 Hz display shows all of it (`src/inc/kernel/terminal.asm`, whose header lists the control codes and escape sequences). It scrolls with the tilemap offset (NextReg `$31`) and shows reverse video with tiles 256 to 511.

### Keyboard

DP/M reads the keyboard matrix directly (`src/inc/kernel/keyboard.asm`), because the NextZXOS system variables are not available while DP/M runs. Keys go into a 16-byte input queue.

- CAPS SHIFT and SYMBOL SHIFT pressed and released with no other key select Extended mode for the next key. Extended mode with 1 to 4 gives PF1 to PF4.
- The cursor keys and PF1 to PF4 send VT100 escape sequences.
- CAPS SHIFT and 2 switches caps lock on or off.

### Default colours

The console's default ink and paper colours are in the `[console]` section of `config.ini` in the install folder, as `ink=` and `paper=` lines. Each value is a colour name: black, red, green, yellow, blue, magenta, cyan or white. DP/M reads the file at start. If there is no file, DP/M uses green on black. DPM control function `$01` changes the colours and writes them to the file, and `CONCOLOR.COM` uses this function.

## Interrupts

DP/M runs the Z80 in interrupt mode 2 with hardware IM2 vectors (NextReg `$C0` bit 0). Only the ULA frame interrupt is enabled. The vector table and the handler (`BLINK` in `src/BDOS.asm`) are in the resident BDOS, which is in MMU slot 7 in every mapping.

Interrupts are on while a CP/M program runs and while CONIN waits for a key. They are off while the kernel runs. On each frame the handler:

- Scans the keyboard and puts a new key in the input queue, so that keys typed while a program is busy are kept. It does not scan while CONIN waits, because CONIN scans the keyboard itself.
- Blinks the cursor.

## DPM control

DPM control is DP/M's own BIOS entry, for CP/M programs. It is entry 29 of the BIOS jump table, 84 bytes after the warm boot entry. A program finds it from the address at `$0001`. The function number goes in register C (`BIOS_CONTROL` in `src/inc/kernel/ROM.asm`).

| C | Function | Parameters | Result |
|---|---|---|---|
| `$00` | End DP/M and return to NextZXOS. Open files and the directory search are closed first. | None | Does not return |
| `$01` | Set the console's default colours, and write them to `config.ini`. | D = ink, E = paper, each 0 to 7 in the order of the colour names above | A = 0, or `$FF` for a colour above 7 or an error with `config.ini` |
| `$02` | Change a drive's current directory in NextZXOS. | B = drive (0 = A:), DE = the path, ending in 0 | A = 0, or an esxDOS error code |
| `$03` | Get a drive's current directory. | B = drive, DE = a 263-byte buffer | A = 0 and the path in the buffer, ending in 0, or an esxDOS error code |
| `$04` | Get the name of one directory in a drive's current directory. | B = drive, HL = the index of the directory (0 = the first), DE = a 263-byte buffer | A = 0 and the name in the buffer, ending in 0, `$FF` when there is no directory with that index, or an esxDOS error code |

Any other function number returns A = `$FF`.

Functions `$02` and `$03` close all open files and the directory search first, because file paths are relative to the drive's directory. `$02` takes a path of up to 256 characters, absolute or relative to the drive's current directory, with long or 8.3 names. `$03` gives the path as esxDOS function `F_GETCWD` gives it: the drive, 8.3 names and a closing slash, for example `C:/FATTEST/`.

Function `$04` reads the drive's current directory and counts only its directories. It leaves out `.`, so in a subdirectory `..` is directory 0. The order is the order esxDOS reads the entries. The name is the long name, or the 8.3 name of a directory that has no long name. `$04` does not close open files or the directory search, so a program can call it between search first and search next.

A drive that is not mapped gives esxDOS error 11 (No such drive). DP/M finds what a drive is with the NextZXOS call `IDE_DOS_MAPPING`. The RAMdisk and `.P3D` or `.DSK` image drives (P3DOS drives) have no directories: `$03` gives `/`, `$02` gives esxDOS error 17 (Not a directory), and `$04` gives `$FF`. A directory changed with `$02` stays changed in NextZXOS after DP/M ends.

The CCP command `EXIT` and the program `EXIT.COM` use function `$00`. `FATCD.COM` uses functions `$02` and `$03`, and `FATDIR.COM` uses `$03` and `$04`.

## FAT directories

Each of the drives C: to P: is the current directory of the NextZXOS drive with the same letter. Two programs on drive A:, user 0, show and change these directories. Their source is in `src/com/fat/`. They are C programs, and `make fat` compiles them with z88dk's zsdcc compiler in z88dk's Docker image.

`FATCD d:` prints the current directory of drive `d:`. `FATCD d: path` changes it, and prints nothing when the change works:

```
A0>FATCD C: /FATTEST/Long Folder Name
A0>FATCD C:
/FATTEST/LONGFO~1
A0>FATCD C: ..
```

- The path is absolute, or relative to the current directory. It is the rest of the command line after the drive. Spaces inside it are kept, so a folder name with spaces needs no quotes. Spaces at the end are dropped, and a path cannot start with a space.
- A path can use long names or 8.3 names. FATCD prints 8.3 names, because NextZXOS gives the current directory in that form. It prints the path without the drive and without a closing slash. The root is `/`.
- A: and B: are DP/M's own drives, not NextZXOS drives, and FATCD refuses them.
- A P3DOS drive, such as the RAMdisk, has no directories. FATCD prints `/` for it, and a change gives "Not a directory".
- An error prints the esxDOS message, for example "No such drive" for a drive that is not mapped, or "Not a directory" for a path that does not exist.
- With no arguments, FATCD prints its usage.

`FATDIR d:` prints the current directory of drive `d:` as `FATCD d:` prints it, then the names of the directories in it, one to a line:

```
A0>FATDIR C:
/FATTEST/SUB
..
```

- In a subdirectory, `..` is first. The other names follow in the order esxDOS reads them.
- Each name is the long name, or the 8.3 name of a directory that has no long name. `FATCD` accepts either.
- FATDIR lists directories only, not files. `DIR` lists the files.
- A: and B: are refused, as in FATCD. For a P3DOS drive FATDIR prints `/` and no names.
- With no arguments, FATDIR prints its usage.

## Exit

At exit DP/M (`KERNEL.exit`, and `memmap_exit` and `state_exit` in `src/DPM.asm`):

- Puts back the NextRegs that setup changed, the tilemap palette and the interrupt control and enable registers.
- Copies `$4000`-`$7FFF` back, and puts back the pages NextZXOS had in MMU slots 2 to 7.
- Frees every page it allocated.
- Puts back the border, the CPU speed and the I register, selects interrupt mode 1 and puts back the interrupt enable state.

It does not put back a drive directory changed with DPM control `$02`, or the NextReg select port `$243B`.

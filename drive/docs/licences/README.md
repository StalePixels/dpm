# Drive A, user 0

DP/M installs a set of CP/M programs on drive A, user 0. On the SD card they are in the folder `A/0` of the DP/M install folder, `C:/DPM/A/0`. This file and the licence files it names are in `docs/licences` of the same install folder.

## Source

`EXIT` and `CONCOLOR` are part of DP/M. Their source is in the DP/M repository, https://github.com/Xalior/dpm.

The other programs are built from cpmish, https://github.com/StalePixels/cpmish, branch `DPM`.

## Licences

| Program | Licence | File |
|---|---|---|
| `EXIT`, `CONCOLOR` | GNU LGPL version 3 | `COPYING.lgpl3`, with `COPYING.camelforth` |
| `COPY`, `DUMP`, `QE`, `STAT`, `SUBMIT` | BSD 2-clause | `COPYING.cpmish` |
| `ASM` | BSD 2-clause per cpmish's README (the source header says MIT) | `COPYING.cpmish` |
| `BBCBASIC` | zlib | `COPYING.bbcbasic` |
| `CAMEL80` | GNU GPL version 3 or later | `COPYING.camelforth` |
| `TED` | GNU GPL version 2 or later | `LICENSE.ted` |
| `Z8E` | Public domain, as `COPYING.z8e` explains | `COPYING.z8e` |
| `ASM80` | Digital Research release | `dr/COPYING.md`, `dr/CPM-LICENSE.txt` (from cpm.z80.de/license.html) |
| `STARTREK` | Free to redistribute and modify in any way | `COPYING.startrek` (the header of `startrek.c`) |

The GNU LGPL version 3 is a set of additional permissions to the GNU GPL version 3. `COPYING.camelforth` is the text of the GNU GPL version 3.

cpmish as a whole is distributed under the GNU GPL version 2 (`COPYING.gpl2`), because it contains GPL code; each part keeps its own licence.

# Drive A, user 0

The `.COM` files in `drive/A/0/` are the programs DP/M puts on drive A, user 0. `make install_emu` copies them to `/DPM/A/0` on the SD card, and `make release` puts them in `A/0/` in the release ZIP. This `licences/` folder goes to `/DPM/docs/licences` on the card and in the release ZIP.

## Source

The programs are built from cpmish, the `cpmish/` submodule of this repository (https://github.com/StalePixels/cpmish, branch `DPM`), at the commit the submodule is pinned to. `git submodule status cpmish` shows that commit.

## Rebuilding

Docker must be running. From the top of this repository:

```
git submodule update --init cpmish
make cpmish
```

`make cpmish` runs `dev/cpmish/build.sh` (Docker) on the `cpmish` submodule into a temporary folder, then replaces the `.COM` files in `drive/A/0/` with the new ones.

## Licences

| Program | Licence | File |
|---|---|---|
| `COPY`, `DUMP`, `QE`, `STAT`, `SUBMIT` | BSD 2-clause | `COPYING.cpmish` |
| `ASM` | BSD 2-clause per cpmish's README (the source header says MIT) | `COPYING.cpmish` |
| `BBCBASIC` | zlib | `COPYING.bbcbasic` |
| `CAMEL80` | GNU GPL version 3 or later | `COPYING.camelforth` |
| `TED` | GNU GPL version 2 or later | `LICENSE.ted` |
| `Z8E` | Public domain, as `COPYING.z8e` explains | `COPYING.z8e` |
| `ASM80` | Digital Research release | `dr/COPYING.md`, `dr/CPM-LICENSE.txt` (from cpm.z80.de/license.html) |
| `STARTREK` | Free to redistribute and modify in any way | `COPYING.startrek` (the header of `startrek.c`) |

cpmish as a whole is distributed under the GNU GPL version 2 (`COPYING.gpl2`), because it contains GPL code; each part keeps its own licence. The source of every program is in the `cpmish/` submodule.

# External commands we use, override with Env Vars
MONO:=mono
CAT:=cat
CP:=cp
TOUCH:=touch
MKDIR:=mkdir -pv
ECHO:=echo
SJASMPLUS:=sjasmplus
ZCC:=zcc
HDIUTIL:=hdiutil
MAME:=mame
SEQ:=seq
TXT2BAS:=txt2bas
ZIP:=zip

# --- Emulator image: NextZXOS SD card. Its FAT volume is labelled "DPM",
#     so it always mounts at /Volumes/DPM (see `install_emu`).
IMAGE:=2gb/cspect-next-2gb.img
MOUNT:=/Volumes/DPM
# NextZXOS dot-commands live in DOT_DIR (so build/DPM installs as .DPM);
# EMU_PATH is DP/M's install folder: CCP.COM, and the CP/M emulated drives
# (A/0..15, B/0..15).
DOT_DIR:=$(MOUNT)/dot
EMU_PATH=$(MOUNT)/DPM
# autoexec.bas source (tracked, human-readable NextBASIC) -> tokenised onto image.
# Boots DP/M: issues OUT 12091,0 (revert nextfaststart overclock) then runs .dpm.
AUTOEXEC_SRC:=dev/autoexec.bas.txt
AUTOEXEC_DST:=$(MOUNT)/nextzxos/autoexec.bas
# The programs on drive A, user 0: cpmish's .COM files, built by the cpmish
# submodule and committed here. Their licences go to /DPM/docs/licences.
DRIVE_A0:=drive/A/0
DRIVE_DOCS:=drive/docs
# The release ZIP, named from DPMversion in src/inc/version.asm. Not committed.
VERSION:=$(shell sed -n 's/.*DEFINE DPMversion "\(.*\)".*/\1/p' src/inc/version.asm)
RELEASE_ZIP:=build/dpm-$(VERSION).zip

# --- MAME: ZX Spectrum Next driver + Next debugging plugins.
#     nextbreak    traps the $FD $00 opcode emitted by m_CSpect_BREAK, so the
#                  in-code breakpoints fire exactly as under CSpect.
#     debugstart   keeps -debug enabled but HIDES the debugger window at boot,
#                  so the machine runs until a breakpoint opcode fires.
#     nextfaststart skips the NextZXOS boot delay.
#     Plugins: https://github.com/Threetwosevensixseven/MAMENextPlugins
#     They live in MAME's pluginspath next to MAME's boot.lua bootstrap
#     (https://github.com/mamedev/mame/blob/master/plugins/boot.lua) and are
#     enabled in plugin.ini -- see ../../docs/emulator.md for the full setup.
MAME_SYS:=tbblue
MAME_RUN:=$(MAME) $(MAME_SYS) -hard1 $(IMAGE) \
		-window -nomaximize -resolution 1024x768 -nothrottle \
		-debug -plugin nextbreak,debugstart,nextfaststart

.PHONY: dev emulate turbo dot ccp exit concolor cpmish release install_emu autoexec mount_image unmount_image \
        cspect cspect_turbo setup_emulator setup_emulator_testfiles \
        _setup_dirs _setup_files

# Run under MAME (debugger stays hidden until a breakpoint opcode fires).
emulate:
	$(MAME_RUN)

# As above but unthrottled (the old CSpect "turbo"; breakpoints still live).
turbo:
	$(MAME_RUN) -nothrottle

# CSpect fallback (pre-MAME). Remove once the MAME spike is confirmed.
cspect:
	$(MONO) CSpect/CSpect.exe -sound -mouse -w8 -zxnext -r -joy -esc -basickeys -brk -16bit -fps -mmc=$(IMAGE) -map=src/DPM.map

cspect_turbo:
	$(MONO) CSpect/CSpect.exe -sound -mouse -w8 -zxnext -r -joy -esc -basickeys -brk -16bit -freerun -fps -mmc=$(IMAGE) -map=src/DPM.map

dot:
	cd src && $(SJASMPLUS) DPM.asm
	$(CAT) build/DPM.dot > build/DPM		# Create a new file with CPemu.dot contents
	$(CAT) build/kernel >> build/DPM		#   & Append kernel to dot command
	$(CAT) build/BIOS >> build/DPM			#    & Append BIOS to dot command
	$(CAT) build/BDOS >> build/DPM			#    & Append BDOS to dot command

# The CCP, assembled on its own. The kernel loads it from EMU_PATH/CCP.COM
# at every cold and warm boot.
ccp:
	cd src && $(SJASMPLUS) CCP.asm

# EXIT.COM, the CP/M program that ends DP/M, built into DRIVE_A0 with the
# other drive A, user 0 programs.
exit:
	cd src && $(SJASMPLUS) EXIT.asm
	$(CP) build/EXIT.COM $(DRIVE_A0)/EXIT.COM

# CONCOLOR.COM, the CP/M program that sets DP/M's default console colours,
# a C program built with z88dk into DRIVE_A0 with the other drive A, user 0
# programs.
concolor:
	cd src/concolor && $(ZCC) +cpm -O2 concolor.c -o ../../build/CONCOLOR.COM
	$(CP) build/CONCOLOR.COM $(DRIVE_A0)/CONCOLOR.COM

# Rebuild cpmish's programs (dev/cpmish/build.sh, in Docker) into a temporary
# folder, then replace the .COM files in DRIVE_A0 with them, names upper-cased
# as on a CP/M disk.
cpmish:
	tmp=$$(mktemp -d) && dev/cpmish/build.sh cpmish $$tmp && \
	for f in $$tmp/*.com; do \
		$(CP) $$f $(DRIVE_A0)/$$(basename $$f .com | tr a-z A-Z).COM; \
	done && \
	rm -rf $$tmp

# The release ZIP, extracted by the user into C:/DPM/: the dot command DPM,
# CCP.COM, the empty drive folders A/0..15 and B/0..15 (stored as folder
# entries, so they exist after extraction), the DRIVE_A0 programs in A/0, and
# the licences in docs/. Nothing else.
release: dot ccp exit concolor
	rm -f $(RELEASE_ZIP)
	tmp=$$(mktemp -d) && \
	$(CP) build/DPM build/CCP.COM $$tmp/ && \
	for d in A B; do for u in $$($(SEQ) 0 15); do $(MKDIR) $$tmp/$$d/$$u; done; done && \
	$(CP) $(DRIVE_A0)/*.COM $$tmp/A/0/ && \
	$(CP) -R $(DRIVE_DOCS) $$tmp/docs && \
	(cd $$tmp && $(ZIP) -r -X $(CURDIR)/$(RELEASE_ZIP) DPM CCP.COM A B docs) && \
	rm -rf $$tmp

# Mount the image, copy the freshly built dot, CCP.COM, the DRIVE_A0
# programs and the licences in, then unmount so the image is free for MAME (macOS and
# MAME must not hold the FAT volume at once).
install_emu:
	@$(HDIUTIL) detach $(MOUNT) >/dev/null 2>&1 || true
	$(HDIUTIL) attach -nobrowse -imagekey diskimage-class=CRawDiskImage $(IMAGE)
	$(CP) build/DPM $(DOT_DIR)/DPM
	$(MKDIR) $(EMU_PATH)
	$(CP) build/CCP.COM $(EMU_PATH)/CCP.COM
	$(MKDIR) $(EMU_PATH)/A/0
	$(CP) $(DRIVE_A0)/*.COM $(EMU_PATH)/A/0/
	$(MKDIR) $(EMU_PATH)/docs
	$(CP) -R $(DRIVE_DOCS)/licences $(EMU_PATH)/docs/
	$(HDIUTIL) detach $(MOUNT)

# Tokenise dev/autoexec.bas.txt and install it onto the image as the boot
# autoexec.bas. Validates first (txt2bas -t catches some errors, but only a
# real Next/MAME truly validates NextBASIC). Self-mounts/unmounts.
autoexec:
	$(TXT2BAS) -t -i $(AUTOEXEC_SRC)
	@$(HDIUTIL) detach $(MOUNT) >/dev/null 2>&1 || true
	$(HDIUTIL) attach -nobrowse -imagekey diskimage-class=CRawDiskImage $(IMAGE)
	$(TXT2BAS) -f 3dos -i $(AUTOEXEC_SRC) -o "$(AUTOEXEC_DST)"
	$(HDIUTIL) detach $(MOUNT)

# Manual mount/unmount (for setup_emulator, or poking the image by hand).
mount_image:
	@$(HDIUTIL) detach $(MOUNT) >/dev/null 2>&1 || true
	$(HDIUTIL) attach -nobrowse -imagekey diskimage-class=CRawDiskImage $(IMAGE)

unmount_image:
	$(HDIUTIL) detach $(MOUNT)

dev: dot ccp exit install_emu turbo

# Mount the image, create the CP/M drive tree (C:/DPM/{A,B}/{0..15}) that the
# kernel's setup probes with F_OPENDIR, then unmount. (_setup_dirs does the
# actual mkdirs; it runs via recursive make while the image is mounted.)
setup_emulator:
	@$(HDIUTIL) detach $(MOUNT) >/dev/null 2>&1 || true
	$(HDIUTIL) attach -nobrowse -imagekey diskimage-class=CRawDiskImage $(IMAGE)
	$(MAKE) _setup_dirs
	$(HDIUTIL) detach $(MOUNT)

_setup_dirs:
	@$(MKDIR) $(EMU_PATH)/A/0
	@$(MKDIR) $(EMU_PATH)/A/1
	@$(MKDIR) $(EMU_PATH)/A/2
	@$(MKDIR) $(EMU_PATH)/A/3
	@$(MKDIR) $(EMU_PATH)/A/4
	@$(MKDIR) $(EMU_PATH)/A/5
	@$(MKDIR) $(EMU_PATH)/A/6
	@$(MKDIR) $(EMU_PATH)/A/7
	@$(MKDIR) $(EMU_PATH)/A/8
	@$(MKDIR) $(EMU_PATH)/A/9
	@$(MKDIR) $(EMU_PATH)/A/10
	@$(MKDIR) $(EMU_PATH)/A/11
	@$(MKDIR) $(EMU_PATH)/A/12
	@$(MKDIR) $(EMU_PATH)/A/13
	@$(MKDIR) $(EMU_PATH)/A/14
	@$(MKDIR) $(EMU_PATH)/A/15
	@$(MKDIR) $(EMU_PATH)/B/0
	@$(MKDIR) $(EMU_PATH)/B/1
	@$(MKDIR) $(EMU_PATH)/B/2
	@$(MKDIR) $(EMU_PATH)/B/3
	@$(MKDIR) $(EMU_PATH)/B/4
	@$(MKDIR) $(EMU_PATH)/B/5
	@$(MKDIR) $(EMU_PATH)/B/6
	@$(MKDIR) $(EMU_PATH)/B/7
	@$(MKDIR) $(EMU_PATH)/B/8
	@$(MKDIR) $(EMU_PATH)/B/9
	@$(MKDIR) $(EMU_PATH)/B/10
	@$(MKDIR) $(EMU_PATH)/B/11
	@$(MKDIR) $(EMU_PATH)/B/12
	@$(MKDIR) $(EMU_PATH)/B/13
	@$(MKDIR) $(EMU_PATH)/B/14
	@$(MKDIR) $(EMU_PATH)/B/15

# As setup_emulator, plus a set of edge-case test files in A/0.
setup_emulator_testfiles:
	@$(HDIUTIL) detach $(MOUNT) >/dev/null 2>&1 || true
	$(HDIUTIL) attach -nobrowse -imagekey diskimage-class=CRawDiskImage $(IMAGE)
	$(MAKE) _setup_dirs
	$(MAKE) _setup_files
	$(HDIUTIL) detach $(MOUNT)

_setup_files:
	@$(TOUCH) "$(EMU_PATH)/A/0/empty.one"
	@$(TOUCH) "$(EMU_PATH)/A/0/empty.two"
	@$(TOUCH) "$(EMU_PATH)/A/0/eightchr.emp"
	@$(TOUCH) "$(EMU_PATH)/A/0/noext"
	@$(TOUCH) "$(EMU_PATH)/A/0/long space"
	@$(TOUCH) "$(EMU_PATH)/A/0/1 2 3.num"
	@$(ECHO) "test data" > "$(EMU_PATH)/A/0/test.txt"
	@$(ECHO) "test data for 3" > "$(EMU_PATH)/A/0/test_3.txt"
	@$(ECHO) "test data for longfile1" > "$(EMU_PATH)/A/0/longfile1.txt"
	@$(ECHO) "test data for longfile2" > "$(EMU_PATH)/A/0/longfile2.txt"
	@$(ECHO) "test data for spaces       " > "$(EMU_PATH)/A/0/spaces .txt"
	@$(TOUCH) "$(EMU_PATH)/A/0/stuff"
	@$(TOUCH) "$(EMU_PATH)/A/0/things"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.000"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.001"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.002"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.003"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.004"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.005"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.006"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.007"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.008"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.009"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.00A"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.00B"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.00C"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.00D"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.00E"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.00F"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.010"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.011"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.012"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.013"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.014"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.015"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.016"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.017"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.018"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.019"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.01A"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.01B"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.01C"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.01D"
	@$(TOUCH) "$(EMU_PATH)/A/0/bulk.01E"
	@$(SEQ) -w 1 16 | while read n; do printf 'Line %s of 16: DPM multi-block TYPE test, wide line to limit scrolling. .END\r\n' "$$n"; done > "$(EMU_PATH)/A/0/big.txt"
	@printf '%0128d' 0 | tr '0' '.' > "$(EMU_PATH)/A/0/rec128.txt"
	@printf '%0256d' 0 | tr '0' '.' > "$(EMU_PATH)/A/0/rec256.txt"
	@$(ECHO) "rename me" > "$(EMU_PATH)/A/0/rename.me"
	@$(ECHO) "this file lives in user area 1" > "$(EMU_PATH)/A/1/user1.txt"
	@$(ECHO) "this file lives on drive B" > "$(EMU_PATH)/B/0/bdrive.txt"
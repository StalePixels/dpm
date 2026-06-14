# External commands we use, override with Env Vars
MONO:=mono
CAT:=cat
CP:=cp
TOUCH:=touch
MKDIR:=mkdir -pv
ECHO:=echo
SJASMPLUS:=sjasmplus
HDIUTIL:=hdiutil
MAME:=mame
TXT2BAS:=txt2bas

# --- Emulator image: NextZXOS SD card. Its FAT volume is labelled "DPM",
#     so it always mounts at /Volumes/DPM (see `install_emu`).
IMAGE:=2gb/cspect-next-2gb.img
MOUNT:=/Volumes/DPM
# NextZXOS dot-commands live in DOT_DIR (so build/DPM installs as .DPM);
# EMU_PATH is where the CP/M emulated drives (A/0..15, B/0..15) live.
DOT_DIR:=$(MOUNT)/dot
EMU_PATH=$(MOUNT)/DPM
# autoexec.bas source (tracked, human-readable NextBASIC) -> tokenised onto image.
# Boots DP/M: issues OUT 12091,0 (revert nextfaststart overclock) then runs .dpm.
AUTOEXEC_SRC:=dev/autoexec.bas.txt
AUTOEXEC_DST:=$(MOUNT)/nextzxos/autoexec.bas

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
MAME_RUN:=$(MAME) $(MAME_SYS) -hard1 $(IMAGE) -debug -plugin nextbreak,debugstart,nextfaststart

.PHONY: dev emulate turbo dot install_emu autoexec mount_image unmount_image \
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
	$(CAT) build/CCP >> build/DPM			#    & Append CCP to dot command

# Mount the image, copy the freshly built dot in, then unmount so the image
# is free for MAME (macOS and MAME must not hold the FAT volume at once).
install_emu:
	@$(HDIUTIL) detach $(MOUNT) >/dev/null 2>&1 || true
	$(HDIUTIL) attach -nobrowse -imagekey diskimage-class=CRawDiskImage $(IMAGE)
	$(CP) build/DPM $(DOT_DIR)/DPM
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

dev: dot install_emu turbo

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
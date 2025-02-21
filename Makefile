# External commands we use, override with Env Vars
MONO:=mono
CAT:=cat
TOUCH:=touch
MKDIR:=mkdir -pv
ECHO:=echo
SJASMPLUS:=sjasmplus

EMU_PATH=/Volumes/DPM/DPM

emulate:
	$(MONO) CSpect/CSpect.exe -sound -mouse -w8 -zxnext -r -joy -esc -basickeys -brk -fps -mmc=2gb/cspect-next-2gb.img -map=src/DPM.map

turbo:
	$(MONO) CSpect/CSpect.exe -sound -mouse -w8 -zxnext -r -joy -esc -basickeys -brk -freerun -fps -mmc=2gb/cspect-next-2gb.img -map=src/DPM.map

dot:
	cd src && $(SJASMPLUS) DPM.asm
	$(CAT) build/DPM.dot > build/DPM		# Create a new file with CPemu.dot contents
	$(CAT) build/kernel >> build/DPM		#   & Append kernel to dot command
	$(CAT) build/BIOS >> build/DPM			#    & Append BIOS to dot command
	$(CAT) build/BDOS >> build/DPM			#    & Append BDOS to dot command

setup_emulator:
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

setup_emulator_testfiles: setup_emulator
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
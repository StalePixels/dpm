v1.2.0

 - FATCD shows and changes the directory of drives C: to P:
 - FATDIR lists the directories in it
 - DPM control functions $02, $03 and $04 change, get and list FAT directories
 - Both UARTs at 115,200 baud, 8N1: the ESP WiFi module and the Pi
 - LST:, RDR:, PUN: and CON: follow IOBYTE
 - STAT DEV: shows the devices, and STAT sets them, for example STAT LST:=TTY:
 - IOBYTE at cold boot is $95: LST: to the Pi, RDR: and PUN: to the ESP
 - CON: BAT:, which IOBYTE terminal programs use: Kermit-80, MDM7, MEX, ZMP, QTerm
 - A 64K receive buffer for each UART, filled by its receive interrupt
 - TELNET.COM, a telnet client on the ESP WiFi module
 - Extended mode + a letter gives CTRL and that letter, for example CTRL-B
 - Faster console output and BIOS console calls
 - The DRIVE and M1 (NMI) buttons do nothing while DP/M runs
 - Exit puts back the UART select, NextReg $A0 and NextReg $06
 - DP/M needs 28 free 8K pages (224K)
 - FATCD and FATDIR are built with zsdcc in z88dk's Docker image
 - The EXIT.COM source is in src/com/exit/, CONCOLOR's in src/com/concolor/

v1.1.0

 - VT100 terminal with ANSI colour, bold and reverse video, replacing VT52
 - Hardware scrolling, blinking cursor and keyboard type-ahead
 - VT100 cursor keys, PF1-PF4 on Extended mode + 1-4, and terminal replies
 - CONCOLOR sets the default console colours, kept in /DPM/config.ini
 - A: drive programs rebuilt for VT100
 - DP/M refuses to start if it can't find the installation directory

v1.0.1

 - NTSC Support
 - Increase usable screenspace and rebuild all static binaries
 - Make Ped7g happy by using sjasmplus in CI

v1.0.0 - Display Program/Monitor - 3/10/26

 - CP/M 2.2 BDOS emulator with FAT32 Support

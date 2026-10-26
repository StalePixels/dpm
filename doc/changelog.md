v1.2.0 (in progress)

 - DPM control function $02 changes the FAT working directory of a drive, $03 returns it
 - The EXIT.COM source is in src/com/exit/

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

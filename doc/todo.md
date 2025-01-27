Current todo list, in order

 * Boot "ROM" - in our case, dotcommand
	check if next
	allocate enough RAM for discard
	load discard
	jump to discard
 * Boot "Sector" - our discard code, run once at startup
	allocate rest of ram
	load rest of binaries
	jump to "ColdBoot" in DP/M Kernel
 * DP/M Kernel - our "out of main memory" BDOS 2 NextZXOS bridge
        load CCP.COM
 * CP/M BDOS entry points
        slim shim to MMU map kernel, and jump into

Stuff now done

**WARNING** this was part written with an LLM, and is not yet proof read - trust at your peril

The CP/M (Control Program for Microcomputers) architecture was designed to provide a simple, hardware-agnostic operating system for 8-bit microcomputers, particularly those based on the Intel 8080 and Zilog Z80 CPUs. CP/M abstracts hardware functionality and provides a consistent interface for running software. Its architecture consists of the following key components:

1. Basic Structure
	•	Memory Layout: CP/M typically assumes a flat memory model with a fixed location for the operating system components and application programs.
	•	Application programs typically occupy the high end of memory, starting at a fixed “transient program area” (TPA).
	•	The operating system resides in the lower memory addresses, leaving a significant portion of memory for applications.
	•	16-bit Address Space: With the limitations of the 8080/Z80 processors, CP/M operates within a 64KB memory space.
	

2. Major Components
	BIOS (Basic Input/Output System):
	•	The lowest level of CP/M.
	•	Provides hardware-dependent routines for I/O (e.g., disk access, serial communication).
	•	It is specific to the hardware platform and must be customized for each machine.
	•	Includes routines for initializing hardware, reading/writing to devices, and performing other platform-specific tasks.
	DP/M will use NextZXOS for all these operations - this is why it's called a "CP/M Emulator", not everything (spefifically low level applications which directly call the BIOS) will work.

	BDOS (Basic Disk Operating System):
	•	The middle layer, abstracting hardware access provided by the BIOS.
	•	Provides a hardware-independent API for file and device management.
	•	Implements system calls such as reading/writing files, allocating disk space, and retrieving system information.
	•	Manages CP/M’s flat file system, which organizes data using “extent-based” storage with a directory structure.
	DP/M aims to be a "BDOS level emulator" aka a "File level emulator", using NextZXOS's ESXDOS APIs for FAT32 support, etc.
	
	CCP (Console Command Processor):
	•	The command-line interface for the user.
	•	Handles user commands (e.g., launching programs, copying files).
	•	Supports built-in commands like DIR, ERA, and TYPE.
	•	For custom commands, it searches for .COM files in the current drive/user space and loads them into the TPA for execution.
	DP/M aims to support user-changable CCP replacements. 
	"Potential future enhancements" could well be an enhanced "NextZXOS Aware" shell, but that's an exercise for after the basic emulator has required functionality.

3. File System
	•	Flat Structure: CP/M uses a simple flat directory structure without hierarchical folders.
	•	Extent-Based File Allocation:
	•	Files are stored in contiguous “extents” managed by the BDOS.
	•	Directory entries contain metadata about the file (e.g., name, type, extents).
	•	User Numbers:
	•	Files can be grouped under “user numbers” (0–15), a primitive way to organize data by user or category.
	•	8.3 Filenames: File names are limited to 8 characters for the name and 3 for the extension.
	DP/M aims to "normalise" the filesystem API, where possible and practical, exposing the FAT32 working directory as a CP/M emulated drive.  
	The ability to change the current working directory of the FAT32 drive from within the emulator itself is classed as "potential future enhancements" at this stage.

4. TPA (Transient Program Area)
	•	The memory region reserved for user programs.
	•	Typically begins after the CCP and extends to the top of available memory.
	•	Programs loaded into the TPA execute directly in memory, interacting with the BDOS and BIOS for system services.
	DP/M's own Kernel/BDOS code should live outside of the main memory space, accessed via the MMU.

5. Peripheral Support
	•	CP/M assumes a basic set of peripherals:
	•	Console device (usually a serial terminal or screen/keyboard).
	•	Disk drives for file storage.
	•	Printer and serial communication devices.
	•	All I/O is abstracted by the BIOS to allow CP/M to run on various hardware platforms without modification.
	DP/M's will require all its own hardware drivers to be written - expected requirements are:
	•	Console: "Layer3" hardware textmode, for speed and versatility. This means a simple terminal handler will be required.
	•	Keyboard: Bare metal matrix scanning, classix ZX driver style - since sysvars will not be available.
	•	Disk drives: Enable ESXDOS RAM for IO operations, done as dotcommand, transparently mapped back to CP/M buffers.
	•	Printer and serial communications are considered "potential future enhancements" - this + console driver could be leveraged for BBS & NextPi terminal emulation.
	•	Other I/O has not yet been brought into consideration.

6. Execution Model
	•	When the system boots, the CCP is loaded and initializes the console.
	•	The CCP accepts user commands and uses the BDOS to load and execute .COM files.
	•	.COM programs are simple binary images loaded into the TPA, and upon termination, control returns to the CCP.
	DP/M's will load a fixed name CCP, statically named at compile time for the first iteration, meaning SUBMIT could be used to automate futher interactions. Replacement CCPs should be supported from the start, but the mechanism to configure them (as for many 'opinionated settings') should be considered  "potential future enhancements" at this time.

7. Hardware Independence
	•	CP/M’s separation of the BDOS and BIOS ensures that only the BIOS needs to be customized for different hardware.
	•	The BDOS and CCP remain the same across all platforms, allowing portability of software between machines.
	DP/M does **NOT** aim for hardware Independence - quite the opposite, DP/M will embrace hardware dependence if it futhers intergration with NextZXOS, or the Next's native features. Therefore things like Z80N to make our emulation faster and more lightweight should be embraced. DP/Ms BDOS will be very unique, and tightly coupled to NextZXOS, using the Next's own operating system as the BIOS.

8. Limitations
	•	No multitasking: CP/M runs a single program at a time.
	•	Limited memory usage: Restricted by the 64KB memory addressing of the 8080/Z80.
	•	Minimal file system: Lacks modern features like subdirectories and long filenames.
	DP/M actively does not support multitasking. It runs the Z80 in interrupt mode 2 with the Next's hardware IM2 vectors, and only the ULA frame interrupt is enabled; its handler blinks the cursor. Interrupts are on while a CP/M program runs and while console input waits for a key, and off while the kernel runs. On exit DP/M restores the interrupt NextRegs and sets interrupt mode 1 before it returns to NextZXOS.
	DP/M actively does not support CP/M 3.0 enhanced memory model, for simplicity at this stage.  Multitasking is not considered "potential future enhancements", that is left for the scope of DP/M > 1.0 ;-)

	 Multitasking and enchanced memory management are not considered "potential future enhancements" for this verion of DP/M, that is left for the scope of DP/M > 1.0 ;-)
	

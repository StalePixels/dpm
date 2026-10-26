;-----------------------------------------------------------------------------
; -- DPM UART driver
;
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A CP/M 2.2 Emulator for the Next - plays nice with BASIC, provides a FCB based
; filesystem layer emulator to allow limited access on FAT32 formatted drives.
;
;-----------------------------------------------------------------------------
    MODULE KERNEL_SERIAL
; The Next's two UARTs share ports $133B to $163B; port $153B bit 6 selects
; which one they reach. Both run at 115,200 baud, 8N1, with no flow control.
; Each UART's Rx near full interrupt (BLINK.esp_rx, BLINK.pi_rx) moves the
; bytes in its 512-byte Rx buffer to the end of a 64K ring in pages of its
; own, so the buffer does not overflow while a program is slow to read.
; The ring holds the older bytes and the Rx buffer the newer, so receive and
; status look at the ring first. Sending and an empty ring are polled. A
; wait for a UART has interrupts on, with BLINK.waiting set, as BIOS_CONIN
; waits for a key: the frame interrupt then blinks the cursor and leaves
; the kernel mapped.

ESP             EQU     %00000000           ; $153B: the ESP WiFi module
PI              EQU     %01000000           ; $153B: the Pi, on GPIO 14 and 15

; Both UARTs at 115,200 baud, 8N1, no flow control, their buffers emptied.
; The Pi's UART goes on GPIO 14 and 15, wired for the Pi (NextReg $A0 bits
; 5 and 4). The Pi is left selected.
;     Dirties AF, BC, DE, HL
setup:
        ld      a, (KERNEL.exit.SMC_pi_peripherals)
        or      %00110000                   ; UART on GPIO 14 and 15, Rx on 14 and Tx on 15
        nextreg PI_PERIPHERALS_ENABLE_NR_A0, a
        m_NextRegRead_c VIDEO_TIMING_NR_11  ; The system clock
        and     %00000111
        ld      hl, prescalers
        add     hl, a
        add     hl, a
        ld      e, (hl)                     ; Low 7 bits
        inc     hl
        ld      d, (hl)                     ; High 7 bits, with bit 7 set
        ld      a, ESP
        call    .uart
        ld      a, PI
        call    .uart
        nextreg INT_EN_2_NR_C6, %00100010   ; Both UARTs' Rx near full interrupts
        ret
.uart:
        ld      bc, UART_SELECT_P_153B
        out     (c), a
        ld      b, high UART_RX_P_143B
        out     (c), e                      ; The prescaler, low 7 bits first
        out     (c), d
        ld      b, high UART_FRAME_P_163B
        ld      a, %10011000                ; Hold the buffers empty, 8 bits
        out     (c), a
        ld      a, %00011000                ; 8 bits, no parity, 1 stop bit, no flow control
        out     (c), a
        ret

; The prescaler for 115,200 baud for each video timing, NextReg $11 bits
; 2:0: the system clock divided by 115,200. Each is written to $143B as its
; low 7 bits, then its high 7 bits with bit 7 set.
prescalers:
        db      243 & $7F, $80 | (243 >> 7) ; 0: 28,000,000
        db      248 & $7F, $80 | (248 >> 7) ; 1: 28,571,429
        db      256 & $7F, $80 | (256 >> 7) ; 2: 29,464,286
        db      260 & $7F, $80 | (260 >> 7) ; 3: 30,000,000
        db      269 & $7F, $80 | (269 >> 7) ; 4: 31,000,000
        db      278 & $7F, $80 | (278 >> 7) ; 5: 32,000,000
        db      286 & $7F, $80 | (286 >> 7) ; 6: 33,000,000
        db      234 & $7F, $80 | (234 >> 7) ; 7: 27,000,000, HDMI

; Selects the UART in A, ESP or PI, and its ring.
;     Dirties BC
select:
        ld      bc, UART_SELECT_P_153B
        out     (c), a
        ld      bc, BLINK.esp_ring
        or      a
        jr      z, .ring
        ld      bc, BLINK.pi_ring
.ring:
        ld      (BLINK.ring), bc
        ret

; Sends A to the selected UART, once its Tx buffer has room.
;     Dirties AF, BC, DE, HL
send:
        push    af
        ld      de, $0202                   ; Wait while bit 1, Tx full, is set
        call    wait
        pop     af
        out     (c), a                      ; BC = $133B
        ret

; Waits for a byte from the selected UART and returns it in A: the oldest in
; its ring, or else the next from its Rx buffer. The Rx interrupt may move
; bytes to the ring during the wait, so the ring is looked at again after.
;     Dirties AF, BC, DE, HL
receive:
        call    BLINK.ring_take
        ret     nc
        ld      de, $0100                   ; Wait until bit 0, a byte waiting, is set
        call    wait
        call    BLINK.ring_take
        ret     nc
        ld      bc, UART_RX_P_143B
        in      a, (c)
        ret

; Returns A = $FF if the selected UART has a byte waiting, in its ring or
; its Rx buffer, else 0.
;     Dirties AF, BC, HL
status:
        ld      hl, (BLINK.ring)
        call    BLINK.ring_empty
        jr      nz, .ready                  ; Bytes in the ring
        ld      bc, UART_TX_P_133B
        in      a, (c)
        and     %00000001                   ; A byte waiting?
        ret     z                           ; ...No
.ready:
        ld      a, $FF
        ret

; Returns A = $FF if the selected UART's Tx buffer has room, else 0.
;     Dirties AF, BC
tx_status:
        ld      bc, UART_TX_P_133B
        in      a, (c)
        cpl
        and     %00000010                   ; Tx not full?
        ret     z                           ; ...No
        ld      a, $FF
        ret

; Waits until the status of the selected UART, port $133B, XOR E AND D is
; not 0. Returns BC = $133B.
;     Dirties AF, BC, HL
wait:
        ld      bc, UART_TX_P_133B
        in      a, (c)
        xor     e
        and     d
        ret     nz                          ; Ready now
        ld      hl, BLINK.waiting
        ld      (hl), $FF
        ei                                  ; The cursor blinks while the UART is awaited
.poll:
        in      a, (c)
        xor     e
        and     d
        jr      z, .poll
        di
        ld      (hl), 0
        ret

    ENDMODULE

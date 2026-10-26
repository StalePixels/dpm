;-----------------------------------------------------------------------------
; TELNET.COM
;-----------------------------------------------------------------------------
; © D. 'Xalior' Rimron-Soutter, license: https://opensource.org/licenses/lgpl-3.0.html
;
; A telnet client on the Next's ESP WiFi module: TELNET host [port], port 23
; when there is none. It sends the ESP's AT commands, AT, AT+CIPSTART,
; AT+CIPMODE=1 and AT+CIPSEND, then passes bytes both ways: each byte from
; the ESP goes to the console through BIOS CONOUT, where DP/M's VT100
; terminal shows it, and each key goes to the ESP. CTRL-B leaves: "+++"
; between pauses of a second, then
; AT+CIPMODE=0 and AT+CIPCLOSE, and the warm boot back to the CCP.
;
; CP/M calls only, through the BIOS jump table at the address $0001 holds.
; The ESP is RDR: PTR: and PUN: PTP:. Status is BIOS CONST with CON: on
; BAT:, input BIOS CONIN with CON: on BAT:, output BIOS PUNCH: IOBYTE
; io_modem, the IOBYTE TELNET found with CON: BAT:, RDR: PTR: and PUN: PTP:.
; The console calls run under io_found, the IOBYTE as TELNET found it, and
; that is the IOBYTE TELNET leaves.
;
; Telnet commands are answered with a refusal (DO with WONT, WILL with DONT)
; and not shown. Every wait for the ESP counts frames with HALT, so none
; waits for ever. Assembled on its own into TELNET.COM, a CP/M transient at
; TPA_A.
;-----------------------------------------------------------------------------
    DEVICE zxspectrumnext
    OPT reset --zxnext --syntax=abfw

    INCLUDE "../../inc/addresses.asm"           ; TPA_A, REBOOT_A, IOBYTE_A, TBUFF_A

CR              EQU     13
BS              EQU     8
DEL             EQU     $7F
LF              EQU     10
LEAVE_KEY       EQU     2                       ; CTRL-B
IO_MODEM_BITS   EQU     %00010110               ; PUN: PTP:, RDR: PTR:, CON: BAT:

IAC             EQU     255                     ; Telnet commands (RFC 854)
DONT            EQU     254
DO              EQU     253
WONT            EQU     252
WILL            EQU     251
SB              EQU     250
SE              EQU     240

SECOND          EQU     50                      ; Frames
LINE_MAX        EQU     63                      ; Longest ESP reply line kept
HOST_MAX        EQU     63
PENDING_MAX     EQU     30

        ORG     TPA_A
telnet_start:
        ld      sp, stack_top
        ld      a, (IOBYTE_A)
        ld      (io_found), a
        and     %11000000                       ; LST: as found
        or      IO_MODEM_BITS
        ld      (io_modem), a
        ld      hl, (REBOOT_A+1)                ; The BIOS warm boot entry
        ld      de, 3
        add     hl, de
        ld      (bconst+1), hl
        add     hl, de
        ld      (bconin+1), hl
        add     hl, de
        ld      (bconout+1), hl
        add     hl, de                          ; LIST
        add     hl, de
        ld      (bpunch+1), hl

        call    parse_tail
        jr      nc, .parsed
        ld      hl, msg_usage
        call    print
        jp      done
.parsed:
        ld      hl, msg_trying
        call    print
        ld      hl, host
        call    print
        ld      hl, msg_port
        call    print
        ld      hl, port
        call    print
        ld      hl, msg_crlf
        call    print

        ld      a, (io_modem)
        ld      (IOBYTE_A), a
.stale:
        call    rx_poll                         ; Drop what the ESP sent before
        jr      c, .stale

        ld      hl, cmd_at
        call    command
        ld      hl, SECOND*2
        call    wait_ok
        or      a
        jr      z, .esp_ok
        ld      hl, msg_no_esp
        call    print
        jp      done
.esp_ok:
        ld      hl, cmd_start
        call    send
        ld      hl, host
        call    send
        ld      hl, cmd_start_port
        call    send
        ld      hl, port
        call    command
        ld      hl, SECOND*25
        call    wait_ok
        or      a
        jr      z, .connected
        call    say_failed
        ld      hl, SECOND/2
        call    drain                           ; The CLOSED after a refusal
        jp      done
.connected:
        ld      hl, cmd_mode1
        call    command
        ld      hl, SECOND*2
        call    wait_ok
        or      a
        jr      nz, .lost
        ld      hl, cmd_send
        call    command
        ld      a, 1
        ld      (want_prompt), a
        ld      hl, SECOND*2
        call    wait_ok
        or      a
        jr      z, terminal
.lost:
        call    say_failed
        call    close_link
        jp      done

;-----------------------------------------------------------------------------
; Passthrough: every byte from the ESP to the console, every key to the ESP.
; The keyboard is read when the ESP has nothing, and after every 256 bytes.
;-----------------------------------------------------------------------------
terminal:
        ld      hl, msg_connected
        call    print
        ld      a, 1
        ld      (passthrough), a
        ld      hl, pending                     ; Replies held before passthrough
        ld      a, (pending_len)
        or      a
        jr      z, .loop
        ld      b, a
.flush:
        ld      c, (hl)
        push    bc
        push    hl
        call    bpunch
        pop     hl
        pop     bc
        inc     hl
        djnz    .flush
.loop:
        call    bconst                          ; Under io_modem: the ESP
        or      a
        jr      z, .keys
        call    bconin
        ld      c, a
        ld      a, (iac_state)
        or      a
        jr      nz, .telnet
        ld      a, c
        inc     a                               ; IAC?
        jr      z, .telnet
        ld      a, (io_found)
        ld      (IOBYTE_A), a
        call    bconout
        ld      a, (io_modem)
        ld      (IOBYTE_A), a
        ld      hl, rx_count
        dec     (hl)
        jr      nz, .loop
.keys:
        ld      a, (io_found)
        ld      (IOBYTE_A), a
        call    bconst
        or      a
        jr      z, .no_key
        call    bconin
        ld      c, a
        ld      a, (io_modem)
        ld      (IOBYTE_A), a
        ld      a, c
        cp      LEAVE_KEY
        jr      z, leave
        cp      DEL
        jr      nz, .send
        ld      c, BS                           ; DELETE sends BS, which BBSes take as rub-out
.send:
        push    bc
        call    bpunch
        pop     bc
        ld      a, c
        cp      CR                              ; CR NUL, as RFC 854 has a bare CR
        jr      nz, .loop
        ld      c, 0
        call    bpunch
        jr      .loop
.no_key:
        ld      a, (io_modem)
        ld      (IOBYTE_A), a
        jr      .loop
.telnet:
        call    telnet_byte
        jr      .loop

leave:
        ld      a, 1
        ld      (leaving), a
        ld      hl, SECOND
        call    drain                           ; The guard time before +++
        ld      c, '+'
        call    bpunch
        ld      c, '+'
        call    bpunch
        ld      c, '+'
        call    bpunch
        ld      hl, SECOND+SECOND/10
        call    drain                           ; And after
        call    close_link
        ld      hl, msg_closed
        call    print
done:
        ld      a, (io_found)
        ld      (IOBYTE_A), a
        jp      REBOOT_A

; AT+CIPMODE=0, then AT+CIPCLOSE, each with its own wait.
close_link:
        ld      a, 1
        ld      (leaving), a
        xor     a
        ld      (want_prompt), a
        ld      hl, cmd_mode0
        call    command
        ld      hl, SECOND*2
        call    wait_ok
        ld      hl, cmd_close
        call    command
        ld      hl, SECOND*5
        call    wait_ok
        ld      a, (closed_seen)                ; CLOSED comes before the OK
        or      a
        ret     z
        ld      hl, SECOND
        jp      wait_ok

; Prints "Cannot connect: " and the ESP's last message, or ERROR or "no
; answer" when there is none.
say_failed:
        push    af
        ld      hl, msg_failed
        call    print
        pop     af
        ld      hl, msg_timeout
        cp      2
        jr      z, .print
        ld      hl, msg_buf
        ld      a, (hl)
        or      a
        jr      nz, .print
        ld      hl, msg_error
.print:
        call    print
        ld      hl, msg_crlf
        jp      print

;-----------------------------------------------------------------------------
; A byte from the remote end, in C: shown, or taken by the telnet command
; parser. iac_state: 0 data, 1 after IAC, 2 after IAC and a verb, 3 inside
; a subnegotiation, 4 after IAC inside one.
;-----------------------------------------------------------------------------
rx_byte:
        ld      a, (iac_state)
        or      a
        jr      nz, telnet_byte
        ld      a, c
        inc     a
        jr      z, telnet_byte
        jp      show

telnet_byte:
        ld      a, (iac_state)
        or      a
        jr      nz, .state1
        inc     a                               ; IAC
        ld      (iac_state), a
        ret
.state1:
        dec     a
        jr      nz, .state2
        ld      a, c
        cp      IAC                             ; IAC IAC is the byte 255
        jr      nz, .command
        xor     a
        ld      (iac_state), a
        jp      show
.command:
        ld      b, 3
        cp      SB
        jr      z, .set
        ld      b, 2
        cp      WILL
        jr      nc, .verb                       ; WILL, WONT, DO, DONT
        ld      b, 0
.set:
        ld      a, b
        ld      (iac_state), a
        ret
.verb:
        ld      (iac_verb), a
        jr      .set
.state2:
        dec     a
        jr      nz, .state3
        ld      (iac_state), a
        ld      a, (iac_verb)
        ld      b, DONT
        cp      WILL
        jr      z, .refuse
        ld      b, WONT
        cp      DO
        ret     nz                              ; WONT and DONT need no answer
.refuse:
        push    bc
        ld      a, IAC
        call    net_out
        pop     bc
        push    bc
        ld      a, b
        call    net_out
        pop     bc
        ld      a, c
        jr      net_out
.state3:
        dec     a
        jr      nz, .state4
        ld      a, c
        cp      IAC
        ret     nz
        ld      a, 4
        ld      (iac_state), a
        ret
.state4:
        ld      a, c
        cp      SE
        ld      a, 0
        jr      z, .end_sb
        ld      a, 3
.end_sb:
        ld      (iac_state), a
        ret

; A in the ESP's direction: sent in passthrough, held until then before it.
net_out:
        ld      c, a
        ld      a, (passthrough)
        or      a
        jp      nz, bpunch
        ld      a, (pending_len)
        cp      PENDING_MAX
        ret     nc
        ld      e, a
        inc     a
        ld      (pending_len), a
        ld      d, 0
        ld      hl, pending
        add     hl, de
        ld      (hl), c
        ret

; C to the console.
show:
        ld      a, (io_found)
        ld      (IOBYTE_A), a
        call    bconout
        ld      a, (io_modem)
        ld      (IOBYTE_A), a
        ret

;-----------------------------------------------------------------------------
; The ESP's replies
;-----------------------------------------------------------------------------
; Carry and the byte in A when the ESP has one, no carry when not.
rx_poll:
        call    bconst
        or      a
        ret     z
        call    bconin
        scf
        ret

; Reads the ESP's reply for HL frames. A = 0 for a line OK (or the '>'
; prompt when want_prompt is set), 1 for ERROR or CLOSED (closed_seen set),
; 2 when HL frames pass. Data in a +IPD before passthrough goes to rx_byte. The last other
; line that is not the command's echo is kept in msg_buf.
wait_ok:
        ld      (wait_frames), hl
        xor     a
        ld      (line_len), a
        ld      (msg_buf), a
        ld      (closed_seen), a
.loop:
        call    rx_poll
        jr      c, .byte
        halt
        ld      hl, (wait_frames)
        dec     hl
        ld      (wait_frames), hl
        ld      a, h
        or      l
        jr      nz, .loop
        ld      a, 2
        ret
.byte:
        call    reply_byte
        jr      nc, .loop
        ret

; Drops the ESP's bytes for HL frames.
drain:
        ld      (wait_frames), hl
.loop:
        call    rx_poll
        jr      c, .loop
        halt
        ld      hl, (wait_frames)
        dec     hl
        ld      (wait_frames), hl
        ld      a, h
        or      l
        jr      nz, .loop
        ret

; A byte of reply in A. Carry and the result in A when the reply is done.
reply_byte:
        ld      c, a
        ld      hl, (ipd_left)
        ld      a, h
        or      l
        jr      z, .text
        dec     hl
        ld      (ipd_left), hl
        ld      a, (leaving)
        or      a
        ret     nz
        call    rx_byte
        or      a                               ; No carry
        ret
.text:
        ld      a, c
        cp      CR
        ret     z                               ; No carry
        cp      LF
        jr      z, .line
        cp      '>'
        jr      nz, .store
        ld      a, (want_prompt)
        or      a
        jr      z, .store
        ld      a, (line_len)
        or      a
        jr      nz, .store
        scf                                     ; A = 0
        ret
.store:
        ld      a, (line_len)
        cp      LINE_MAX
        ret     nc                              ; Long lines are cut, no carry
        ld      e, a
        inc     a
        ld      (line_len), a
        ld      d, 0
        ld      hl, line_buf
        add     hl, de
        ld      (hl), c
        inc     hl
        ld      (hl), 0
        ld      a, c
        cp      ':'
        jr      z, .ipd
        or      a
        ret
.ipd:
        ld      hl, line_buf                    ; "+IPD,n:" starts n data bytes
        ld      de, txt_ipd
        call    starts_with
        ret     nz
        ld      hl, line_buf+5
        ld      de, 0
.digit:
        ld      a, (hl)
        sub     '0'
        cp      10
        jr      nc, .count
        push    hl
        ld      h, d
        ld      l, e
        add     hl, hl
        add     hl, hl
        add     hl, de
        add     hl, hl
        ld      e, a
        ld      d, 0
        add     hl, de
        ex      de, hl
        pop     hl
        inc     hl
        jr      .digit
.count:
        ld      (ipd_left), de
        xor     a
        ld      (line_len), a
        ret
.line:
        ld      a, (line_len)
        or      a
        ret     z                               ; An empty line, no carry
        xor     a
        ld      (line_len), a
        ld      de, txt_ok
        call    line_is
        jr      nz, .not_ok
        ld      a, (want_prompt)
        or      a
        ret     nz                              ; Waiting for '>' instead, no carry
        scf                                     ; A = 0
        ret
.not_ok:
        ld      de, txt_error
        call    line_is
        jr      z, .error
        ld      de, txt_closed
        call    line_is
        jr      z, .closed
        ld      hl, line_buf                    ; The command's echo
        ld      de, txt_at
        call    starts_with
        ret     z                               ; No carry
        ld      hl, line_buf                    ; Kept for the error message
        ld      de, msg_buf
        ld      bc, LINE_MAX+1
        ldir
        or      a
        ret
.closed:
        ld      a, 1
        ld      (closed_seen), a
        ld      hl, txt_closed
        ld      de, msg_buf
        ld      bc, 7
        ldir
.error:
        ld      a, 1
        scf
        ret

; Z when the line in line_buf is the zero-ended text at DE.
line_is:
        ld      hl, line_buf
.loop:
        ld      a, (de)
        cp      (hl)
        ret     nz
        or      a
        ret     z
        inc     hl
        inc     de
        jr      .loop

; Z when the text at HL starts with the zero-ended text at DE.
starts_with:
        ld      a, (de)
        or      a
        ret     z
        cp      (hl)
        ret     nz
        inc     hl
        inc     de
        jr      starts_with

;-----------------------------------------------------------------------------
; Output
;-----------------------------------------------------------------------------
; The zero-ended text at HL to the ESP, then CR LF.
command:
        call    send
        ld      hl, txt_crlf
; The zero-ended text at HL to the ESP.
send:
        ld      a, (hl)
        or      a
        ret     z
        ld      c, a
        push    hl
        call    bpunch
        pop     hl
        inc     hl
        jr      send

; The zero-ended text at HL to the console.
print:
        ld      a, (io_found)
        ld      (IOBYTE_A), a
.loop:
        ld      a, (hl)
        or      a
        jr      z, .end
        ld      c, a
        push    hl
        call    bconout
        pop     hl
        inc     hl
        jr      .loop
.end:
        ld      a, (io_modem)
        ld      (IOBYTE_A), a
        ret

;-----------------------------------------------------------------------------
; The command tail: host, then the port, 23 when there is none. Carry when
; it is not that.
;-----------------------------------------------------------------------------
parse_tail:
        ld      hl, TBUFF_A
        ld      c, (hl)                         ; Its length
        ld      b, 0
        inc     hl
        add     hl, bc
        ld      (hl), 0                         ; Zero-ended
        ld      hl, TBUFF_A+1
        call    skip_spaces
        ld      de, host
        ld      b, HOST_MAX
.host:
        ld      a, (hl)
        or      a
        jr      z, .host_end
        cp      ' '
        jr      z, .host_end
        cp      '"'
        jr      z, .bad
        ld      (de), a
        inc     hl
        inc     de
        djnz    .host
        jr      .bad
.host_end:
        xor     a
        ld      (de), a
        ld      a, (host)
        or      a
        jr      z, .bad                         ; No host
        call    skip_spaces
        ld      a, (hl)
        or      a
        ret     z                               ; port is "23", no carry
        ld      de, port
        ld      b, 5
.port:
        ld      a, (hl)
        sub     '0'
        cp      10
        jr      nc, .port_end
        ld      a, (hl)
        ld      (de), a
        inc     hl
        inc     de
        djnz    .port
.port_end:
        ld      a, b
        cp      5
        jr      z, .bad                         ; No digit
        xor     a
        ld      (de), a
        call    skip_spaces
        ld      a, (hl)
        or      a
        ret     z
.bad:
        scf
        ret

skip_spaces:
        ld      a, (hl)
        cp      ' '
        ret     nz
        inc     hl
        jr      skip_spaces

;-----------------------------------------------------------------------------
; The BIOS entries, filled in at the start
;-----------------------------------------------------------------------------
bconst:         jp      0
bconin:         jp      0
bconout:        jp      0
bpunch:         jp      0

;-----------------------------------------------------------------------------
; Text
;-----------------------------------------------------------------------------
cmd_at:         DB      "AT", 0
cmd_start:      DB      "AT+CIPSTART=\"TCP\",\"", 0
cmd_start_port: DB      "\",", 0
cmd_mode1:      DB      "AT+CIPMODE=1", 0
cmd_mode0:      DB      "AT+CIPMODE=0", 0
cmd_send:       DB      "AT+CIPSEND", 0
cmd_close:      DB      "AT+CIPCLOSE", 0
txt_crlf:
msg_crlf:       DB      CR, LF, 0
txt_ok:         DB      "OK", 0
txt_error:      DB      "ERROR", 0
txt_closed:     DB      "CLOSED", 0
txt_at:         DB      "AT", 0
txt_ipd:        DB      "+IPD,", 0
msg_usage:      DB      "Usage: TELNET host [port]", CR, LF
                DB      "The port is 23 when there is none. CTRL-B leaves.", CR, LF, 0
msg_trying:     DB      "Trying ", 0
msg_port:       DB      " port ", 0
msg_no_esp:     DB      "No answer from the ESP", CR, LF, 0
msg_failed:     DB      "Cannot connect: ", 0
msg_timeout:    DB      "no answer", 0
msg_error:      DB      "ERROR", 0
msg_connected:  DB      "Connected. CTRL-B leaves.", CR, LF, 0
msg_closed:     DB      CR, LF, "Connection closed", CR, LF, 0

;-----------------------------------------------------------------------------
; Data
;-----------------------------------------------------------------------------
io_found:       DB      0
io_modem:       DB      0
passthrough:    DB      0
leaving:        DB      0
want_prompt:    DB      0
closed_seen:    DB      0
iac_state:      DB      0
iac_verb:       DB      0
rx_count:       DB      0
pending_len:    DB      0
line_len:       DB      0
ipd_left:       DW      0
wait_frames:    DW      0
port:           DB      "23", 0, 0, 0, 0
telnet_end:

host            EQU     telnet_end
line_buf        EQU     host+HOST_MAX+1
msg_buf         EQU     line_buf+LINE_MAX+2
pending         EQU     msg_buf+LINE_MAX+2
stack_top       EQU     pending+PENDING_MAX+128

        SAVEBIN "../../../build/TELNET.COM",telnet_start,telnet_end-telnet_start

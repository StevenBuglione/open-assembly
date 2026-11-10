# Linux x86-64 terminal attributes

Status: proposed, scoped to six Phase 10 interfaces.

The initial terminal ABI implements `tcgetattr`, `tcsetattr`,
`cfgetispeed`, `cfgetospeed`, `cfsetispeed`, and `cfsetospeed`. The
generated declaration uses a 36-byte, four-byte-aligned `struct termios`.
The four 32-bit unsigned mode fields occupy offsets 0, 4, 8 and 12.
The one-byte line discipline is at 16. The 19 control bytes start at
17. The Linux x86-64 terminal ioctl record uses this exact layout.
Applications must compile against the project header for this ABI.
[Linux termbits](https://raw.githubusercontent.com/torvalds/linux/master/include/uapi/asm-generic/termbits.h) · [POSIX termios header](https://man7.org/linux/man-pages/man0/termios.h.0p.html)

`tcgetattr` reads through `TCGETS`. `tcsetattr` maps `TCSANOW`,
`TCSADRAIN`, and `TCSAFLUSH` to `TCSETS`, `TCSETSW`, and `TCSETSF`.
An unknown action returns `EINVAL` before any ioctl. Valid actions
preserve errno on success and translate kernel errors. The kernel
determines which requested terminal attributes it can apply.
[Linux terminal attribute ioctls](https://man7.org/linux/man-pages/man2/TCSETS.2const.html)

Baud rates use Linux `CBAUD` and `CIBAUD` fields in `c_cflag`.
The input getter reports the effective encoded input rate. When the
input field is zero it reports the output rate. An input setter value
of `B0` selects that tracking behavior. For output, `B0` is the
hangup rate. The setters accept named rates from `B0` through
`B4000000`, preserve all unrelated flag bits, and leave the record
unchanged with `EINVAL` for unsupported codes. Arbitrary speeds through
the separate Linux `termios2` ABI are a later scope.
[Linux line speed interfaces](https://man7.org/linux/man-pages/man3/termios.3.html)

Verification includes real PTY attribute changes read back through
raw Linux ioctls, restoration through all three actions, nonterminal
and invalid-descriptor errors, and independent speed fields. Line
control and terminal process-group interfaces have separate scopes.

# Linux x86-64 terminal line controls

Status: proposed, scoped to five additional Phase 10 interfaces.

`tcdrain` uses `TCSBRK` with a nonzero argument to wait for output without
requesting a break. `tcflow` maps the four POSIX action values to
`TCXONC`. `tcflush` maps the three POSIX queue selectors to `TCFLSH`.
An unknown action or selector returns `EINVAL` before issuing an ioctl.
[Linux terminal ioctl constants](https://raw.githubusercontent.com/torvalds/linux/master/include/uapi/asm-generic/ioctls.h) · [Linux break and drain handling](https://man7.org/linux/man-pages/man2/TCSBRK.2const.html)

`tcsendbreak` requests the Linux default 250 ms for a nonpositive
duration. A positive duration uses `TCSBRKP` in deciseconds, capped
at `INT_MAX / 100` so the kernel's signed millisecond count remains
representable. A PTY exercises the ioctl route and return contract.
Physical break duration depends on the serial driver and needs
hardware-specific evidence. [Linux tty ioctl implementation](https://raw.githubusercontent.com/torvalds/linux/master/drivers/tty/tty_io.c)

`tcgetsid` reads a four-byte session ID through `TIOCGSID`. The Linux
kernel checks the terminal's session relationship with the caller.
Use an isolated session leader with an owned PTY for positive
verification. [Linux tcgetsid](https://man7.org/linux/man-pages/man3/tcgetsid.3.html)

All five interfaces preserve errno on success and translate Linux
errors. Validate the exact ioctl arguments and signed descriptors
through the private syscall boundary, with separate real PTY and
nonterminal controls. Thread cancellation and foreground
process-group APIs retain their own scopes.

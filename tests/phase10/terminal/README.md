# Independent Linux terminal checks

Run `./tools/container make phase10-terminal`. The gate covers eleven POSIX
termios interfaces under Linux, QEMU and strict Memcheck. Hosted semantic
cases also run against pinned glibc and musl. The host comparisons use
public rate values and independent kernel readback. A project-only case
checks the 36-byte kernel record and exact CBAUD/CIBAUD layout.

The live cases create a fresh PTY, toggle and restore echo through each
attribute action, and use a forked session leader to acquire a controlling
terminal and verify its session ID. Nonterminal and closed-descriptor
cases exercise Linux errors. An isolated syscall wrapper checks requests,
signed descriptors, rate-independent action mapping, break duration
saturation and validation before ioctl. Physical serial break timing is
outside this PTY scope.

The direct SysV probe exercises all eleven interfaces and poisons unused
upper argument bits. The calibrated no-op probe explains the explicit
Memcheck omission for that machine-state case. Semantic cases retain all
three backends. Every public function has a generated-stub rejection.

[POSIX termios](https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/termios.h.html)
[Linux termbits](https://github.com/torvalds/linux/blob/v6.12/include/uapi/asm-generic/termbits.h)
[Linux ioctl constants](https://github.com/torvalds/linux/blob/v6.12/include/uapi/asm-generic/ioctls.h)

# Independent variadic descriptor control

The fixture checks the Linux AMD64 flock and typed owner layouts.
Descriptor flags are local to a descriptor, while nonblocking status
follows its open file description. Duplication with and without
close-on-exec, pipe capacity, and Linux error returns exercise the
no-argument and promoted-int command forms.

Two processes lock adjacent byte ranges beyond the 32-bit offset
boundary. The query observes the other process's PID and the full
range. The OFD case compares independent opens with a duplicate,
checks the kernel's OFD owner marker, and observes removal of the
lock on the last close.

The owner fixture establishes a process group with ID greater than
one and verifies the successful negative result and preserved errno.
The separate pinned PID-namespace case exercises PGID 1, for which
the project returns EOVERFLOW on the reserved -1 result. The typed
owner query still reports the group. The pinned host wrappers preserve
errno for that sentinel and are compared on the remaining owner case.

The zero-return stub fails the direct bad-descriptor oracle. Unknown
command rejection before fd validation is a separate project check.

[Descriptor control contract](../../../docs/adr/0007-linux-files-process-signal-time.md) ·
[Linux lock commands](https://man7.org/linux/man-pages/man2/fcntl_locking.2.html) ·
[Linux owner commands](https://man7.org/linux/man-pages/man2/F_GETOWN.2const.html)

The per-function gate runs with `./tools/container tools/gate fcntl`.
It adds a variadic ABI trampoline, a direct dispatch probe for every
documented command and adjacent command numbers, source-mapped QEMU
conditional edges, real NASM mutations and a 60-second differential
against pinned glibc and musl. The packet driver varies flag mutations,
duplication minima, descriptor failures, 64-bit lock ranges and pipe
sizes. The directed tests separately check successful negative group
owners and the reserved error result. The production report binds its
runtime, candidate, fixture, tools and current input hashes.

Native and QEMU inspect the ABI trampoline's x87 and MXCSR control
settings. The shared no-op calibration reports differences on Memcheck,
so the manifest scopes that trampoline to the first two backends.
Memcheck still runs the semantic and descriptor state cases.

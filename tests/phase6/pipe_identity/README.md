# Independent pipe descriptor fixtures

The shared packet cases use the Linux file and process contracts.
They preserve the original Phase 6 pipe, pipe2, exhaustion and
typed-stub fixtures. The direct pipe2 ABI call poisons the high
half of the flags register and checks the captured signed result,
descriptor canaries, both endpoints and preserved register state.

Each 16-byte little-endian input selects flags, one of two guard
edges, and up to eight data bytes. Each 64-byte response records
the exact signed result, errno, output canary and descriptor-slot
witness bits, endpoint ordering and shared FIFO identity, descriptor
flags, and the observed byte count, data, and final EOF result.
Numeric descriptors are normalized through kernel observations.
The packet stream can select a wholly protected output record.
Before a failure it identifies the lowest available descriptor
slots independently and checks that they remain unused.

The same C source runs against the candidate and pinned glibc and
musl. The fixed rows exercise the supported flags and invalid
pipe2 flags. The direct SysV state probe runs on native and QEMU.
Its nondefault x87 control value exceeds Memcheck emulation.

The protected-output rows are compared on native Linux with both
pinned hosted libraries. In a separate raw-syscall diagnostic,
QEMU returned EFAULT and left both descriptor slots open.
Native Linux returned EFAULT with both slots still unused.
Memcheck reported the never-readable mapping in that raw
diagnostic. The packet fixture initializes its output before
protecting it for the call. Memcheck produced the native result
for that packet shape. QEMU packet samples use readable guards.

# Independent allocator function fixtures

The public checks follow
[ADR 0004](../../docs/adr/0004-allocator-environment.md), C17 §7.22.3
and the POSIX allocation contracts. They write valid payload bytes,
keep neighboring allocations live, check zero initialization after
recycling and verify preserved prefixes after resize. The ordinary
project cases cover zero requests, size arithmetic overflow and
project alignment and errno requirements.

The mapping witness acts only while armed for the named allocation.
It injects ENOMEM only for the selected anonymous read/write map
size interval. The release case observes a real mapping and its
matching successful unmap. An unaffected later allocation or the
portable byte checks alone would not establish direct-map release.
This scope is separate from the inherited randomized Phase 3 suite
and the forced-remap checks in
[ADR 0036](../../docs/adr/0036-direct-allocation-remap.md).

The timed differential fixture uses 32-byte little-endian input
records and 64-byte results. It normalizes process addresses to
alignment and disjointness flags, digests requested bytes and checks
retention of other live objects. It compares nonzero ordinary and
exhaustion cases across the candidate, pinned glibc and pinned musl.
Project-specific zero-size and small-alignment policies remain
direct assertions. Successful pointer-allocation errno is normalized
for the hosted implementations and independently checked for the
candidate. POSIX returned errors and preserved output are encoded
directly. On an oversized posix_memalign request both pinned hosts
set errno to ENOMEM and leave the output pointer intact. The shared
comparison uses the direct returned error and output preservation.
The candidate still checks the published errno preservation contract.
Free's shared packet checks errno and survival of other live
objects. Its direct release witness is a separate oracle.

The shared SysV probe tests preserved state on native and QEMU.
Its nondefault x87 control value exceeds Memcheck emulation.
Ordinary, packet and raw-boundary cases still run under Memcheck.

# Independent allocator closure witnesses

The cases follow the slab policy in
[ADR 0004](../../docs/adr/0004-allocator-environment.md)
and direct growth in
[ADR 0036](../../docs/adr/0036-direct-allocation-remap.md).
The wrapper observes the published x86-64 Linux syscall boundary.
It stays idle outside the named operation and uses real kernel
results except for the two explicitly injected error cases.

The cold-slab case injects ENOMEM for a read/write anonymous
private 64 KiB map while other allocations remain live. A retry
must map and provide a usable new slab with both prior payloads
intact. The arithmetic case checks the maximum supported
power-of-two alignment with PTRDIFF_MAX size. Both public
alignment APIs must reject the wrapping total without a map.

The list case fills four equal-class slabs with separately
patterned payloads. A single recycled slot is the only available
space across those slabs. Reuse must preserve all other payloads.
The case empties the slabs in a different order and observes real
unmaps as the number of unused slabs exceeds the one-spare limit.
It determines the slab grouping from returned address ranges and
observed mappings.

The native in-place case reserves its own PROT_NONE interval.
It gives the named initial allocation an address in that interval
with MAP_FIXED, releases the unused suffix, and observes the real
kernel remap. The same-address result, preserved payload prefix
and final unmap are all required. The boundary case supplies the
highest raw Linux error number, 4095, as a negative syscall result.
It observes a real fallback mapping, release of the original and
retained payload. These witnesses do not read private allocator
headers. Their scope is separate from the public wrapper gates.

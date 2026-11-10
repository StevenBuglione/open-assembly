# 0036 Direct allocation growth

## Contract

`realloc` grows an existing direct anonymous allocation with Linux x86-64
`mremap` when the requested size exceeds that allocation's usable capacity.
The allocator holds its existing heap lock and validates the live allocation
before requesting `MREMAP_MAYMOVE`. A successful remap preserves all bytes of
the old requested payload. The replacement owns the resulting mapping, can
be resized or freed, and retains at least the ordinary 16-byte alignment
promised by `realloc`. Growth may move the allocation even when the old
address was over-aligned. Successful growth preserves the caller's `errno`.

If the remap is unsupported or fails, the allocator tries its existing
allocate-copy-release path. If both attempts fail, `realloc` returns `NULL`
with `ENOMEM` and the old allocation, contents, and ownership remain valid.
Sizes outside the project's `PTRDIFF_MAX` limit fail without issuing a remap.
Slab allocations, in-capacity resizes, and the existing null and zero-size
cases retain their established allocation paths.

## Linux boundary

The private syscall boundary issues x86-64 syscall 25 with the recorded
anonymous mapping base and length, the payload offset plus the requested
size, `MREMAP_MAYMOVE` (1), and zero unused arguments. Linux rounds the
lengths to pages. The allocator checks the size calculation before calling
Linux. On success it rebinds the integrity metadata to the returned mapping
before releasing the heap lock. On raw syscall failure the original metadata
is unchanged.

The upstream interface is documented by [Linux man-pages](https://man7.org/linux/man-pages/man2/mremap.2.html).
The optimization covers direct allocation growth. The general allocator v2
workload and musl benchmark acceptance remain separate.

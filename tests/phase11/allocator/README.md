# Independent direct allocation growth

Run `./tools/container make phase11-allocator`. The C17 comparison
exercises payload preservation and the live allocation after a failed
resize on native Linux, QEMU, Memcheck, pinned glibc and pinned musl.

The project-specific fixture observes exact mapping base, length, requested
payload offset, flags and raw syscall return. It checks real remap growth,
over-aligned allocation growth, reuse after success and free of the final
mapping. A separate native case reserves the next mapped page or observes
an existing neighbor and requires the kernel to move the allocation.

The fault cases arm only the matching remap and fallback anonymous map.
They test ENOSYS fallback and complete failure with original ownership and
bytes intact. Slab and in-capacity resizes must avoid remap, and overflow
must fail before any mapping operation. The generated realloc stub is
rejected by the live direct-growth case.

[C17 realloc, section 7.22.3.5](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)
[Linux mremap](https://man7.org/linux/man-pages/man2/mremap.2.html)

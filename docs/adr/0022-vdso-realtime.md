# Bounded x86-64 vDSO lookup for realtime seconds

Status: proposed, scoped to the initial Phase 11 clock slice.

On x86-64 Linux, the runtime may obtain realtime seconds for `time` from
`__vdso_clock_gettime@LINUX_2.6`. It passes `CLOCK_REALTIME` and a
writable, runtime-owned Linux time64 record. A missing entry or nonzero
vDSO result falls back to the existing raw clock query. The raw public
`clock_gettime` path retains the kernel's `EFAULT` handling for
inaccessible application output pointers. Other clock APIs keep their
existing dispatch in this slice. [Linux vDSO ABI](https://man7.org/linux/man-pages/man7/vdso.7.html) · [Linux clock_gettime](https://man7.org/linux/man-pages/man2/clock_gettime.2.html)

Use the original auxiliary vector from static startup. Scan up to 128
entries for `AT_SYSINFO_EHDR` and stop at `AT_NULL`. An image base must
be nonzero, page-aligned, and allow a 16 KiB address window without
overflow. Read a prefix through the raw self `process_vm_readv` boundary,
with separate 4 KiB remote vectors. Validate only bytes actually read.
Missing auxiliary data, a short unreadable image, seccomp denial,
unsupported syscalls, and unsupported images use the raw clock path.
The copy is used for metadata only. The callable address belongs to the
original kernel mapping. [Linux process_vm_readv](https://man7.org/linux/man-pages/man2/process_vm_readv.2.html)

The private parser `__al_vdso_lookup(const void *image, size_t bytes)`
returns the entry's nonzero byte offset, or zero on rejection. The caller
supplies a readable range and at most 16 KiB. Require a little-endian
ELF64 x86-64 shared image, one bounded readable executable load segment
with base offset and virtual address zero, and one file-backed dynamic
segment. Bound dynamic records, hash metadata, strings, symbols,
version indices, and version definitions inside the load segment and
the actual readable prefix. Resolve the exact NUL-terminated symbol and
version names and require a defined ordinary function wholly within the
executable load. Reject unsupported layouts, including GNU-hash-only
images in this initial slice. [ELF program headers](https://gabi.xinuos.com/elf/07-pheader.html) · [ELF dynamic records](https://gabi.xinuos.com/elf/08-dynamic.html)

The first caller to claim the cache resolves and publishes the entry.
A concurrent or signal-interrupted caller takes the raw fallback while
the cache is busy. An unsupported result remains cached until process
exit. A fork child that inherits a busy cache takes the raw fallback for
the rest of its lifetime. Neither path acquires a lock or modifies errno
on success. The private `__al_vdso_clock_entry(void)` returns the cached
callable address, or null on fallback.

Verification must distinguish native vDSO use from a successful raw
query. Cover missing and unreadable auxiliary image addresses, malformed
or unsupported ELF metadata, signal reentry while resolving, and direct
fallback error handling. Keep evidence for QEMU and Memcheck scoped to
the facilities available in each backend. Static PIE, other accelerated
clock APIs, and Phase 11 performance acceptance have separate gates.

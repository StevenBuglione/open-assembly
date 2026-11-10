# Phase 3 allocator and environment contract

## Allocator

Implement the C17 malloc, free, calloc, realloc and aligned_alloc interfaces and
the POSIX posix_memalign interface as wrappers around one private allocator.
Memory comes from anonymous read/write mappings through the existing raw syscall
boundary. Keep that boundary and the TLS errno offset unchanged. Cite C17
§7.22.3 and POSIX.1-2024 for the corresponding functions.

All successful allocations have at least 16-byte alignment, including the
allocation used to represent a zero-size request. A zero-size request may
return a freeable pointer, with zero accessible bytes under the API contract.
On exhaustion, including size arithmetic overflow, the pointer-returning
interfaces return NULL and set ENOMEM. Success preserves errno. free(NULL) is
a no-op and valid calls to free preserve errno. The expected maximum object
size is PTRDIFF_MAX. Check requested size, alignment slack, headers, mapping
length, and calloc multiplication before performing any memory operations.

| Interface | Contract |
| --- | --- |
| malloc | Allocate the requested byte count and leave the contents unspecified. |
| calloc | Check the product before allocating. Zero the requested bytes even when a slab slot is reused. A zero factor is a zero-size request. |
| realloc | A null pointer is handled as malloc. Preserve the minimum of the old requested size and the new size. Failure leaves the original allocation and contents intact. A successful zero-size request returns a freeable pointer and releases the original allocation. |
| aligned_alloc | Accept supported nonzero powers of two. Raise the effective alignment to at least 16. Accept sizes that are not multiples of alignment under the C17 revision of §7.22.3.1. Return NULL with EINVAL for unsupported alignment. |
| posix_memalign | Require a power of two and a multiple of sizeof(void *). Return EINVAL or ENOMEM directly and leave the output pointer and errno unchanged on failure. Write the new pointer and return zero on success. |

C17 delegates details of zero-size allocation. The freeable result and preservation on realloc failure define the
project contract. Differential tests should assert the project contract separately
where glibc handles zero-size realloc differently. realloc promises the
default alignment of the new object. Retaining extra alignment in place is
allowed and preserving it across moves can be considered separately.

Use one process-wide allocator lock word and the existing acquire/release
hooks. Each public entry reaches a single lock scope around metadata access.
An internal allocation or deallocation operation called by realloc assumes
that scope is already held. The lock implementation is still a no-op until
threads exist. Use raw mmap and munmap results internally. Apply errno
translation at the public boundary, after unlocking. Never take an
environment lock from an allocator path.

### Layout and invariants

- Start with 64 KiB slabs and fixed aligned strides including a 32-byte
  allocation header. Candidate strides are 48, 64, 80, 96, 128, 160, 192,
  256, 384, 512, 768, 1024, 1536, 2048, 3072 and 4096 bytes. They can be
  tuned after measuring size distributions without changing the public ABI.
- Each size class has a list of slabs with capacity for another allocation.
  A slab records its stride/class, aligned slot area, free-list head, unused
  slot frontier, live count and links. Take a validated free slot before
  advancing the frontier. Move a slab off the available list when full and
  put it back when a slot becomes free. Retain at most one empty slab per
  class and release excess empty slabs after removing them from the list.
- Small default-aligned requests use the first stride whose payload fits.
  Larger and over-aligned requests get a direct mapping with checked room
  for the header and alignment slack. Round the user address up within the
  mapping. Store the original mapping address and length in the header for
  munmap. Passing the same length to munmap avoids separate page arithmetic.
- The four-word header records the slab/mapping address and allocation
  state, requested size, auxiliary metadata, and an integrity tag. The
  per-process seed can use the initial thread's existing pointer guard.
  Store that seed once before allocation starts so a future thread does
  not need the same FS guard to free an allocation made elsewhere. Make
  the tag cover the payload address and header fields. Validate the tag
  before following the metadata pointer. Validate slab class, range, slot
  alignment, live state and fit before recycling a slot.
- reallocate in place only when the current payload capacity is sufficient.
  For moves, allocate the new object first, copy the requested prefix, and
  free the old one under the same lock. A failed allocation makes no edits
  to the old header or its storage.
- free and realloc accept only a live pointer returned by this allocator.
  A tag or invariant failure after reaching readable metadata can call the
  existing fatal diagnostic. An arbitrary bad pointer or a second free of
  an unmapped direct allocation is outside the C contract and may fault.
  The integrity check helps diagnose corruption and does not provide a
  security boundary against an attacker with arbitrary memory access.

The slot header contains the tagged owner at byte 0, requested size at
byte 8, the auxiliary word at byte 16, and the integrity tag at byte 24.
The owner low bits distinguish live slabs, direct mappings, and free slab
slots. The auxiliary word holds the direct mapping length or the next
recycled slot. The slab header occupies the first 64 bytes of its mapping.
Its eight words hold the next available slab, address of the previous list
link, address of the class head, stride, frontier, live count, recycled
slot head, and end of the mapping. A zero previous link denotes a full
slab. The allocator core owns both layouts and the environment subsystem
uses only the public allocation interface.

## Environment

Expose the POSIX char **environ object. Keep the existing main arguments
and private __al_initial_envp and __al_auxv snapshots. Startup can
initialize environ to a shallow copy of the initial pointer vector using a
private anonymous mapping. This keeps the original NULL terminator and
auxiliary vector adjacency intact even after an unset. For an empty
environment a private one-element NULL vector is sufficient. The mapping
can live for the process lifetime. An early allocation failure uses the
current panic path before calling main. This adds an explicit startup
dependency and a narrowly modeled data export. It changes no existing
startup arguments, auxiliary vector, or TLS offsets.

Use one environment lock word and only acquire allocator locks underneath
it. Lookup returns borrowed pointers into environment strings. The caller
must finish using the borrowed pointer before a mutation that can remove
that string. The initial pointer array and strings belong to the process
stack, application arrays and putenv strings remain application-owned,
and only memory recorded as library-owned is deallocated.

- getenv accepts a nonempty name without an equals sign. Return the value
  after the equals sign of the first matching entry, or NULL for absent
  or invalid names. Match names exactly and case-sensitively. Preserve
  errno. Skip malformed entries in a caller-supplied environment vector.
- setenv validates the name and copies the bytes of both name and value
  into one library allocation. A zero overwrite argument leaves an
  existing value alone. Otherwise replace the first matching value or
  append a new entry. Never publish partially constructed data. On invalid
  name return -1 with EINVAL. On allocation or arithmetic failure return
  -1 with ENOMEM and preserve the entire active environment.
- unsetenv validates the name, removes every matching entry and succeeds
  if the name was absent. Compact the active writable array in place and
  keep its terminating NULL. This avoids an allocation on valid removal.
  Return -1 and EINVAL for an invalid name.
- putenv installs the actual caller-provided name=value pointer. Later
  caller edits to the name or value must be visible to lookup. Require a
  nonempty name. Treat a nonempty string without an equals sign as
  removal, subject to verification against the pinned musl and current
  POSIX contract. Never free the supplied string. A failure to grow the
  vector must leave the environment unchanged.

Read the active environ pointer on each call because a program can assign
a valid replacement array. Distinguish replacement of environ itself from
direct edits to its entries, which POSIX leaves undefined. Treat caller
arrays as borrowed. Copy them into a managed vector when adding an entry.
Track managed vector capacity and owned name=value strings independently.
Free an owned string only when no active slot points within its storage.
This also handles an application replacement array that references part of
an existing environment string. If environ points at a suffix of a
managed vector, keep its backing allocation until another vector is
published. Copy a name or value that aliases an existing owned string
before freeing that string.

## Verification and checkpoint

The independent allocator suite should generate operation sequences from
a small live-object model. Check distinct live storage, requested alignment,
zero initialization, retained prefixes after realloc, and valid writes at
the first and last requested bytes. Exercise zero sizes, a sample around
each size class boundary, over-aligned small and large requests,
multiplication and addition overflow, and deterministic failed mapping
with a resource limit or controlled syscall failure. Keep ordinary
allocation tests on native Linux, QEMU and Valgrind. Use the model and
sentinels for slab bounds because the entire anonymous mapping is otherwise
addressable to Valgrind. Record raw fault evidence and require the relevant
generated stubs to fail.

The environment tests should cover the initial vector and its unchanged
auxv adjacency, key prefixes, empty values, overwrite and deletion,
modified putenv strings, application-supplied environ arrays, replacing
a value using one of its existing substrings, exhaustion without partial
publication, and repeated churn without retaining obsolete allocations.
Differential checks compare specified effects and pointer ownership. Record first-pass
rates, integration rework, and measured verification cost for the roadmap
go/no-go checkpoint.

References

- [WG14 C17 baseline with later edits marked](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)
- [WG14 issue 460 and its final resolution](https://www.open-std.org/jtc1/sc22/wg14/issues/c11c17/log.html#issue0460)
- [POSIX posix_memalign](https://pubs.opengroup.org/onlinepubs/9799919799/functions/posix_memalign.html)
- [POSIX environment inheritance and environ replacement](https://pubs.opengroup.org/onlinepubs/9799919799/functions/exec.html)
- [POSIX setenv](https://pubs.opengroup.org/onlinepubs/9799919799/functions/setenv.html)

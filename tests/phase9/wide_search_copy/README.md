# Wide-element search and copy verification

The original wide manifest supplies the directed cases and generated
zero-stub controls. These supplemental cases add direct typed SysV
calls that capture the full returned pointer. Both search probes
poison the upper half of the signed wchar_t argument register. Copy
probes check the returned destination and unchanged source, including
a zero bound and padding after an early terminator.
[AMD64 System V ABI](https://gitlab.com/x86-psABIs/x86-64-ABI)

Search cases compare the exact returned address before computing an
offset. They exercise repeated matches, a missing element with the
same low 16 bits, and matches on both sides of the terminating null.
The fixtures use raw signed 32-bit wchar_t elements, including
WCHAR_MIN, WCHAR_MAX, and -1. The locale does not change the element
comparison or copy.
[Project wide-element contract](../../../docs/adr/0012-c-utf8-multibyte.md) ·
[WG14 wide search and copy clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

Each nonempty source or destination is placed at either edge of a
readable page bounded by inaccessible pages. The adjacent readable
element is a canary. The model checks all source and destination
elements and both accessible canaries. The unbounded copy writes
through the terminator. The bounded copy includes a source with n
readable nonzero elements, a short source ending at the guard page,
and an n=0 call with both addresses in protected pages. Copy ranges
are disjoint throughout.

The input packet is two little-endian uint64 words. The low 62 bits of
the first word select the scenario modulo the operation's scenario
count. The top bits choose the source and destination edge. The
second word seeds the raw elements, lengths, and errno sentinel.
The 64-byte output contains the signed result, then unsigned words
for scenario, source units, destination units, bound, needle bits,
element digest, and observed errno. Search offsets use -1 for absence.
Copy emits zero after verifying the exact returned destination.

ABI statuses 11–13 identify machine state, result or errno, and
object mismatch. Guard and packet statuses 21–23 identify returned
pointer, errno, and object or canary mismatch. The 90s identify
fixture setup or I/O errors. The same guard and packet code builds
against the candidate and both pinned hosted libraries.

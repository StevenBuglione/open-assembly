# Wide matching verification

The original wide manifest supplies directed cases and generated zero
stubs. These additions capture full size_t and pointer results through
the shared SysV trampoline and verify the input arrays remain unchanged.
The fixtures use complete signed 32-bit wchar_t values. Membership and
substring comparisons use element equality, including negative values
and values that share low 16 bits.
[AMD64 System V ABI](https://gitlab.com/x86-psABIs/x86-64-ABI) ·
[Project wide-element contract](../../../docs/adr/0012-c-utf8-multibyte.md)

The independent model first finds each terminating NUL within the
declared readable array. Its membership loop checks individual elements
of the set. The substring loop tries candidate positions in order and
compares each needle element. Volatile model reads and assignment
stores prevent replacement by library operations. The replay also checks
the compiled packet object's undefined symbols.
[WG14 wide search clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

Each string is placed independently at either end of a readable page
with inaccessible pages on both sides. Each adjacent readable element
is a canary. An empty string has one readable NUL element. Cases include
empty sets and needles, all or no members, a partial accepted prefix,
matches at the final element, duplicate members, and multiple matches.
Accessible data after an early NUL must have no effect on the result,
and the entire declared array remains unchanged.

Substring cases include longer needles, repeated-prefix failures, a
match at the final legal position, overlapping occurrences, empty needles
with accessible tails, and full-width distinctions. Seeded cases vary
both strings up to 128 elements and include forced and natural matches.
Exact pointer equality is checked before emitting a first-match offset.

Each input packet is two little-endian uint64 words. The first selects
a scenario using its low 62 bits and the two guard placements using its
high bits. The second seeds values, lengths, and errno. The 64-byte output
contains the signed result, then unsigned scenario, readable text units,
readable pattern units, logical text length, logical pattern length,
array digest, and observed errno. Spans emit their complete count.
Pointer results emit an offset or -1 for absence.

The same packet fixture builds against the candidate, pinned glibc, and
pinned musl. ABI statuses 11–13 identify machine state, result or errno,
and source modification. Semantic statuses 21–23 identify result or
pointer, errno, and array or canary mismatch. The 90s identify fixture
setup or packet I/O errors.

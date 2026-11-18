# Wide concatenation and collation fixtures

The original wide manifest supplies directed tests and generated zero
stubs for wcscat, wcsncat, wcscoll, and wcsxfrm. These additions capture
the full returned pointer or size_t, and only the permitted comparison
sign, through the shared SysV trampoline.
[AMD64 System V ABI](https://gitlab.com/x86-psABIs/x86-64-ABI)

Both supported locales use signed full-width element order and identity
collation keys under the project contract. Each timed row explicitly
sets locale C or C.UTF-8. The independent model scans bounded owned
arrays, selects the first unequal element, and constructs expected
concatenation or transform output with volatile stores. It calls no
wcslen, wcscmp, wmemcpy, or memory helper.
[Wide-element locale contract](../../../docs/adr/0012-c-utf8-multibyte.md) ·
[WG14 wide concatenation and collation clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

Source and destination arrays are independently placed at either end
of readable pages bounded by inaccessible pages. The readable neighbor
is a canary. Concatenation destinations contain a valid initial string
and enough room for the result. Bounded cases include an exactly
readable nonterminated source and n=0 with a protected source pointer.
All arrays are disjoint. Appended text must end with one NUL, and every
other destination element and every source element must be retained.

Transform size queries use n=0 with NULL or a protected nonnull output.
Complete keys include their NUL. SIZE_MAX cases have real small output
objects large enough for the complete key. Extra accessible destination
elements must retain their sentinels. The project-only short-key guard
checks that insufficient destinations remain untouched in both locales.

Pinned glibc and musl agree on the measured collation signs, including
signed extrema. Their short transform buffers differ from the project
no-store policy. For a two-element key and n=1 or n=2, glibc writes
an unterminated prefix while musl writes a NUL-terminated prefix. The
policies program preserves the actual output words and return values
for both locales. Common timers use size queries and fitting keys.

Each input is two little-endian uint64 words. The first selects the
scenario using its low 62 bits and independent source/destination page
edges using the high bits. The second seeds values, lengths, bounds,
and errno. Its high bit selects C.UTF-8. The 64-byte result records the
signed normalized result, scenario, source units, destination units,
bound, locale flag, full-array digest, and observed errno. Comparison
uses its sign. Pointer returns emit zero after exact-address equality.
Transform returns its full key length.

ABI statuses 11–13 identify machine state, result or errno, and object
mismatch. Semantic statuses 21–23 identify result or pointer, errno,
and input/output or canary mismatch. The 90s identify fixture setup,
packet I/O, model invariants, or mapping cleanup failures.

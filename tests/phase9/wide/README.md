# Wide string and memory fixtures

All 21 operations run with exact objects against guard pages at both
ends and 512 deterministic independent model samples per case. The
manifest also runs the collation operations in the project's C.UTF-8
locale. The test uses an xorshift32 generator seeded with 0x613c95ab.
The model compares only signs and compares mutation results element by
element. It tracks tokenizer offsets, terminators and skipped delimiters.

The directed checks cover signed 32-bit extrema, a full-width element
with zero low byte, matches at the terminator, prefix lengths, a bounded
input without a terminator, padding, overlap in both directions, guard
neighbors, zero elements, and very large valid bounds on short input.
The xfrm fixture checks identity when the complete key fits and the
project's short-buffer policy. Candidate calls preserve errno.

Pinned glibc and musl compare the shared C-locale behavior. The C.UTF-8
ordering and transform checks use the project's published identity
collation policy. Each public symbol has a direct zero-return stub
control checked before the seeded samples.

[C17 wide string and memory clauses, WG14 N2310](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

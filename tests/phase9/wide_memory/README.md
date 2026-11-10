# Wide-memory verification fixtures

The original wide manifest supplies directed cases and generated
zero-stub controls for these four functions. These additions capture
the full returned pointer or the sign of the low 32-bit integer
result through the shared SysV trampoline. The wmemset cases poison
the upper half of the signed wchar_t argument register.
[AMD64 System V ABI](https://gitlab.com/x86-psABIs/x86-64-ABI)

The model operates on raw signed 32-bit wchar_t elements, including
WCHAR_MIN, WCHAR_MAX, -1, zero, and values that differ only in high
bytes. Wmemcmp checks only the first mismatch sign. Embedded zero
elements do not terminate these memory operations.
[Project wide-element contract](../../../docs/adr/0012-c-utf8-multibyte.md) ·
[WG14 wide memory clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

The guard cases place each disjoint array independently at either
edge of a readable page with inaccessible pages on both sides.
An adjacent readable element is a canary. A zero count passes
mapped protected addresses. Nonzero wmemcpy ranges are disjoint.
Wmemmove cases cover left and right overlap, different overlap
distances, self moves, and disjoint ranges within one valid array.
Their model copies from a separate pre-call snapshot, and checks
the entire containing array afterward. The outer page guard and
canary bound the union of the overlapping ranges.

The shared direct packet fixture is compiled against the candidate
and both pinned hosted libraries. Each input is two little-endian
uint64 words. The low 62 bits of the first select a scenario, and
its high bits select array placement. An overlapping union uses
the first placement bit. The second word seeds the full-width
elements and lengths. All source, destination, and canary elements
are checked against the independent model after each operation.

The 64-byte output contains the signed normalized result and
unsigned scenario, count, source offset, destination offset,
fill-value bits, element digest, and observed errno. A comparison
emits its sign. A move emits its destination offset after verifying
the exact returned pointer. Other writes emit zero after the same
pointer check. Statuses 11–13 identify ABI state, result or errno,
and object mismatch. Statuses 21–23 identify semantic result,
errno, and object or canary mismatch. The 90s identify fixture
setup or packet I/O errors.

The replay checks the compiled packet object's undefined symbols and
rejects calls to memcpy, memmove, or memset from its model.

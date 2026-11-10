# Phase 2 test oracles

The manifest covers all 22 C17 `string.h` functions, all 14 C17 `ctype.h`
functions, nine integer conversions, `qsort`, and `bsearch`. The fixtures
were written against the public specifications and the System V AMD64 ABI.
The gate links the candidate under a distinct symbol and uses `nm` to
verify references to that symbol and to the selected host oracle.

| Oracle ID | Observations |
| --- | --- |
| `abi:sysv-amd64` | The trampoline checks stack balance, DF, callee-saved registers, MXCSR control bits, the x87 control word, and x87 stack depth. Array comparator callbacks also check their incoming stack alignment and DF. [AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI) |
| `reference:byte-count` | The original `strlen` fixtures count the prefix before the first zero, including high-bit bytes. [Phase 0 test oracles](../../docs/cookbook/test-oracles.md) |
| `c17:byte-operations` | C17 §7.24.2, §7.24.4, §7.24.5 and §7.24.6. Independently construct the expected destination or search position. Copy tests preserve bytes outside the destination. `memmove` checks both overlap directions, identical pointers, and disjoint regions. `memcmp` compares the sign of the first differing unsigned byte. |
| `c17:string-operations` | C17 §7.24.2 through §7.24.5. Construct exact copied, padded or appended bytes. Check search offsets, first differences, empty sets and needles, partial matching, high-bit bytes, and the terminator. In the C locale, the `strxfrm` reference compares the identity transform and its length. The candidate additionally leaves a short destination unchanged under its project specification. |
| `c17:tokenization` | C17 §7.24.5.8. Compute token offsets and every mutation on a separate buffer. Change delimiters during continuation, exhaust trailing delimiter runs, and reset an unfinished scan with a new string. |
| `project:strerror-messages` | C17 §7.24.6.2 allows implementation-defined message wording. Test nonempty messages, the project's documented unknown-error fallback, and preservation of `errno` and prior messages. A signal-guarded read checks returned strings for unassigned Linux error numbers and the boundary around `EFTYPE`. The host comparison only checks the host's message is nonempty. [Linux UAPI error numbers](https://github.com/torvalds/linux/blob/master/include/uapi/asm-generic/errno.h) |
| `c17:c-locale-ctype` | C17 §7.4. Exhaust every `unsigned char` value and `EOF` against ASCII range membership and case pairing. Normalize classification results to zero or nonzero. |
| `reference:integer-construction` | C17 §7.8.2 and §7.22.1. Construct digit strings from known magnitudes with wider arithmetic, then compare the return value, end pointer, and `errno`. Directed cases cover invalid bases, incomplete prefixes, no digits, all C whitespace, signed bounds, unsigned negation, and overflow through the full digit run. Host comparisons omit the project's `EINVAL` policy where C17 leaves it open. |
| `reference:sorted-permutation` | C17 §7.22.5.2. Check monotonic keys and one-to-one preservation of complete records, allowing equal keys to reorder. Exercise unusual widths, duplicate and descending inputs, nested sorting, extreme comparator returns, and memory safety with inconsistent comparators. |
| `reference:sorted-search` | C17 §7.22.5.1. Check membership and any matching element among duplicates. Validate that the comparator receives the original key first and an in-array element second. |
| `reference:page-protection` | Place valid inputs or destinations at the low and high edges of readable or writable pages bounded by `PROT_NONE`. Inputs that should never be written are read-only. A protected-page violation during the probe fails the fixture. |
| `diff:glibc`, `diff:musl` | Compare each host result against the same independent reference. The separate `strlen` oracle executable uses a counted byte protocol. [glibc manual](https://sourceware.org/glibc/manual/), [musl](https://musl.libc.org/) |

The C17 section numbers refer to ISO/IEC 9899:2018. [WG14 C17 draft record](https://open-std.org/jtc1/sc22/wg14/www/wg14_document_log_v2.htm)

`unit` runs directed cases and `differential` also runs a fixed seeded
prefix. `fuzz [SECONDS]` repeats the same prefix and extends the sequence
for the requested duration. The libFuzzer entry point uses input bytes to
select a case and vary its seed, then checks that case against the
independent oracle. The dedicated `strlen` entry point takes the fuzzed bytes
directly as the string buffer. Branch coverage and mutation results come
from the gate's execution records.

`ctype` takes scalar inputs and returns scalar values, so its manifest
records why guard pages do not apply. Guard pages detect accesses across protected
boundaries and writes to read-only input. Accesses within the same mapped
page are outside their resolution. The fixtures use the C locale and only
the C17 input domain, plus the project-specific invalid-base and
degenerate-array behavior declared in the specs.

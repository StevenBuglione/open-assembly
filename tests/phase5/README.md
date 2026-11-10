# Phase 5 numeric test oracles

The parser fixture compares the object representation, end pointer,
`errno`, and the hardware floating environment. It reads generated
packets with a 24-byte little-endian header and an ASCII subject. Each
header carries the input length, expected endpoint, rounding mode,
expected exception flags, expected error, and the two words of the
expected value. The fixture checks the count of consumed packets.

| Oracle ID | Expected observations |
| --- | --- |
| `reference:exact-rational` | Construct magnitudes independently with Python fractions. Scale to the target binary quantum and use quotient and remainder to derive the rounded bits for each direction. Check ties, carry at the normal boundary, signed zero, overflow, subnormal results, and sticky digits beyond the retained prefix. |
| `reference:mpfr` | Convert the same finite exact fractions independently using MPFR at 24, 53, and 64 bits, explicit exponent bounds and subnormal emulation. Compare MPFR's exact rational result with the arithmetic model before running the candidate. [MPFR manual](https://www.mpfr.org/mpfr-current/mpfr.html) |
| `project:fp-effects` | Check canonical signed NaN, exponent rollback, C-locale whitespace, endpoints, preservation of prior flags and controls, and the declared range-error and tininess policy. [Numeric ABI](../../docs/adr/0006-exact-numerics.md) |
| `c17:fenv`, `reference:x86-fp-state` | C17 §7.6. Seed x87 and SSE status/control state with hardware instructions, then observe both units independently. Exercise the eleven fenv APIs, including flag masks, save and restore, default state, and hold/update. [Intel architecture manuals](https://www.intel.com/content/www/us/en/developer/articles/technical/intel-sdm.html) |
| `c17:float-format` | C17 §7.21.6.1. Check decimal notation selection and digit counts, directed rounding, truncation, signed zero and special values. A variadic case crosses all eight SSE argument slots and interleaves aligned extended values with general-purpose arguments. Hexadecimal spellings are compared by their represented value where C permits different normalizations. |
| `c17:float-scan` | C17 §7.21.6.2. Scan directly to all three destination precisions, distinguish just-above-halfway cases from double rounding, check signed zero and subnormals, and check width, suppression, count, and retained lookahead through the actual stdin stream. |
| `diff:glibc`, `diff:musl` | Separate hosted fixture builds exercise the common numeric results. Project-specific exception effects and canonical NaN payloads use the declared ABI oracle. |

The published input includes all 60 rows in `data/more-test-cases.txt`
from the Apache-2.0 parse-number-fxx dataset. The gate compares the
published binary32 and binary64 fields at round-to-nearest and records
the original data and license hashes. The rest of the generated corpus
comes from the exact model and the fixed seed `0x50483552`. [Pinned published data](https://github.com/nigeltao/parse-number-fxx-test-data/tree/55d79b184b7d8fac2e143e89dc19b766ec4e54b8)

Each native converter also runs a 60-second seeded differential
campaign. Each batch balances decimal and hexadecimal syntax across
the four rounding modes. The gate records the actual accepted count,
elapsed time, seed, and a hash of the reproducible packet prefix.

The pinned musl reference disagrees on some cases that underflow to
signed zero and on directed binary32 rounding. The host comparison
reports exclusions for those inputs. Native and QEMU still run the full
exact and MPFR corpus. Memcheck drops some
floating-point status flags and loses precision on x87 extended values.
The gate records those exclusions. Separate Memcheck runs still
check the full binary32, binary64 and `atof` corpus for values and
endpoints, plus the applicable fenv and stream cases.

The runtime binaries use the generated freestanding headers and archive.
The gate records the actual pinned MPFR library, SONAME, version and
hash, plus the test-object symbol references and generated-stub
rejections. C17 references use the WG14 baseline. [WG14 C17 clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

```sh
./tools/container python3 tools/phase5.py
```

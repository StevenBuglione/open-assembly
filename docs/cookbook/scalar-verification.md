# C17 integer arithmetic production checks

Run `./tools/container make production-scalars` for `abs`, `labs`, `llabs`,
`div`, `ldiv`, `lldiv`, `imaxabs`, and `imaxdiv`. This is a separate batch
from the original 47 Phase 2 functions. The batch uses the same
`tools/gate --production` reports for individual queue eligibility.

The independent C17 oracle covers positive, negative, zero and
representable boundary values. The division cases compare both quotient
and remainder, including the signed minimum dividend with valid divisors.
Inputs whose mathematical result falls outside the type and zero divisors
are excluded. The pinned glibc and musl programs independently exercise
the same operations. The 60-second libFuzzer campaign for each candidate
compares the assembly result with both the C reference and glibc.
[WG14 integer arithmetic and greatest-width integer clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

The native and QEMU ABI probe checks preserved state and poisons the upper
register halves for 32-bit arguments. Directed probes check the declared
result registers and `errno`. Valgrind runs the hosted differential cases.
QEMU records the actual source-mapped candidate entry even for a function
with zero conditional edges. The stub returns a typed zero and the
mutation checks change both result fields of the division functions. A
wrapper's report binds a fresh passing result for its linked arithmetic
implementation. The scalar signatures have no caller-supplied memory
range for guard pages. The pinned libc-test snapshot contains no mapped
functional cases for these eight arithmetic entries.

# Independent exact mathematics fixtures

The typed packet checker compiles separately for binary32, binary64 and
x86 binary80, with compiler builtins disabled. Its operands and expected
results are representations supplied on standard input. For the native and
QEMU passes it checks result bits, exponent and quotient outputs, errno,
new exceptions, an unrelated seeded exception, and preserved control state.
The full candidate matrix uses all four rounding modes. The classification
and comparison cases call the public C17 macros.

The packet generator derives classification, signs, adjacent values and
integer rounding from IEEE encodings and exact rationals. It uses the Phase 5
rational rounding oracle and MPFR cross-check for fused arithmetic and
scaling. For square roots, cube roots and hypotenuses it calculates the
target-rounded result with pinned MPFR and checks exactness with independent
rational powers. Finite bit equality establishes zero ULP error for the
sampled observations. Directed boundary cases cover signed zero, signaling
and quiet NaNs, subnormal transitions, finite extrema, cancellation, halfway
values, integer range limits and extended-precision nexttoward comparisons.
The random inputs use fixed per-format and per-operation seeds.

The hosted probes compare the same result and out-parameter checker over a
documented common domain. The shared remquo cases keep the entire quotient
within the common low three bits. The project checks its full seven-bit
contract separately. Host cbrt comparisons use nearest rounding and the exact cubes of zero,
one and two with either sign. Pinned glibc also differs from the exact
binary64 value of cbrt(27) in nearest rounding. The candidate is compared against MPFR in every rounding mode.
Memcheck covers the common binary32/64 result domain in nearest mode. Full
x87 extended precision and raw control/status observations run natively and
in QEMU.

Build `math_packet.c` three times with the pinned C test flags and
`-DTEST_FORMAT=32`, `64`, or `80`. Link the freestanding objects against
the audited candidate startup object and archive. The report runner
expects `math-f32`, `math-f64`, and `math-f80` in the binary directory.
Optional hosted binaries use the same C source and ordinary `-lm` with
the pinned GCC and musl-GCC. Use `gcc-math-f32`, `musl-gcc-math-f32` and the
corresponding names for the other types. Optional generated stub binaries
link the same fixture with one public symbol wrapped and use that symbol
as their filename. Floating stubs use the return register for the target
type.

```sh
python3 tests/phase7/sample.py build/phase7 build/evidence/phase7-sampled.json \
    --hosts build/phase7 --stubs build/phase7/stubs
```

The exhaustive fixture computes each binary32 expectation on the fly.
Its arguments are the operation, rounding-mode index (nearest, downward,
upward, toward zero), first bit pattern and number of consecutive patterns.
`exhaustive.py` verifies a disjoint contiguous shard partition and records
per-shard completion, the exact pattern count, and frozen artifact hashes.
A report marks the full domain complete only when every requested shard
passes and the union is the entire 2^32 domain. Each report binds one
operation, one rounding mode and one executable. Boundary-window runs are
sampled and have their own counts.

```sh
python3 tests/phase7/exhaustive.py build/phase7/exhaustive fabsf \
    build/evidence/phase7-fabsf-exhaustive.json --mode 0 --shards 64 --workers 4 \
    --input build/runtime/libopenasm.a --input build/runtime/crt1.o
```

[WG14 C17 math clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf) ·
[MPFR reference manual](https://www.mpfr.org/mpfr-current/mpfr.html) ·
[Phase 7 exact mathematics contract](../../docs/adr/0008-math-range-reduction.md)

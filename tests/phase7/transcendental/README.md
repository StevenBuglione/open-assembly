# Independent transcendental accuracy probes

The probe is compiled for binary32, binary64, and x86 binary80 using the
public declarations and disabled compiler builtins. A fixed-width binary
protocol supplies one or two input representations, an operation, and a
rounding mode. The probe returns the actual representation, errno, floating status
flags, and a control-state change bit. Each call starts with a known errno
and an unrelated preexisting exception. This exposes failures to preserve
state and verifies newly raised exceptions.

The independent oracle uses pinned MPFR in the target precision, target
exponent range, and selected rounding mode, with subnormal handling.
Finite error is the count of adjacent target encodings between the result
and the correctly rounded MPFR value. The bound is one ULP for approximate
normal results, with the sign and class checked separately. Special values,
signed zero, exact powers and zero-input identities, and range-boundary
results use exact checks where the contract specifies them. Domain NaNs
are checked for quietness. NaN propagation cases also check their payload
and sign bits.

Directed inputs include exact powers of two and representable powers of
ten, cancellation near one, underflow and overflow transitions, tiny
arguments, and signed extrema. Trigonometric inputs include representable
neighbors of MPFR-enclosed multiples of pi/4 and points selected by their
small MPFR reduction residuals at large exponents. The expm1 and log1p
cases stress cancellation, tiny results and the log1p pole. The pow
cases cover sign and parity, identities, NaN priority, representable
roots and rational powers, exponent range boundaries, and bases close
to one with large exponents. Inverse trigonometric inputs cover domain
endpoints and reduction intervals, and atan2 covers signed-zero and
infinite quadrants and ratios spanning the full exponent range.
Hyperbolic inputs cover tiny results, overflow, saturation and inverse
domain and pole transitions. The error-function cases find saturation
and gradual-underflow neighborhoods by independently solving for target
erfc values with MPFR. The gamma cases cover exact factorials, signed
poles, large positive overflow, negative tails, and cancellation at
negative zeros of lgamma. Seeded, stratified bit
patterns broaden the sample across each target. The consecutive binary32
runner separately measures selected large ranges. These runs are sampled
coverage of the full domain. Their reports include exact starting bits,
count, rounding mode, executable and archive hashes, oracle generation
time, runtime time, and observed maximum ULP.

Native and QEMU runs check the full selected domain. Memcheck checks
nearest shared normal/zero binary32 and binary64 results. The separately
labeled hosted glibc and musl runs compare the same nearest subset.
Their long-double log10 values at some exact powers of ten differ by one
ULP from the project's exact-result requirement. The reports also record
larger hosted MPFR differences for log1p and expm1 in binary80. The MPFR oracle gates the candidate.

In the integrated checkout, `./tools/container make phase7-transcendental`
runs the pinned gate, including two isolated candidate builds, ELF and
symbol checks, hosted comparisons, MPFR comparisons, and typed generated
stub rejections. To include the selected large binary32 ranges, run
`./tools/container python3 tools/phase7_transcendental.py --shards`.

For isolated fixture use, build `probe.c` with the pinned C test flags and `-DTEST_FORMAT=32`,
`64`, and `80`. Use object names `trans-f32.o`, `trans-f64.o` and
`trans-f80.o`. Link the objects against the audited candidate startup
and archive as `trans-f32`, `trans-f64`, and `trans-f80`.
Optional hosted probes compile the same file against pinned GCC/musl-GCC
with `-static -no-pie -lm`, using names such as `gcc-trans-f32` and
`musl-gcc-trans-f32`.

```sh
python3 tests/phase7/transcendental/controls.py build/phase7 \
    build/runtime/crt1.o build/runtime/libopenasm.a build/phase7/stubs \
    build/evidence/phase7-trans-controls.json
python3 tests/phase7/transcendental/verify.py build/phase7 \
    build/evidence/phase7-trans-sampled.json --hosts build/phase7 \
    --stubs build/phase7/stubs --input build/runtime/libopenasm.a
python3 tests/phase7/transcendental/verify.py build/phase7 \
    build/evidence/phase7-trans-shard-sin.json --shard sin 0x7f000000 262144 3 \
    --input build/runtime/libopenasm.a
python3 tests/phase7/transcendental/verify.py build/phase7 \
    build/evidence/phase7-trans-shard-pow.json --shard pow 0x3f7e0000 262144 2 \
    --second 0x457ff000 --input build/runtime/libopenasm.a
```

The generated controls link a typed zero return for each public symbol.
Separate wrappers exercise acceptance at one representable step,
rejection at two steps, rejection of an extra exception, and exact-case
rejection at one step. These are targeted fixture controls.

[Phase 7 contract](../../../docs/adr/0008-math-range-reduction.md) ·
[MPFR reference manual](https://www.mpfr.org/mpfr-current/mpfr.html)

# Independent Phase 7 complex fixtures

The typed C fixture covers packed binary32 components, separate SSE
binary64 components, and the two-slot x87 extended ABI. It loads exact
component representations, including signed zeros and NaN payloads.
Both output components are checked for complex results, along with x87
stack depth, sticky exception flags, errno and floating controls.

Component extraction, conjugation and projection use bit rules.
Magnitude uses exact dyadic sums and MPFR square-root rounding.
Argument uses MPFR atan2. Logarithm, square root, exponential, circular
trig, hyperbolic trig and their inverses use directed GNU MPC bounds for finite values
and explicit Annex G expectations for selected nonfinite cases.
An output with an unspecified NaN payload or zero/infinity sign is
checked by its result class. The C17 correction for `cacosh(0+iNaN)`
allows either sign of π/2, with a separate directed reference for each. A standard-permitted optional invalid flag
is masked only on the selected rows that permit it.

MPC and MPFR come from the pinned image and the gate records the loaded
libraries' hashes. A finite inexact normal result may differ by one ULP
per component. Exact, signed-zero and range cases require the specified
representation. The sampled corpus includes four rounding modes, signed
branch cuts, small components next to large ones, overflowing intermediate
ranges, both sides of inverse branch cuts and poles, and neighbors of
argument reduction boundaries. A fixed seed
adds ordinary dyadic pairs. Hosted and Memcheck observations use a
nearest-mode finite shared subset. The Memcheck comparison covers
binary32 and binary64 because its x87 emulation does not retain the
64-bit extended significand.

The binary complex power probe passes independent real and imaginary
values for both arguments through the three SysV calling conventions.
It uses scalar MPFR for nonnegative-real scalar cases, exact dyadic
quarter-turns for cardinal phases, and directed MPC intervals for
general finite powers. Samples cover both sides of the negative-real
cut, exponents through the binary80 range, huge noncardinal phase at
finite magnitude, and a small factor that rescues one component while
the other overflows. The sampled one-ULP bound applies to same-sign,
same-class finite nonzero magnitudes outside the exact scalar and
unit-cardinal cases. Zero and range transitions remain class-checked.
The checker requires final component range flags and errno. It allows
additional Annex G intermediate flags on the general path and still
checks the seeded sticky flag and unchanged controls.

Run `./tools/container make phase7-complex` for the pinned gate. It builds
two independent runtime archives and checks that each typed fixture links
to the intended public definitions. Each generated zero stub follows the
scalar or complex return ABI and must fail its oracle.

`replay_boundaries.py` isolates the directed normal/subnormal transition
that the broader inverse sample found. For `x = 2^(-emin)`, the exact
real part of `atanh(x+i)` is below `1/x` by less than one subnormal step.
The small angle of `acos(x+i)` and `acosh(x+i)` is above `1/x` by
less than one normal step. The replay cross-checks these conclusions
against the MPC intervals before querying either backend.

[Complex ABI contract](../../../docs/adr/0011-complex-abi.md) ·
[WG14 N2310 Annex G](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf) ·
[WG14 DR 471](https://open-std.org/JTC1/SC22/WG14/issues/c11c17/log.html#issue0471) ·
[AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI) ·
[GNU MPC manual](https://www.multiprecision.org/mpc/documentation.html)

# Phase 7 exact math and range reduction

The first Phase 7 slice operates on binary32, binary64 and the canonical
x86 extended format. It uses the Phase 5 rounding modes and exception
flags. Test code can compare returned bits, sign of zero, the integer or
exponent outputs, errno and the exception set. Use MPFR at each target
precision with an explicit exponent range and subnormal treatment.
Classification and sign operations use an independent IEEE bit model.

## Exact and basic operations

- fabs and copysign change only a sign bit. Classification accepts
  finite values, zero, infinity and either class of NaN. The classified
  value's representation is otherwise preserved. Classification does
  not raise exceptions. Comparisons on signaling NaN and noncanonical
  extended encodings need separate coverage.
- sqrt observes the current rounding mode. Preserve signed zero.
  Positive infinity stays infinity. Negative nonzero values, including
  negative infinity, yield NaN with FE_INVALID and EDOM. Quiet NaNs
  propagate. Signaling NaNs are quieted and raise FE_INVALID.
- ceil, floor and trunc choose the named integral direction. round
  chooses the nearest integral value, with ties away from zero.
  nearbyint and rint use the active rounding mode, with ties to even in
  nearest mode. Preserve zero sign. Only rint raises FE_INEXACT for a
  discarded nonzero fraction. Quiet NaNs propagate. Other arithmetic
  math entries quiet signaling NaNs and raise FE_INVALID.
- lrint and llrint use the active rounding mode and raise inexact for a
  discarded fraction on a valid result. lround and llround use nearest
  with ties away and leave inexact unchanged. The signed integer return
  type is 64 bits on this target. NaN, infinity or an unrepresentable
  integral result yields the signed minimum with FE_INVALID and EDOM.
- frexp returns a signed fraction with magnitude in [0.5, 1) and
  stores a base-two exponent. For zero, infinity and NaN, store exponent
  zero. Scaling by scalbn, scalbln and ldexp multiplies by an exact
  power of two, rounds only at the range boundary and preserves signed
  zero. An inexact tiny result raises FE_UNDERFLOW and FE_INEXACT with
  ERANGE. Exponent overflow raises FE_OVERFLOW and FE_INEXACT with
  ERANGE. Exact subnormals leave errno and flags unchanged.
- modf separates the integral and fractional parts without rounding.
  Both parts retain the sign, including zero. Infinity produces a
  signed zero fractional part. A NaN propagates to both parts.
- nextafter and nexttoward move one representable step in the requested
  direction independently of the rounding mode. Equal operands return
  the target's value, including its zero sign. A step from a finite
  operand to infinity raises overflow and inexact with ERANGE. A step
  into the subnormal interval, including a step to or from zero,
  raises underflow and inexact with ERANGE.
- ilogb returns the unbiased leading-bit exponent, including for
  subnormals. For zero and NaN return INT_MIN. For infinity return
  INT_MAX. These special results raise invalid with EDOM. logb returns
  a floating representation of the exponent. For zero it returns
  negative infinity with FE_DIVBYZERO and ERANGE. For infinity it
  returns positive infinity.

- fmin and fmax choose the numeric operand when the other operand is a
  quiet NaN. They choose negative and positive zero respectively.
  Signaling NaN takes precedence and raises invalid. The comparison
  macros use unordered results for all NaNs without raising invalid
  while inspecting same-format operands. Widening conversions for
  mixed-format operands use the usual arithmetic conversions.
- fmod uses a quotient truncated toward zero. remainder and remquo use
  the nearest integer with ties to even independently of the rounding
  mode. remquo stores the signed low seven bits of that quotient. These
  exact functions preserve errno and exceptions for finite results.
  A zero divisor or infinite dividend raises invalid with EDOM when
  neither operand is NaN. A zero result keeps the dividend sign.
- nan, nanf and nanl construct the canonical positive quiet NaN
  independently of the supplied tag.

- fma forms the integer significand product and aligns both addends
  to the smaller binary exponent before adding or subtracting. The
  shared rational rounder rounds the exact result once. The largest
  binary80 alignment span is below 50,000 bits, within the 81,920-bit
  limb capacity. Exact zero from opposite signs uses the downward
  rounding sign rule. Infinite products with a zero factor and
  opposite infinite summands report FE_INVALID and EDOM if no NaN
  operand takes precedence. fdim reuses exact addition for positive
  differences and returns positive zero for an ordered x no greater
  than y. The two families use dedicated limb scratch behind runtime
  lock hooks. They release it before publishing floating exceptions
  and are unsuitable for signal handlers that can interrupt the same
  family.

- cbrt and hypot determine a result quantum from the exact leading
  exponent. They compare integer cubes or squares against a scaled
  radicand, retaining fractional bits for the exact midpoint comparison
  and a sticky bit below them. Hypot aligns and adds the two exact
  integer squares before rounding. The binary80 radicand is at most
  65,658 bits, within the same limb capacity. These functions use
  dedicated scratch under the runtime lock hooks and release it
  before raising floating exceptions.

The scalar assembly layer uses bit decomposition for exact operations.
SSE2 provides binary32 and binary64 square roots, and x87 provides the
extended square root. The standard fenv APIs keep the two rounding
controls synchronized. The supported environment uses the ABI precision
and subnormal settings with any of the four standard rounding modes.
Additional hardware precision and flush controls need separate tests.

## Range reduction before transcendental implementation

Trigonometric reduction needs a certified interval for x times 2/pi.
Generate a fixed-point 2/pi table with independent MPFR lower and upper
bounds. Size the table from the largest accepted binary exponent,
significand length and the residual precision needed after selecting a
quadrant. At each reduction, propagate a bound on the omitted product
bits. If the interval still intersects a half-integer boundary, retain
more table limbs before choosing the quadrant. Once the quadrant is
certain, form the small remainder using split pi/2 limbs and account
for the rounding of each reconstruction operation. Save hard cases
near quadrant boundaries and near zeros of sin or cos. Tangent needs
a separate error bound near poles because the reciprocal magnifies
remainder error.

For exp and log, reduce with exact powers of two and split ln(2)
constants. Form the reduction interval using directed reference
arithmetic. Handle values near one in log1p and near zero in expm1
through dedicated paths with stable cancellation behavior. Choose a
polynomial only after fixing the reduction interval, target precision
and evaluation rounding. Treat approximation error, rounding error
and reduction error separately in the ULP report.

The 16,896-bit table has a reproducible separation certificate in
`tools/math-range-certificate`. Let C be floor((2/pi) * 2^16896)
and D = 16896 - k for a magnitude m * 2^k. The two directed MPFR
bounds agree on C. Then mC / 2^D is a lower bound on the exact
reduction product, with omitted positive tail below m / 2^D.

For each exponent k from -64 through 16320, the certificate counts
residues of 2mC modulo 2^D for 1 <= m < 2^64. It uses Euclidean
reciprocity to sum floors of arithmetic progressions and counts
both end intervals without enumerating significands. No residue
lies within (2^D / 2^128) + 2(2^64 - 1) of zero modulo 2^D.
After subtracting the worst omitted tail, twice the exact reduction
product stays more than 2^-128 from every integer. That proves the
nearest quadrant and gives a lower bound on the nonzero residual
magnitude for this input interval. Smaller exponents give input
magnitude below one half and need no argument reduction.

The certificate verifies the table and separation property. It is
distinct from an exhaustive run of floating-point function calls.
The little-endian table SHA-256 is
`a9a5d9e59cfdf4a4ead9d3dfb70c1d7e93af925bf571214c09ed5c3c527170b7`.

The reducer retains 256 fractional bits and uses the Q256 floor of
pi/2. The total absolute error of the retained reduced angle is
below three Q256 units. The sine and cosine kernels alternate terms
in the reduced interval. The squared angle and each truncating
multiply and divide contribute bounded error. With at most 48 terms,
the kernel error stays below 1,024 Q256 units. The tangent path
rounds a ratio of the two computed series. In odd quadrants it
reverses that ratio and changes the sign. The separation certificate
bounds the denominator away from zero when the reciprocal is used.
For arguments below 2^-80 the side of the exact result relative to
the argument or to one determines directed rounding, including at
the subnormal boundary.

The first exp2 kernel uses the exact reduction x = n + f with integer
n and 0 <= f < 1. An integer input takes the exact scaling path.
Arguments with magnitude below 2^-80 round at one, with the adjacent
value selected only when the rounding direction requires it.
Otherwise the fractional remainder is exactly representable in the
256-bit fixed-point format used for reduction.

Compute t = f ln(2) with the lower fixed-point enclosure for ln(2).
The constant's 256-bit floor is identical when computed from both
directed MPFR bounds at precision 1024. Use 56 positive Taylor terms,
truncating each multiply and divide downward. If u = 2^-256, the
error in t is less than 2u. Each term error is bounded by the prior
term error divided by the term index plus 4u. The first term error
is below 4u and the later terms are within 8u. The omitted tail is
below u since exp(t) is below two and 2 (ln 2)^57 / 57! is below u.
The lower series and that series plus 512u therefore enclose the
reduced result. Round their midpoint using the common binary
rounder, then apply the exact binary scale. This analytical error
bound does not assert correct rounding for every midpoint case.

Natural exp reduces x times log2(e) on the same fixed grid. The
constant is the floor from the directed reciprocal of ln(2).
The additional argument error is bounded by (|x| + 1) Q256 units.
Reduction to integer and fractional parts of the approximate
argument does not introduce a discontinuity in the reconstructed
exponential. For expm1, subtract one on the common integer scale
before final rounding. A small argument uses the known side of
expm1(x) relative to x, and a sufficiently negative argument uses
the known side relative to negative one. These paths preserve
directed rounding through cancellation.

The logarithm kernel decomposes positive x exactly as 2^e m with
1 <= m < 2. The restoring integer division retains the floor of
u = (m-1)/(m+1) on the 256-bit grid. The atanh series retains 88
odd terms with downward truncation, and u is below one third. If
v = 2^-256, the error in u squared is below 2v and the repeated
power error is below 2v. The term divisions add less than v each.
The series tail is below v and the total series error is below 265v.
For log2, scaling by the directed enclosure of 2/ln(2) gives error
below 1024v. The midpoint correction is applied before combining
with the exact integer exponent. For natural and base-ten logarithms,
the integer exponent contribution uses the lower ln(2) constant.
The additional error is bounded by |e|v. The base-ten scaling uses
the lower 1/ln(10) constant. Across all supported finite arguments,
the final absolute error is below 2^16 v before binary rounding.
Exact powers of two for log2, exact powers of ten for log10, and
one for log bypass the series and preserve FE_INEXACT.

For log1p, first form the exact dyadic sum 1 + x in integer limbs,
then normalize it before the Q256 logarithm evaluation. This retains
the low correction even where ordinary addition in the target format
would lose it. The special path for small arguments uses the fact
that log1p(x) is below x for every nonzero x in its domain.

Pow keeps log2 of the base magnitude and its product with the
exponent at Q256 before evaluating exp2. In the finite reduced
exponent range the multiplier can amplify logarithm error, so the
error bound uses the minimum nonzero log2 magnitude of a target
input near one and the maximum exponent product accepted by the
reduction. Powers of two use an exact integer logarithm. For other
dyadic bases, isolate the odd integer factor. An exact target-width
power has an odd factor with at most 64 bits, so a nonunit factor
allows numerator at most 40 and fractional denominator at most 32.
Where the odd factor and power of two admit that root, compute the
resulting rational power in limbs and round it once.

Inverse tangent reduces to a positive ratio at most one and
composes the selected signed quadrant from pi/4 multiples. Ratios
above one half use (1-r)/(1+r) and the quarter-pi complement.
For very small ratios on the axis through zero, the correction
from atan(r) to r is below the separation from nonidentical target
rounding boundaries of a rational with two 64-bit significands.
A small exact rational decrement selects the correct side of an
equal boundary. Near the other axes, the corresponding pi multiple
has a target rounding interval wider than the omitted correction.

The asin and acos kernels use a Q256 power series with argument at
most one half. For larger magnitudes, the half-angle transformation
forms the exact dyadic radicand (1-|x|)/2 and computes its Q256
square root using restoring integer digits. The cosine complement
near positive one is formed directly from the small half-angle
series to preserve its relative accuracy.

The hyperbolic kernels retain the Q256 magnitude of exp(|x|) and
its binary exponent. Sinh and cosh use the ratio of exp(2|x|) plus
or minus one to 2 exp(|x|). Tanh uses the ratio of the difference
and sum with one. The integer differences are formed before target
rounding. Large arguments omit the inverse exponential when its
relative contribution is below the fixed-point error. Tiny arguments
and saturated tanh use the direction of the exact correction to
select an adjacent value under directed rounding.

Inverse hyperbolic sine and cosine form x squared plus or minus
one on an exact dyadic scale, compute a Q256 square root, then
evaluate the natural logarithm of the resulting sum. For magnitudes
above 2^96 the correction to log(2|x|) is below the approximation
budget. Inverse hyperbolic tangent combines natural logarithms of
the exact dyadic inputs 1 + |x| and 1 - |x| before final rounding.

Gamma uses the exact factorial for positive integral arguments
and otherwise evaluates log-gamma on the Q256 grid. The positive
recurrence shifts the argument to at least 64 before applying 28
Stirling correction terms. The Bernoulli coefficients are scaled
at 64 and the first omitted term bounds the positive-real remainder
below 2^-245. The negative side uses reflection with the sine of
the exact fractional argument and the interval parity for the sign.
The reciprocal singularity near zero uses a rational perturbation
whose sign selects the correct side of an exact reciprocal tie.
[NIST gamma recurrence and reflection](https://dlmf.nist.gov/5.5)
and [NIST Stirling expansion and error bounds](https://dlmf.nist.gov/5.11).

The binary32 `tgammaf` entry classifies provable extremes before the
Q256 calculation. The Euler integral bounds the reciprocal growth
by \(\Gamma(1+x) \ge 1 - \gamma x\), with Euler's constant \(\gamma\).
This proves overflow for \(0 < |x| < 2^{-128}\) and at \(-2^{-128}\).
Positive \(2^{-128}\) retains the general path because downward and
toward-zero rounding produce max finite with INEXACT alone. A directed
256-bit MPFR lower bound at float encoding `0x420c2910` exceeds
\(2^{128}\). Monotonicity gives overflow for every larger finite
positive input. [Euler integral](https://dlmf.nist.gov/5.2) ·
[Log-convexity](https://dlmf.nist.gov/5.5.iv)

For a negative noninteger below -42, the binary32 distance to the
nearest integer is at least \(2^{-18}\). Reflection, the sine chord
bound on that interval, and \(42! > 2^{169}\) place the nonzero
result below half the least subnormal in magnitude. The integer part's
parity determines the sign. The existing scaling helper applies the
caller's rounding mode and publishes the corresponding range flags and
errno. [Reflection formula](https://dlmf.nist.gov/5.5.ii)

The finite binary32 fast path evaluates gamma in binary64 with an
enclosure around the approximation. For \(|x| \ge 2^{-18}\), exact
integer shifts reduce the argument to \([2.5, 3.5)\). The shifted
binary32 arguments have at most 41 fractional bits and magnitude
below 64, so each recurrence factor is exact in binary64. The
degree-24 Taylor polynomial about 3 has absolute remainder at most
\(2^{-45}\). On the radius-2 circle, Euler's integral bounds the
complex gamma magnitude by 24. The weighted absolute sum of Taylor
coefficients on the reduced interval is at most 32. Rounded
coefficients and 48 Horner operations contribute less than
\(2^{-42}\) absolute. The central gamma value exceeds one. At most
45 recurrence products and a final multiplication or division keep
the combined relative error below \(2^{-40}\). The relative radius
\(2^{-39}\) leaves room for rounding both enclosure endpoints.
[Euler integral](https://dlmf.nist.gov/5.2.i) ·
[Gamma series and recurrence](https://dlmf.nist.gov/5.7)

For smaller arguments, use the reciprocal plus three correction terms
from the Taylor series of \(\Gamma(1+x)\). Cauchy's estimate on the
radius-1/2 circle about 1 bounds the omitted correction by
\(64 |x|^3\). Binary64 reciprocal and addition roundoff plus this
remainder fit inside the relative radius \(2^{-49}\).

The candidate converts both bounds under the caller's rounding mode
and requires matching binary32 bits and overflow status. It accepts
an inexact result only when the rounded value is outside the closed
enclosure. Possible exact results and ambiguous rounding fall back
to Q256. MXCSR is restored before returning, calling the fallback,
or publishing the proved effects. Exact factorials and negative
integers continue through the existing engine.

The binary32 `lgammaf` entry uses separate enclosures for small
arguments, the two positive roots, and positive arguments at or above
8. For \(0 < |x| \le 1/16\), a degree-12 log-gamma series corrects
\(-\log |x|\). The omitted series is bounded by \(2^{-54}\).
Within 1/8 of 1 or 2, factor out the exact displacement before the
degree-18 series evaluation. The leading coefficient in each factored
series stays separated from zero, so relative accuracy is retained
near the roots. [Gamma series](https://dlmf.nist.gov/5.7.E3)

The binary64 logarithm reduces its input to \(2^e m\), with
\(1 \le m < 2\). The 16-term odd series in \((m-1)/(m+1)\) has
remainder below \(2^{-55}\). The coefficient rounding and SSE2
evaluation give an absolute error below \(2^{-42}\) over the
binary32 input exponent range. For positive inputs from 8, eight
Stirling corrections leave a remainder below \(2^{-53}\). The
combined error of the selected finite classes fits within the
relative radius \(2^{-38}\), including rounding the endpoints.
The positive-real Stirling lower bound gives overflow for every
finite input at or above \(2^{122}\). [Logarithm series](https://dlmf.nist.gov/4.6.E4) ·
[Stirling remainder](https://dlmf.nist.gov/5.11.ii)

For the remaining arguments from -32 to 8, at most 40 exact
unit shifts move the argument to \([8,9)\). One Stirling evaluation
and one logarithm of the absolute recurrence product replace the
chain of logarithms. The shifts and factors are exact in binary64.
Product roundoff, the two log errors, and the final subtraction
fit inside an absolute radius of \(2^{-36}\). This absolute bound
keeps the test meaningful when the two terms nearly cancel.

For larger negative nonintegers, reflection uses the exact distance
\(d\) to the nearest integer. The correction is
\(-\log d - \log(\sin(\pi d)/(\pi d))\). The even degree-20
sinc series on \(0 < d \le 1/2\) has remainder below \(2^{-60}\).
The resulting log-gamma magnitude exceeds twice \(1+|x|\) on this
interval, so the relative radius \(2^{-38}\) also covers the
reflected evaluation. [Reflection](https://dlmf.nist.gov/5.5.ii)

The enclosure requires the same rounded bits and overflow status at
both ends and excludes a possible exact result before publishing
INEXACT. Poles, special values, and ambiguous enclosures continue
through Q256. Local SSE control and status are restored before
fallback or publishing effects.

Run `tools/math-inventory` to compare authored specifications and
production assembly against every inventoried math and complex
function. Its counts describe source coverage. The scoped numerical
and application evidence is recorded separately.

The error-function kernel uses the alternating Taylor series for
magnitudes below two, with separately accumulated positive and
negative terms. For the Gaussian tail, a positive continued
fraction is evaluated as exact integer continuants on the common
dyadic scale of the input. At depth 384 its adjacent-convergent
gap is below 2^-151 at x=2, and the positive denominator
polynomials make the gap smaller as x increases. The
`tools/math-range-certificate` command checks the exact endpoint
bound. The tail's exponential retains a separate binary exponent
through final rounding, including in the subnormal range.
[NIST error-function series](https://dlmf.nist.gov/7.6.E1) and
[NIST Gaussian continued fraction](https://dlmf.nist.gov/7.9.E1).

The exit evidence needs measured maximum ULP by function and target,
tests around range and reduction boundaries, and independently generated
special-value cases. Exhaustive binary32 coverage requires a real
enumeration of all relevant bit patterns. Stratified inputs and hard
cases remain sampled evidence. The Lua integration exit still applies
to the full Phase 7 milestone.

References

- [WG14 C17 mathematics clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)
- [WG14 NaN remainder resolution](https://open-std.org/JTC1/SC22/WG14/issues/c11c17/issue0418.html)
- [MPFR reference manual](https://www.mpfr.org/mpfr-current/mpfr.html)
- [Exact conversion and floating environment](0006-exact-numerics.md)

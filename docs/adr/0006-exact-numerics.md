# Phase 5 exact conversion and floating environment

The Phase 5 conversion target is the C-locale strtof, strtod, strtold and
atof family. Each target rounds the exact input directly to its own format.
Integer arithmetic supplies the value bits. Hardware floating arithmetic
applies exception effects through fenv. Float stdio reuses the numerical
core and retains the Phase 4 integer and stream contracts.

| Result | Significand bits | Minimum normal exponent | Maximum exponent |
| --- | ---: | ---: | ---: |
| binary32 | 24 | -126 | 127 |
| binary64 | 53 | -1022 | 1023 |
| x86 extended | 64 | -16382 | 16383 |

## Input and effects

The lexer skips C-locale whitespace and consumes one optional sign. It
recognizes decimal and hexadecimal significands with an optional period,
case-insensitive infinity and quiet NaN, and the applicable decimal or
binary exponent. A hexadecimal prefix needs at least one hex digit,
possibly after the period. An exponent marker and sign are tentative until
an exponent digit is found. A valid parenthesized NaN payload consists of
ASCII letters, digits and underscores and is accepted with canonical quiet
NaN bits. The sign of zero, infinity, and NaN is retained. With no
conversion, return positive zero, store the original input through a
nonnull end pointer and preserve errno. With a conversion, store the first
unconsumed byte through a nonnull end pointer.

Use the current rounding mode. Nearest rounds a tie to even. Directed
rounding uses the input sign to choose whether to increment the magnitude.
Exact conversions preserve errno and existing exception flags. Inexact
results add FE_INEXACT. An inexact tiny result after rounding adds
FE_UNDERFLOW and sets ERANGE. An exponent overflow adds FE_OVERFLOW and
FE_INEXACT and sets ERANGE. Overflow returns infinity when rounded outward
and the largest finite magnitude when rounded inward. Exact subnormal
conversions preserve errno and do not raise underflow. Existing rounding
and mask controls remain in effect throughout conversion.

## Bounded exact arithmetic

Represent the positive magnitude as N times 2 to the power k divided by D.
For decimal input with adjusted exponent k, multiply N or D by 5 to the
power of the absolute value of k. For hexadecimal input D is one. Keep
a truncated decimal significand of at most 22,000 significant digits and
a sticky indication if a later digit is nonzero. Track the entire input
for exponent adjustment and end-pointer reporting. Keep 24 significant
hex digits and a sticky indication for the same reason.

Classify extreme adjusted decimal orders before multiplying by powers of
five. For finite binary80 input the leading decimal order is at most 4932.
Even at that order, the unit of the 22,000-digit retained prefix is finer
than 10 to the power -16446. Every binary80 halfway boundary has a
terminating decimal expansion with at most 16446 fractional places.
Therefore each such boundary lies on the retained decimal grid. Discarded
digits cannot cross a boundary unless the prefix equals that boundary,
where the sticky indication determines the side. The same bound covers
the smaller formats and their directed-rounding boundaries.

Normalize unsigned bignums in little-endian 32-bit limbs with a length
word. Reserve 2560 limbs per temporary. The largest retained decimal
significand fits in 73,083 bits, and decimal classification bounds the
power-of-five denominator before constructing it. Compare bit lengths and
one shifted comparison to find the binary exponent. Choose the output
quantum from the exponent and target precision, clamping to the subnormal
quantum as needed. Scale the numerator or denominator by a power of two
and divide to obtain at most 64 quotient bits. A remainder comparison
against half the divisor resolves nearest rounding. A nonzero remainder
or sticky indication resolves directed rounding and exception effects.
Normalize one final carry before packing the result.

## Floating environment

The generated ABI defines fenv_t as the 28-byte x87 environment followed
by the 32-bit MXCSR value. fexcept_t stores the five standard status bits
in an unsigned 16-bit word. The public rounding constants use the x87
rounding-control encoding. fesetround updates both x87 and SSE controls.
Status queries report the union of the two units. Clearing or saving flags
preserves rounding and exception masks. fesetexceptflag sets flags without
executing an operation that raises a hardware exception. feholdexcept
saves the environment, clears the flags, and masks exceptions.
feupdateenv restores the saved environment and then raises the prior
flags. FE_DFL_ENV restores round-to-nearest and the baseline masked
default. Raising overflow or underflow through an arithmetic operation
can also raise inexact.

## Float stdio and verification

Format binary inputs by converting the significand and binary exponent
to an exact decimal integer with a decimal scale. Round its decimal
digits for f, e, and g at the requested place under the current mode.
Format a with exact hexadecimal digits and apply the requested precision
to those digits. Emit large zero runs through the existing output sink.
Preserve signed zero and handle infinities and NaNs before scaling.
Double arguments use the SysV vector save slots. Long double variadic
arguments use 16-byte-aligned stack slots. Float scanf collects the
maximal input item using its existing one-byte lookahead, validates
the whole item, and converts directly to float, double, or long double.

The printf family renders finite nonzero hexadecimal values with a leading
one, which can become two when explicitly rounded. This policy also
applies to subnormals and extended precision. Inf and NaN use three-letter
spellings with the conversion's case. Preserve their sign and apply
space padding even when zero padding was requested. Output formatting
observes rounding without raising floating exception flags. Scanning an
incomplete floating item fails before assignment or rounding effects.

Independent fixtures should use MPFR with explicit target precision,
exponent bounds and subnormal emulation. Compare bit patterns, end
positions, errno and the expected status flags. Include decimal and hex
ties, adjacent values, near-zero and overflow boundaries, negative zero,
malformed exponents, longest-subject cases, truncated large input and
all four rounding directions. Include published conversion vectors and
record each external source identity. Fast approximation can follow
after the exact path passes.

References

- [WG14 floating environment and string conversion clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)
- [AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI)
- [MPFR reference manual](https://www.mpfr.org/mpfr-current/mpfr.html)

# Numerics design track for phases 5 and 7

Phase 2 integer conversion already separates C-locale syntax from bounded
accumulation. Keep that separation for floating-point parsing. The parsing
front end should return a finite digit sequence with its radix, adjusted
exponent, sign, first unconsumed byte and any discarded-digit information,
or a separate infinity/NaN token. It must stop at the first invalid byte,
keep exponent markers tentative until the first exponent digit, preserve
negative zero, and avoid reading beyond a terminator or an explicit input
bound. Specify decimal, hexadecimal, infinity and NaN spelling and payload
policies before sharing this scanner with scanf. Locale radix support can
be isolated behind a delimiter interface in the locale phase.

The rounding back end should target binary32, binary64 and the AMD64
extended 80-bit format independently. Converting to double and then
narrowing to float introduces double rounding. Construct IEEE significand,
exponent and sign bits directly and use the ABI return registers. Define
the four rounding modes and the rules for exact and inexact subnormals,
tiny results, overflow, infinities and signed zeros before writing the
first assembly. Preserve the existing MXCSR and x87 control state. Keep
floating exception effects and errno updates in a small outer layer.

## First implementation sequence

1. Write a reference model that uses exact Python integers for grammar
   and rounding identities. Independently use MPFR with explicit
   precision, exponent range, subnormal treatment and rounding mode to
   validate numerical outputs. Keep this code in test and development
   paths. Generate vectors from published decimal conversion cases and
   neighbors of halfway values. Record the exact source and revision of
   each vector corpus.
2. Implement a small assembly big integer core with fixed-width limbs.
   Define normalization, maximum limb capacity, quotient/remainder
   invariants and scratch ownership. Use checked size arithmetic. For
   far-out decimal exponents determine overflow or underflow from a
   conservative exponent bound before constructing a power of ten.
   Handle very long inputs by retaining enough leading digits plus a
   sticky indication and a rounding proof. The lexical end pointer still
   tracks the entire valid input, regardless of how many digits the
   numeric back end retains.
3. Build the exact decimal path and the simpler power-of-two hexadecimal
   path before introducing acceleration. A later Eisel-Lemire style fast
   path is permitted only for inputs for which its guard conditions prove
   the same rounding decision. Ambiguous values fall back to exact
   arithmetic. Keep the fast path and exact path independently observable
   in coverage reports.
4. Define formatting as a separate service. Shortest round-trip decimal
   formatting and C printf precision formatting have different contracts.
   Use a permitted shortest-format algorithm such as Ryu only where it
   fits. Keep %f, %e, %g and %a rounding, sign and precision rules explicit.
   Integrate with the Phase 4 output sink and check the stream and
   snprintf length contracts before counting formatted examples as
   passing.
5. For libm, freeze special-value, domain, range and exception behavior
   per function. Keep argument reduction and polynomial evaluation
   independent enough to test across range boundaries. Record ULP
   budgets for each type and domain, and qualify the actual implementation
   with MPFR before any claim of correct rounding. Add reductions and
   binary64/extended precision coverage before expanding into complex
   arithmetic.

Test random and adversarial decimal and hexadecimal forms, values on both
sides of every important range boundary, every supported rounding mode,
malformed exponents and truncated input, negative zero, NaN handling,
overflow and underflow, and the exact end pointer. Preserve bit-pattern
oracles where a floating comparison would hide signed zero or NaN
details. Fuzz both numeric results and consumed lengths, then profile
correctness and performance as separate gates.

References

- [WG14 conversion and floating-point clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)
- [MPFR manual](https://www.mpfr.org/mpfr-current/mpfr.html)
- [Ryu original implementation and publication links](https://github.com/ulfjack/ryu)
- [Open Assembly runtime ABI](../adr/0002-runtime-abi.md)

"""Independent complex arithmetic and mandatory Annex G special values."""

from dataclasses import replace
from fractions import Fraction
from functools import lru_cache

import gmpy2

from math_vectors import (ERANGE, DIVBYZERO, INEXACT, INVALID, UNDERFLOW, default_nan,
                          finite, infinity, rational, signed_zero, two)
from oracle import Expected, expected_atan2, mpfr_operand, multiple_of_quarter_pi, neighbor


FINITE = {"normal", "subnormal", "zero"}
NAN = {"quiet", "signal"}
INVERSE = {"cacos", "casin", "catan", "cacosh", "casinh", "catanh"}


def inverse_special(operation, real, imag, mode):
    fmt = real.fmt
    x, y = real.category, imag.category
    zero, izero = signed_zero(fmt), signed_zero(fmt, imag.negative)
    inf = infinity(fmt)
    nan = Expected(default_nan(fmt), policy="quiet-nan")
    invalid = INVALID if "signal" in (x, y) else 0
    optional = INVALID if not invalid and (x in FINITE or y in FINITE) else 0
    one = finite(fmt, 1)

    if operation in {"casin", "catan"}:
        # Annex G specifies the nonfinite rows through the hyperbolic
        # functions. The imaginary angle becomes the real angle unchanged.
        mapped = {"casin": "casinh", "catan": "catanh"}[operation]
        re, im, allowed = inverse_special(mapped, imag.with_sign(not imag.negative), real, mode)
        return (replace(im, flags=re.flags, error=re.error),
                replace(re, result=re.result.with_sign(not re.result.negative), flags=0, error=0),
                allowed)

    if operation in {"cacos", "cacosh"}:
        if x == "zero" and y in NAN:
            angle = expected_atan2(one, zero, mode)
            if operation == "cacos":
                return replace(angle, flags=angle.flags | invalid), nan, 0
            # C17 adopted DR 471. The angle is pi/2 in magnitude with an
            # unspecified sign. Each possible sign has its own directed bits.
            return (replace(nan, flags=angle.flags | invalid),
                    replace(angle, policy="pi-over-two-either-sign"), 0)
        if x == "inf" or y == "inf":
            if operation == "cacos":
                if y in NAN:
                    return replace(nan, flags=invalid), Expected(inf, policy="class"), 0
                magnitude = Expected(inf.with_sign(not imag.negative))
                if x in NAN:
                    return replace(nan, flags=invalid), magnitude, 0
                return expected_atan2(imag.with_sign(False), real, mode), magnitude, 0
            if x in NAN or y in NAN:
                return Expected(inf, invalid), nan, 0
            angle = expected_atan2(imag, real, mode)
            return Expected(inf, angle.flags), angle, 0
        return replace(nan, flags=invalid), nan, optional

    if operation == "casinh":
        if x == "inf" or y == "inf":
            magnitude = inf.with_sign(real.negative)
            if x in NAN:
                return Expected(magnitude, invalid, policy="class"), nan, 0
            if y in NAN:
                return Expected(magnitude, invalid), nan, 0
            vertical = imag if y == "inf" else izero
            horizontal = inf if x == "inf" else zero
            angle = expected_atan2(vertical, horizontal, mode)
            return Expected(magnitude, angle.flags), angle, 0
        if x in NAN and y == "zero":
            return replace(nan, flags=invalid), Expected(izero), 0
        return replace(nan, flags=invalid), nan, optional

    if operation != "catanh":
        raise ValueError(f"unknown inverse family: {operation}")
    if x == "normal" and y == "zero" and abs(real.value) == 1:
        return Expected(inf.with_sign(real.negative), DIVBYZERO, ERANGE), Expected(izero), 0
    if x == "inf" and y in NAN:
        return Expected(signed_zero(fmt, real.negative), invalid), nan, 0
    if x == "inf" or y == "inf":
        angle = expected_atan2(one.with_sign(imag.negative), zero, mode)
        return Expected(signed_zero(fmt, real.negative), angle.flags | invalid,
                        policy="class" if x in NAN else "exact"), angle, 0
    if x == "zero" and y in NAN:
        return Expected(real, invalid), nan, 0
    return replace(nan, flags=invalid), nan, optional



def special(operation, real, imag, mode):
    fmt = real.fmt
    x, y = real.category, imag.category
    zero = signed_zero(fmt)
    izero = signed_zero(fmt, imag.negative)
    inf = infinity(fmt)
    iinf = infinity(fmt, imag.negative)
    nan = Expected(default_nan(fmt), policy="quiet-nan")
    invalid = INVALID if "signal" in (x, y) else 0
    optional = INVALID if "quiet" in (x, y) and not invalid else 0

    if operation == "clog":
        if x == y == "zero":
            arg = expected_atan2(imag, real, mode)
            return Expected(infinity(fmt, True), arg.flags | DIVBYZERO, ERANGE), arg, 0
        if "inf" in (x, y):
            arg = nan if x in NAN or y in NAN else expected_atan2(imag, real, mode)
            return Expected(inf, arg.flags | invalid), arg, 0
        return replace(nan, flags=invalid), nan, optional
    if operation == "csqrt":
        if y == "inf":
            return Expected(inf, invalid), Expected(iinf), 0
        if x == "inf":
            if real.negative:
                if y in NAN:
                    return replace(nan, flags=invalid), Expected(inf, policy="class"), 0
                return Expected(zero), Expected(iinf), 0
            return Expected(inf, invalid), nan if y in NAN else Expected(izero), 0
        return replace(nan, flags=invalid), nan, optional
    if operation == "cexp":
        if x == "inf":
            if y == "zero":
                return Expected(zero if real.negative else inf), Expected(izero), 0
            if y in FINITE:
                with gmpy2.context(precision=fmt.precision + 32):
                    b = mpfr_operand(imag)
                    signs = gmpy2.is_signed(gmpy2.cos(b)), gmpy2.is_signed(gmpy2.sin(b))
                magnitude = zero if real.negative else inf
                return Expected(magnitude.with_sign(signs[0])), Expected(magnitude.with_sign(signs[1])), 0
            if real.negative:
                return Expected(zero, invalid, policy="class"), Expected(zero, policy="class"), 0
            return Expected(inf, INVALID if y == "inf" else invalid, policy="class"), nan, 0
        if x in NAN and y == "zero":
            return replace(nan, flags=invalid), Expected(izero), 0
        if x in FINITE and y == "inf":
            invalid = INVALID
        return replace(nan, flags=invalid), nan, optional

    # Convert the circular functions to the matching hyperbolic identities.
    # cos(z)=cosh(iz), sin(z)=-i*sinh(iz), tan(z)=-i*tanh(iz).
    if operation in {"ccos", "csin", "ctan"}:
        mapped = {"ccos": "ccosh", "csin": "csinh", "ctan": "ctanh"}[operation]
        re, im, allowed = special(mapped, imag.with_sign(not imag.negative), real, mode)
        if operation == "ccos":
            return re, im, allowed
        return (replace(im, flags=re.flags), replace(re, result=re.result.with_sign(
                not re.result.negative), flags=0), allowed)

    # These rows use the signs fixed by Annex G and accept both signs only
    # for a component the standard expressly leaves unspecified.
    if operation == "ctanh" and x == "inf" and y in FINITE:
        with gmpy2.context(precision=fmt.precision + 32):
            sine = gmpy2.sin(2 * mpfr_operand(imag))
        return Expected(finite(fmt, -1 if real.negative else 1)), Expected(
            signed_zero(fmt, gmpy2.is_signed(sine))), 0
    if operation == "ctanh" and x == "inf" and y not in FINITE:
        return Expected(finite(fmt, -1 if real.negative else 1), invalid), Expected(zero, policy="class"), 0
    if x in FINITE and y == "inf":
        if x == "zero" and operation == "ccosh":
            return replace(nan, flags=INVALID), Expected(zero, policy="class"), 0
        if x == "zero" and operation == "csinh":
            return Expected(zero, INVALID, policy="class"), nan, 0
        return replace(nan, flags=INVALID), nan, 0
    if x in NAN and y == "zero":
        if operation == "ccosh":
            return replace(nan, flags=invalid), Expected(zero, policy="class"), 0
        return replace(nan, flags=invalid), Expected(izero), 0
    raise ValueError(f"no directed special-value oracle for {operation} with {x}, {y}")


def rounded(fmt, value, mode, inexact):
    fraction = Fraction(*map(int, value.as_integer_ratio()))
    result = rational(fmt, fraction, mode, gmpy2.is_signed(value))
    flags = result.flags
    if inexact:
        flags |= INEXACT
        if result.result.field == 0:
            flags |= UNDERFLOW
    error = ERANGE if flags & UNDERFLOW else result.error
    policy = "ulp" if flags == INEXACT else "exact"
    return Expected(result.result, flags, error, policy)


@lru_cache(maxsize=8192)
def bounds(operation, real, imag, precision, exponent):
    values = []
    for direction in (gmpy2.RoundDown, gmpy2.RoundUp):
        with gmpy2.context(precision=precision, round=direction,
                           real_round=direction, imag_round=direction):
            base = gmpy2.mpc(mpfr_operand(real), mpfr_operand(imag))
            if exponent is None:
                result = getattr(gmpy2, operation[1:])(base)
            else:
                power = gmpy2.mpc(*(mpfr_operand(value) for value in exponent))
                result = base ** power
            values.append((result.real, result.imag, result.rc))
    return tuple(values)


def interior(value, direction, precision):
    # MPFR ternary values identify open interval endpoints. Every target
    # rounding transition is a dyadic with at most p+1 significant bits.
    # Move an open bound by one finer representable step, which crosses
    # no such transition when the interval endpoint has greater precision.
    with gmpy2.context(precision=precision + 16):
        value = gmpy2.mpfr(value)
        return gmpy2.next_above(value) if direction > 0 else gmpy2.next_below(value)


def exact_components(operation, real, imag, mode, exponent=None):
    fmt = real.fmt
    for precision in (fmt.precision + 48, 192, 512):
        (rl, il, rc_low), (rh, ih, rc_high) = bounds(operation, real, imag, precision, exponent)
        expected = []
        for index, (lower, upper) in enumerate(((rl, rh), (il, ih))):
            if not gmpy2.is_finite(lower) or not gmpy2.is_finite(upper):
                raise ValueError(f"MPC exceeded its working exponent range for {operation}")
            if bool(rc_low[index]) != bool(rc_high[index]):
                raise ValueError(f"inconsistent MPC exactness for {operation}")
            inexact = bool(rc_low[index])
            if inexact:
                # Use the ternary signs, including if a complex operation
                # returns the same adjacent representable in both modes.
                brackets = []
                for value, rc in ((lower, rc_low[index]), (upper, rc_high[index])):
                    adjacent = interior(value, -rc, precision - 16)
                    interval = (min(value, adjacent), max(value, adjacent))
                    brackets.append(interval)
                lower = max(pair[0] for pair in brackets)
                upper = min(pair[1] for pair in brackets)
                if lower >= upper:
                    raise ValueError(f"inconsistent MPC rounding bracket for {operation}")
                lower = interior(lower, 1, precision)
                upper = interior(upper, -1, precision)
            lo, hi = (rounded(fmt, value, mode, inexact) for value in (lower, upper))
            if lo != hi:
                break
            expected.append(lo)
        if len(expected) == 2:
            return expected
    raise ValueError(f"uncertified {operation} binary{fmt.bits} rounding at {real.low:x},{imag.low:x}")


def expected_pair(operation, real, imag, mode):
    nonfinite = real.category not in FINITE or imag.category not in FINITE
    pole = ((operation == "catanh" and imag.category == "zero" and real.category == "normal" and
             abs(real.value) == 1) or
            (operation == "catan" and real.category == "zero" and imag.category == "normal" and
             abs(imag.value) == 1))
    if operation in INVERSE and (nonfinite or pole):
        return inverse_special(operation, real, imag, mode)
    if nonfinite or (operation == "clog" and real.category == imag.category == "zero"):
        return special(operation, real, imag, mode)
    re, im = exact_components(operation, real, imag, mode)
    return replace(re, flags=re.flags | im.flags, error=re.error or im.error), im, 0


def directed(fmt, operation):
    zero = signed_zero(fmt)
    minsub = finite(fmt, two(fmt.minimum - fmt.precision + 1))
    minnorm = finite(fmt, two(fmt.minimum))
    inf = infinity(fmt)
    nan = default_nan(fmt)
    signaled = replace(nan, low=nan.low ^ (1 << (fmt.precision - 2)) | 1)
    values = tuple(finite(fmt, Fraction(value, 4)) for value in (1, 4, 6, 8, 12, 16, -1, -4, -8, -12))
    one = finite(fmt, 1)
    range_limit = finite(fmt, 128 if fmt.bits == 32 else 1024 if fmt.bits == 64 else 16384)
    large_axis = finite(fmt, two(fmt.maximum - 1))
    inputs = (*values, zero, zero.with_sign(True), minsub, minnorm)

    for real in inputs:
        for imag in inputs:
            yield real, imag, "finite-grid"
    if operation in INVERSE:
        # Probe both approaches to the signed branch points and the
        # combinations where one component is far outside the other's scale.
        horizontal = operation not in {"casinh", "catan"}
        sides = (zero, zero.with_sign(True), minsub, minsub.with_sign(True),
                 minnorm, minnorm.with_sign(True), one, one.with_sign(True), large_axis)
        for sign in (False, True):
            for offset in (-2, -1, 0, 1, 2):
                branch = neighbor(one.with_sign(sign), offset)
                for side in sides:
                    if horizontal:
                        yield branch, side, "inverse-branch-sides"
                    else:
                        yield side, branch, "inverse-branch-sides"
        for large in (large_axis, large_axis.with_sign(True)):
            for side in (*sides, large_axis.with_sign(True)):
                yield large, side, "inverse-scaled-ratios"
                yield side, large, "inverse-scaled-ratios"
        special_values = (zero, zero.with_sign(True), one, one.with_sign(True), inf,
                          inf.with_sign(True), nan, signaled)
        for re in special_values:
            for im in special_values:
                if re.category not in FINITE or im.category not in FINITE:
                    yield re, im, "inverse-nonfinite"
    if operation in {"clog", "csqrt"}:
        for real in (large_axis, large_axis.with_sign(True), one, one.with_sign(True), minsub):
            for imag in (zero, zero.with_sign(True), minsub, minsub.with_sign(True), minnorm, large_axis):
                yield real, imag, "scaled-norm-and-branch"
    if operation in {"cexp", "ccosh", "csinh", "ctanh"}:
        for real in (range_limit, range_limit.with_sign(True)):
            for imag in (zero, minsub, one, large_axis):
                yield real, imag, "exponential-range-and-reduction"
    if operation in {"ccos", "csin", "ctan"}:
        for real in (zero, minsub, one, large_axis):
            for imag in (range_limit, range_limit.with_sign(True), one):
                yield real, imag, "exponential-range-and-reduction"
    circular = {"cexp": "imag", "ccos": "real", "csin": "real", "ccosh": "imag",
                "csinh": "imag", "ctan": "real", "ctanh": "imag"}
    if operation in circular:
        # The odd half-multiples of pi are tangent poles. Axis values and
        # adjacent inputs also stress cancellation of sin/cos factors.
        for multiplier in (2, 6, 1026, 1 << 20):
            point = multiple_of_quarter_pi(fmt, multiplier)
            for offset in (-1, 0, 1):
                phase = neighbor(point, offset)
                for phase in (phase, phase.with_sign(True)):
                    for other in (zero, minsub, one):
                        if circular[operation] == "real":
                            yield phase, other, "range-reduction-and-poles"
                        else:
                            yield other, phase, "range-reduction-and-poles"
    if operation in {"cexp", "ccosh", "csinh", "ctanh"}:
        for real, imag in ((one, inf), (one, inf.with_sign(True)), (signaled, zero),
                           (nan, zero), (one, nan)):
            if operation == "ctanh" and imag.category == "quiet":
                continue
            if operation in {"ccosh", "csinh", "ctanh"} and imag.category == "quiet":
                continue
            yield real, imag, "nonfinite"
    if operation in {"cexp", "clog", "csqrt", "ctanh"}:
        for real in (inf, inf.with_sign(True)):
            for imag in (zero, zero.with_sign(True), one, one.with_sign(True), inf, nan):
                yield real, imag, "nonfinite"
    if operation in {"clog", "csqrt"}:
        for real in (zero, one, inf, nan, signaled):
            for imag in (inf, nan, signaled):
                yield real, imag, "nonfinite"
    if operation in {"ccos", "csin", "ctan"}:
        for real, imag in ((inf, one), (inf.with_sign(True), one), (zero, inf)):
            # Imaginary infinities for sine/cosine need a separate sign table.
            if real.category == "zero" and operation != "ctan":
                continue
            yield real, imag, "nonfinite"

"""MPC and exact quadrant oracles for the binary complex power ABI."""

from dataclasses import replace
from fractions import Fraction

from complex_math import FINITE, NAN, exact_components
from math_vectors import (DOWN, UP, EDOM, INVALID, DIVBYZERO, UNDERFLOW, OVERFLOW, INEXACT,
                          default_nan, finite, infinity, signed_zero, two)
from oracle import MODES, Expected, expected_pow

EXCEPTIONS = INVALID | DIVBYZERO | UNDERFLOW | OVERFLOW | INEXACT


def axis(real, imag):
    if imag.category == "zero":
        return real.with_sign(False), (-2 if imag.negative else 2) if real.negative else 0
    if real.category == "zero":
        return imag.with_sign(False), -1 if imag.negative else 1
    if real.category == imag.category == "inf":
        quarter_turn = Fraction(3 if real.negative else 1, 2)
        return real.with_sign(False), -quarter_turn if imag.negative else quarter_turn
    return None


def approximate_component(expected):
    # The published complex-power bound applies to finite nonzero
    # component magnitudes. Class transitions, including directed
    # overflow to max-finite, retain their exact representation checks.
    if expected.result.category in {"normal", "subnormal"} and not expected.flags & OVERFLOW:
        return replace(expected, policy="ulp")
    return expected


def expected_power(real, imag, exponent, mode):
    fmt = real.fmt
    wr, wi = exponent
    zero = Expected(signed_zero(fmt), policy="class")
    one = finite(fmt, 1)
    nan = Expected(default_nan(fmt), policy="quiet-nan")
    categories = [part.category for part in (real, imag, wr, wi)]
    if "signal" in categories:
        return replace(nan, flags=INVALID), nan, 0
    if wr.category == wi.category == "zero":
        return Expected(one), zero, 0
    if wi.category == imag.category == "zero" and not real.negative and real.category not in NAN:
        wanted = expected_pow(real, wr, mode)
        return wanted, zero, 0
    if "quiet" in categories:
        return nan, nan, 0

    aligned = axis(real, imag)
    if aligned and wi.category == "zero" and wr.category in FINITE:
        magnitude, quarter_turn = aligned
        quadrant = Fraction(quarter_turn) * wr.value
        if quadrant.denominator == 1:
            index = int(quadrant) % 4
            direction = {DOWN: UP, UP: DOWN}.get(mode, mode) if index >= 2 else mode
            amount = expected_pow(magnitude, wr, direction)
            amount = replace(amount, result=amount.result.with_sign(index >= 2))
            if magnitude != one:
                amount = approximate_component(amount)
            optional = EXCEPTIONS & ~amount.flags
            if index % 2 == 0:
                return amount, zero, optional
            return replace(zero, flags=amount.flags, error=amount.error), amount, optional
    if "inf" in categories or real.category == imag.category == "zero":
        return replace(nan, flags=INVALID, error=EDOM), nan, 0

    re, im = map(approximate_component, exact_components("cpow", real, imag, mode, exponent))
    required = re.flags | im.flags
    return replace(re, flags=required, error=re.error or im.error), im, EXCEPTIONS & ~required


def inputs(fmt, rng, random_count):
    zero = signed_zero(fmt)
    negzero = zero.with_sign(True)
    one = finite(fmt, 1)
    two_value = finite(fmt, 2)
    half = finite(fmt, Fraction(1, 2))
    quarter = finite(fmt, Fraction(1, 4))
    unit = finite(fmt, Fraction(5, 4))
    minsub = finite(fmt, two(fmt.minimum - fmt.precision + 1))
    range_exponent = finite(fmt, fmt.maximum + 8)
    inf = infinity(fmt)
    nan = default_nan(fmt)
    signal = replace(nan, low=(nan.low ^ (1 << (fmt.precision - 2))) | 1)

    yield two_value, zero, (one, zero), "scalar-identity"
    for real in (zero, two_value, inf):
        for wr in (half, two_value, two_value.with_sign(True)):
            yield real, negzero, (wr, zero), "scalar-range-and-pole"
    for imag in (zero, negzero):
        for wr in (half, half.with_sign(True), one, two_value, finite(fmt, 3), finite(fmt, 17)):
            yield unit.with_sign(True), imag, (wr, zero), "exact-cut-quadrants"
        for wi in (quarter, quarter.with_sign(True), one):
            yield unit.with_sign(True), imag, (half, wi), "signed-branch-cut"
    for imag in (minsub, minsub.with_sign(True)):
        yield one.with_sign(True), imag, (half, zero), "adjacent-to-branch-cut"
        yield two_value, zero, (range_exponent, imag), "one-component-overflow-rescue"
        yield two_value, zero, (zero, imag), "one-component-underflow"
        yield one, imag, (two_value, minsub), "near-cardinal"

    for exponent in (fmt.precision + 2, fmt.maximum // 2, fmt.maximum - 2):
        huge = finite(fmt, two(exponent))
        residual = finite(fmt, two(-(exponent // 2 + 1)))
        for negative in (False, True):
            signed = huge.with_sign(negative)
            yield two_value, zero, (zero, signed), "huge-noncardinal-phase"
            yield unit, zero, (one, signed), "huge-noncardinal-phase"
            yield one, residual, (signed, zero), "huge-near-unit-base"
            yield zero, one.with_sign(negative), (huge, zero), "huge-cardinal-exact-phase"
        yield one.with_sign(True), zero, (huge, zero), "huge-cardinal-exact-phase"

    for real, imag, exponent in (
        (nan, one, (zero, negzero)),
        (one, zero, (nan, zero)),
        (nan, one, (half, quarter)),
        (one, one, (half, nan)),
        (signal, one, (half, quarter)),
        (zero, zero, (zero, one)),
        (one, one, (one, inf)),
        (inf, one, (half, quarter)),
        (inf.with_sign(True), zero, (half, zero)),
        (inf.with_sign(True), negzero, (half, zero)),
        (inf, inf, (two_value, zero)),
        (zero, inf, (one, zero)),
    ):
        yield real, imag, exponent, "special-domain-and-limits"

    for _ in range(random_count):
        values = [finite(fmt, Fraction(rng.randrange(-2048, 2049), 256)) for _ in range(4)]
        if values[0].category == values[1].category == "zero":
            values[0] = one
        yield values[0], values[1], (values[2], values[3]), "seeded-complex-dyadics"


def power_rows(fmt, rng, random_count):
    for real, imag, exponent, label in inputs(fmt, rng, random_count):
        for mode in MODES:
            re, im, optional = expected_power(real, imag, exponent, mode)
            yield real, imag, exponent, mode, label, re, im, optional

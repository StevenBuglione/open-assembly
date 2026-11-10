"""Independent MPFR target-rounding oracle and range boundary inputs."""

from dataclasses import dataclass
from fractions import Fraction
from functools import lru_cache
from itertools import product
from pathlib import Path
import random
import re
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from math_vectors import (DIVBYZERO, EDOM, ERANGE, FORMATS, INEXACT, INVALID, MODES, MPFR_MODES,
                          NEAREST, OVERFLOW, UNDERFLOW, Number, default_nan, finite, infinity,
                          mpfr_real, rational, representation, signed_zero, two)
import gmpy2

OPERATIONS = re.findall(r"^OP2?\(([a-z0-9]+)\)$",
                        Path(__file__).with_name("operations.def").read_text(), re.MULTILINE)
OP_ID = {name: index for index, name in enumerate(OPERATIONS)}
LOGS = {"log2", "log", "log10"}
TRIG = {"sin", "cos", "tan"}
INVERSE = {"asin", "acos", "atan"}
HYPERBOLIC = {"sinh", "cosh", "tanh"}
BINARY = {"pow", "atan2"}
INVERSE_HYPERBOLIC = {"asinh", "acosh", "atanh"}
ERROR_FUNCTIONS = {"erf", "erfc"}
GAMMA = {"tgamma", "lgamma"}
FUNCTION = {name: getattr(gmpy2, name) for name in OPERATIONS
            if name not in {"pow", "tgamma", "lgamma"}}
REQUEST = struct.Struct("<QHHIQHHI")
OBSERVATION = struct.Struct("<QHHi")
SEED = 0x5452414E
TEST_ERRNO = 947
CHANGED_CONTROL = 0x8000


@dataclass(frozen=True)
class Expected:
    result: Number
    flags: int = 0
    error: int = 0
    policy: str = "exact"


@dataclass(frozen=True)
class Case:
    operation: str
    argument: Number
    mode: int
    label: str
    expected: Expected
    operand: Number | None = None

    @property
    def seed(self):
        return next(flag for flag in (DIVBYZERO, UNDERFLOW, OVERFLOW, INVALID, INEXACT)
                    if not self.expected.flags & flag)

    def wire(self):
        other = self.operand or signed_zero(self.argument.fmt)
        return REQUEST.pack(self.argument.low, self.argument.high, self.mode, OP_ID[self.operation],
                            other.low, other.high, self.seed, 0)

    def description(self):
        return {"family": self.operation, "input": bits(self.argument), "mode": self.mode,
                "stratum": self.label, "expected": bits(self.expected.result),
                "operand": bits(self.operand) if self.operand is not None else None,
                "flags": self.expected.flags, "errno": self.expected.error,
                "policy": self.expected.policy}


def bits(number):
    return f"{number.high:04x}:{number.low:016x}"


def ordinal(number):
    magnitude = (number.field << (number.fmt.precision - 1)) | number.fraction
    return -magnitude if number.negative else magnitude


def neighbor(number, offset):
    code = ordinal(number) + offset
    width = number.fmt.precision - 1
    magnitude = abs(code)
    negative = code < 0 or code == 0 and number.negative
    return representation(number.fmt, negative, magnitude >> width, magnitude & ((1 << width) - 1))


def is_power_two(value):
    return value > 0 and value & (value - 1) == 0


@lru_cache
def decimal_powers(fmt):
    result = {}
    exponent, factor = 0, 1
    while factor.bit_length() <= fmt.precision:
        result[10 ** exponent] = exponent
        factor *= 5
        exponent += 1
    return result


def exact_exp2(fmt, exponent, mode):
    # At these caps the result remains beyond the full range in every target mode.
    rounded = rational(fmt, two(max(-50000, min(50000, exponent))), mode, crosscheck=True)
    return Expected(rounded.result, rounded.flags, rounded.error)


def mpfr_operand(argument):
    if argument.category == "zero":
        return gmpy2.mpfr("-0" if argument.negative else "0")
    if argument.category == "inf":
        return gmpy2.mpfr("-inf" if argument.negative else "inf")
    return mpfr_real(argument.value)


def mpfr_target(op, arg, mode, other=None):
    fmt = arg.fmt
    with gmpy2.context(precision=fmt.precision):
        operand = mpfr_operand(arg)
        second = mpfr_operand(other) if other is not None else None
    with gmpy2.context(precision=fmt.precision, round=MPFR_MODES[mode],
                       emin=fmt.minimum - fmt.precision + 2, emax=fmt.maximum + 1,
                       subnormalize=True) as context:
        if op == "pow":
            output = operand ** second
        elif op == "tgamma":
            output = gmpy2.gamma(operand)
        elif op == "lgamma":
            output, _ = gmpy2.lgamma(operand)
        elif second is not None:
            output = FUNCTION[op](operand, second)
        else:
            output = FUNCTION[op](operand)
        overflow, inexact = context.overflow, context.inexact
    if gmpy2.is_infinite(output):
        if not overflow:
            raise ValueError(f"MPFR unexpected infinity for {op} {bits(arg)}")
        return Expected(infinity(fmt, gmpy2.is_signed(output)), OVERFLOW | INEXACT, ERANGE)
    numerator, denominator = output.as_integer_ratio()
    result = finite(fmt, Fraction(int(numerator), int(denominator)), gmpy2.is_signed(output))
    if overflow:
        return Expected(result, OVERFLOW | INEXACT, ERANGE)
    if op in BINARY | GAMMA and not inexact:
        return Expected(result)
    if result.field == 0:
        return Expected(result, UNDERFLOW | INEXACT, ERANGE)
    return Expected(result, INEXACT, policy="ulp")


def expected(op, arg, mode):
    fmt, category = arg.fmt, arg.category
    if category == "quiet":
        return Expected(arg)
    if category == "signal":
        return Expected(arg.quiet(), INVALID)
    if op in LOGS:
        if category == "zero":
            return Expected(infinity(fmt, True), DIVBYZERO, ERANGE)
        if arg.negative:
            return Expected(default_nan(fmt), INVALID, EDOM, "quiet-nan")
        if category == "inf":
            return Expected(arg)
        value = arg.value
        if value == 1:
            return Expected(signed_zero(fmt))
        if op == "log2" and is_power_two(value.numerator) and is_power_two(value.denominator):
            return Expected(finite(fmt, value.numerator.bit_length() - value.denominator.bit_length()))
        if op == "log10" and value in decimal_powers(fmt):
            return Expected(finite(fmt, decimal_powers(fmt)[value]))
    elif op in {"exp", "exp2", "expm1"}:
        if category == "inf":
            if not arg.negative:
                return Expected(arg)
            return Expected(finite(fmt, -1) if op == "expm1" else signed_zero(fmt))
        if category == "zero":
            return Expected(arg if op == "expm1" else finite(fmt, 1))
        value = arg.value
        if op == "exp2" and value.denominator == 1:
            return exact_exp2(fmt, int(value), mode)
    elif op == "log1p":
        if category == "zero":
            return Expected(arg)
        if arg.value == -1:
            return Expected(infinity(fmt, True), DIVBYZERO, ERANGE)
        if arg.value < -1:
            return Expected(default_nan(fmt), INVALID, EDOM, "quiet-nan")
        if category == "inf":
            return Expected(arg)
    elif op in INVERSE:
        if op != "atan" and abs(arg.value) > 1:
            return Expected(default_nan(fmt), INVALID, EDOM, "quiet-nan")
        if category == "zero" and op != "acos":
            return Expected(arg)
        if op == "acos" and arg.value == 1:
            return Expected(signed_zero(fmt))
    elif op in HYPERBOLIC:
        if category == "zero":
            return Expected(finite(fmt, 1) if op == "cosh" else arg)
        if category == "inf":
            if op == "tanh":
                return Expected(finite(fmt, -1 if arg.negative else 1))
            return Expected(infinity(fmt) if op == "cosh" else arg)
    elif op == "asinh":
        if category in {"zero", "inf"}:
            return Expected(arg)
    elif op == "acosh":
        if arg.value < 1:
            return Expected(default_nan(fmt), INVALID, EDOM, "quiet-nan")
        if arg.value == 1:
            return Expected(signed_zero(fmt))
        if category == "inf":
            return Expected(arg)
    elif op == "atanh":
        if category == "zero":
            return Expected(arg)
        if abs(arg.value) > 1:
            return Expected(default_nan(fmt), INVALID, EDOM, "quiet-nan")
        if abs(arg.value) == 1:
            return Expected(infinity(fmt, arg.negative), DIVBYZERO, ERANGE)
    elif op in ERROR_FUNCTIONS:
        if category == "zero":
            return Expected(arg if op == "erf" else finite(fmt, 1))
        if category == "inf":
            if op == "erf":
                return Expected(finite(fmt, -1 if arg.negative else 1))
            return Expected(finite(fmt, 2) if arg.negative else signed_zero(fmt))
    elif op in GAMMA:
        if category == "inf":
            if op == "tgamma" and arg.negative:
                return Expected(default_nan(fmt), INVALID, EDOM, "quiet-nan")
            return Expected(infinity(fmt))
        if category == "zero":
            return Expected(infinity(fmt, arg.negative and op == "tgamma"), DIVBYZERO, ERANGE)
        value = arg.value
        if value < 0 and value.denominator == 1:
            if op == "tgamma":
                return Expected(default_nan(fmt), INVALID, EDOM, "quiet-nan")
            return Expected(infinity(fmt), DIVBYZERO, ERANGE)
        if op == "lgamma" and value in {1, 2}:
            return Expected(signed_zero(fmt))
    else:
        if category == "inf":
            return Expected(default_nan(fmt), INVALID, EDOM, "quiet-nan")
        if category == "zero":
            return Expected(finite(fmt, 1) if op == "cos" else arg)
    return mpfr_target(op, arg, mode)


def expected_pow(base, exponent, mode):
    fmt = base.fmt
    signals = [operand for operand in (base, exponent) if operand.category == "signal"]
    if signals:
        return Expected(signals[0].quiet(), INVALID, policy="quiet-nan" if len(signals) == 2 else "exact")
    one = finite(fmt, 1)
    if exponent.category == "zero" or base == one:
        return Expected(one)
    quiet = [operand for operand in (base, exponent) if operand.category == "quiet"]
    if quiet:
        return Expected(quiet[0], policy="quiet-nan" if len(quiet) == 2 else "exact")
    magnitude = abs(base.value)
    if exponent.category == "inf":
        if magnitude == 1:
            return Expected(one)
        return Expected(infinity(fmt) if (magnitude > 1) != exponent.negative else signed_zero(fmt))
    power = exponent.value
    integer = power.denominator == 1
    negative = base.negative and integer and bool(int(power) & 1)
    if base.category == "zero":
        if exponent.negative:
            return Expected(infinity(fmt, negative), DIVBYZERO, ERANGE)
        return Expected(signed_zero(fmt, negative))
    if base.category == "inf":
        return Expected(signed_zero(fmt, negative) if exponent.negative else infinity(fmt, negative))
    if base.negative and not integer:
        return Expected(default_nan(fmt), INVALID, EDOM, "quiet-nan")
    return mpfr_target("pow", base, mode, exponent)


def expected_atan2(vertical, horizontal, mode):
    operands = (vertical, horizontal)
    signals = [operand for operand in operands if operand.category == "signal"]
    nans = [operand for operand in operands if operand.category in {"signal", "quiet"}]
    if nans:
        chosen = (signals or nans)[0]
        return Expected(chosen.quiet(), INVALID if signals else 0,
                        policy="quiet-nan" if len(nans) == 2 else "exact")
    return mpfr_target("atan2", vertical, mode, horizontal)


def special_inputs(fmt):
    max_field = 2 * fmt.maximum + 1
    mask = (1 << (fmt.precision - 1)) - 1
    quiet = 1 << (fmt.precision - 2)
    for negative in (False, True):
        for label, field, fraction in (
            ("zero", 0, 0), ("least-subnormal", 0, 1), ("last-subnormal", 0, mask),
            ("minimum-normal", 1, 0), ("next-normal", 1, 1),
            ("largest", max_field - 1, mask), ("largest-previous", max_field - 1, mask - 1),
            ("infinity", max_field, 0), ("quiet-nan", max_field, quiet | 0x243),
            ("signaling-nan", max_field, 0x55), ("last-signaling-nan", max_field, quiet - 1),
        ):
            yield representation(fmt, negative, field, fraction), label


def around(value, radius, label):
    for offset in range(-radius, radius + 1):
        yield neighbor(value, offset), label


def exp2_inputs(fmt):
    least_power = fmt.minimum - fmt.precision + 1
    for power in (least_power - 1, least_power, least_power + 1, fmt.minimum - 1, fmt.minimum,
                  fmt.minimum + 1, -100, -2, -1, 0, 1, 2, 100, fmt.maximum - 1,
                  fmt.maximum, fmt.maximum + 1):
        yield from around(finite(fmt, power), 4, "exp2-integer-threshold")
        yield finite(fmt, Fraction(2 * power + 1, 2)), "exp2-half-integer"
    for exponent in (-81, -80, -79, -fmt.precision - 1, -fmt.precision, -fmt.precision + 1):
        for sign in (-1, 1):
            yield from around(finite(fmt, sign * two(exponent)), 2, "exp2-near-one")


def log_inputs(fmt):
    least_power = fmt.minimum - fmt.precision + 1
    for exponent in sorted({least_power, least_power + 1, fmt.minimum - 1, fmt.minimum,
                            fmt.minimum + 1, -100, -10, -2, -1, 0, 1, 2, 10, 100,
                            fmt.maximum - 1, fmt.maximum}):
        center = finite(fmt, two(exponent))
        yield from around(center, 4 if exponent == 0 else 2, "log2-power-boundary")
    powers = decimal_powers(fmt)
    for value in [*powers, 10 * max(powers), Fraction(1, 10), Fraction(1, 100)]:
        center = rational(fmt, value).result
        yield from around(center, 2, "log10-power-boundary")
    for numerator in (3, 5, 7, 13, 17, 257):
        yield finite(fmt, Fraction(numerator, 2)), "log-mantissa"


def exact_fraction(number):
    numerator, denominator = number.as_integer_ratio()
    return Fraction(int(numerator), int(denominator))


def multiple_of_quarter_pi(fmt, numerator):
    # Certify that both directed endpoint roundings select the same input bits.
    roundings = (gmpy2.RoundDown, gmpy2.RoundUp)
    bounds = []
    for mode in roundings:
        with gmpy2.context(precision=fmt.precision + 180, round=mode):
            value = gmpy2.const_pi() * numerator / 4
        bounds.append(rational(fmt, exact_fraction(value)).result)
    if bounds[0] != bounds[1]:
        raise ValueError(f"quadrant input boundary is ambiguous for binary{fmt.bits}")
    return bounds[0]


def candidate_reduction_boundaries(fmt, rng):
    # Seek the closest sampled residues at integer and half-integer boundaries.
    # Select independently from MPFR reduction values, without a candidate table.
    for exponent in sorted({31, 63, fmt.maximum // 2, fmt.maximum - 3}):
        best = {True: (Fraction(1), None), False: (Fraction(1), None)}
        with gmpy2.context(precision=exponent + fmt.precision + 160):
            factor = 2 / gmpy2.const_pi()
            for _ in range(144):
                fraction = rng.getrandbits(fmt.precision - 1)
                value = representation(fmt, False, fmt.maximum + exponent, fraction)
                quotient = mpfr_real(value.value) * factor
                remainder = exact_fraction(quotient - gmpy2.floor(quotient))
                distances = {True: min(remainder, 1 - remainder), False: abs(remainder - Fraction(1, 2))}
                for integer, distance in distances.items():
                    if distance < best[integer][0]:
                        best[integer] = distance, value
        for integer, (_, number) in best.items():
            label = "trig-huge-near-axis" if integer else "trig-huge-near-quadrant-tie"
            if number is None:
                raise ValueError("missing MPFR residue case")
            for sign in (False, True):
                yield from around(number.with_sign(sign), 2, label)


def trig_inputs(fmt, rng):
    for exponent in (-81, -80, -79, -fmt.precision, -(fmt.precision // 2),
                     0, 1, 10, 20, 63, fmt.maximum - 1):
        for sign in (-1, 1):
            yield from around(finite(fmt, sign * two(exponent)), 2, "trig-power-neighborhood")
    for factor in (1, 2, 3, 4, 5, 6, 7, 8, 12, 17, 31, 255, 1024,
                   (1 << 24) + 1, (1 << 53) + 1, (1 << (fmt.maximum - 3)) + 1):
        center = multiple_of_quarter_pi(fmt, factor)
        for sign in (False, True):
            label = "trig-axis" if factor % 2 == 0 else "trig-quadrant-tie"
            yield from around(center.with_sign(sign), 4, label)
    yield from candidate_reduction_boundaries(fmt, rng)


def random_inputs(fmt, rng, count):
    exponent_fields = [0, 1, fmt.maximum - 1, fmt.maximum, fmt.maximum + 1, 2 * fmt.maximum]
    for index in range(count):
        field = exponent_fields[index % len(exponent_fields)] if index % 2 else rng.randrange(2 * fmt.maximum + 1)
        fraction = rng.getrandbits(fmt.precision - 1)
        yield representation(fmt, bool(rng.getrandbits(1)), field, fraction), "seeded-stratified"


def exp_inputs(fmt):
    yield from exp2_inputs(fmt)
    least_power = fmt.minimum - fmt.precision + 1
    for power in (least_power - 1, least_power, fmt.minimum, -fmt.precision - 2,
                  -fmt.precision - 1, -fmt.precision, -fmt.precision + 1, -1,
                  fmt.maximum, fmt.maximum + 1):
        bounds = []
        for direction in (gmpy2.RoundDown, gmpy2.RoundUp):
            with gmpy2.context(precision=fmt.precision + 180, round=direction):
                magnitude = gmpy2.const_log2() * abs(power)
            bounds.append(rational(fmt, -exact_fraction(magnitude) if power < 0 else
                                   exact_fraction(magnitude)).result)
        if bounds[0] != bounds[1]:
            raise ValueError("ln(2) boundary did not select a unique input")
        yield from around(bounds[0], 4, "exp-ln2-boundary")


def log1p_inputs(fmt):
    yield from around(finite(fmt, -1), 10, "log1p-pole-boundary")
    yield from log_inputs(fmt)
    for exponent in (-81, -80, -79, -fmt.precision - 1, -fmt.precision,
                     -fmt.precision + 1, -8, -2):
        for sign in (-1, 1):
            yield from around(finite(fmt, sign * two(exponent)), 4, "log1p-tiny")


def power_inputs(fmt, rng, random_count):
    special = [value for value, _ in special_inputs(fmt)
               if value.category in {"zero", "inf", "quiet", "signal"}]
    one = finite(fmt, 1)
    half = finite(fmt, Fraction(1, 2))
    two_input = finite(fmt, 2)
    magnitude = [one, one.with_sign(True), half, half.with_sign(True), two_input,
                 two_input.with_sign(True), neighbor(one, -1), neighbor(one, 1)]
    exponent_values = [finite(fmt, integer) for integer in (-17, -8, -3, -2, -1, 1, 2, 3, 8, 17)]
    exponent_values += [half, half.with_sign(True), finite(fmt, Fraction(3, 2)), finite(fmt, Fraction(-3, 2))]
    for base, exponent in product(special + magnitude, special + exponent_values):
        yield base, exponent, "pow-special-signs"
    for value, power in ((4, Fraction(1, 2)), (9, Fraction(1, 2)), (81, Fraction(1, 4)),
                         (16, Fraction(3, 4)), (25, Fraction(1, 2)), (81, Fraction(-1, 4)),
                         (Fraction(9, 4), Fraction(1, 2)), (Fraction(9, 16), Fraction(3, 2)),
                         (81, Fraction(3, 4)), (Fraction(625, 16), Fraction(1, 4)),
                         (3, 9), (5, 10), (-3, 9), (-5, -3), (Fraction(5, 8), 5)):
        yield finite(fmt, value), finite(fmt, power), "pow-exact-rational"
    least = fmt.minimum - fmt.precision + 1
    for integer in (least - 1, least, least + 1, fmt.minimum, fmt.maximum, fmt.maximum + 1):
        for exponent, _ in around(finite(fmt, integer), 3, ""):
            yield two_input, exponent, "pow-range-boundary"
    for integer in (-(1 << (fmt.precision - 1)), 1 << (fmt.precision - 1), 1 << fmt.precision):
        for exponent, _ in around(finite(fmt, integer), 3, ""):
            for base in magnitude:
                yield base, exponent, "pow-near-one-and-parity"
    bases = list(random_inputs(fmt, rng, random_count))
    powers = list(random_inputs(fmt, rng, random_count))
    for (base, _), (exponent, _) in zip(bases, powers, strict=True):
        yield base, exponent, "pow-seeded-stratified"


def inverse_inputs(fmt):
    for center in (Fraction(1, 16), Fraction(1, 4), Fraction(3, 8), Fraction(7, 16),
                   Fraction(1, 2), Fraction(3, 4), 1, Fraction(3, 2), 2, 4, 8):
        for sign in (-1, 1):
            yield from around(finite(fmt, sign * center), 5, "inverse-reduction-boundary")
    for exponent in (-81, -80, -79, -fmt.precision, fmt.precision, 96, fmt.maximum - 2):
        for sign in (-1, 1):
            yield from around(finite(fmt, sign * two(exponent)), 3, "inverse-tiny-or-huge")


def hyperbolic_inputs(fmt):
    yield from exp_inputs(fmt)
    yield from inverse_inputs(fmt)
    for scale in (fmt.maximum + 2, Fraction(fmt.precision, 2),
                  Fraction(fmt.precision + 1, 2), Fraction(fmt.precision + 2, 2)):
        for sign in (-1, 1):
            with gmpy2.context(precision=fmt.precision + 180):
                x = mpfr_real(Fraction(scale * sign)) * gmpy2.const_log2()
            yield from around(rational(fmt, exact_fraction(x)).result, 5, "hyperbolic-range-or-saturation")


def atan2_inputs(fmt, rng, random_count):
    special = [value for value, _ in special_inputs(fmt)
               if value.category in {"zero", "inf", "quiet", "signal"}]
    one = finite(fmt, 1)
    small = representation(fmt, False, 0, 1)
    large = representation(fmt, False, 2 * fmt.maximum, (1 << (fmt.precision - 1)) - 1)
    ordinary = [one, one.with_sign(True), small, small.with_sign(True),
                large, large.with_sign(True), neighbor(one, -1), neighbor(one, 1)]
    for y, x in product(special + ordinary, repeat=2):
        yield y, x, "atan2-quadrants"
    for exponent in (fmt.minimum, -fmt.precision - 1, -fmt.precision,
                     -fmt.precision + 1, -80, -2, 0, 2, fmt.precision, fmt.maximum):
        for sign in (-1, 1):
            value = finite(fmt, sign * two(exponent))
            for y, _ in around(value, 3, ""):
                for x in ordinary[:2] + ordinary[4:6]:
                    yield y, x, "atan2-ratio-boundary"
                    yield x, y, "atan2-ratio-boundary"
    first = random_inputs(fmt, rng, random_count)
    second = random_inputs(fmt, rng, random_count)
    for (y, _), (x, _) in zip(first, second, strict=True):
        yield y, x, "atan2-seeded-stratified"


def inverse_hyperbolic_inputs(fmt):
    yield from inverse_inputs(fmt)
    yield from log_inputs(fmt)
    for center in (0, 1, -1, Fraction(1, 2), Fraction(-1, 2), 2, 4, 16):
        yield from around(finite(fmt, center), 8, "inverse-hyperbolic-boundary")


def crossing(fmt, low, high, value, threshold, increasing):
    for _ in range(fmt.precision + 96):
        middle = (low + high) / 2
        if (value(middle) < threshold) == increasing:
            low = middle
        else:
            high = middle
    left, right = (rational(fmt, exact_fraction(bound)).result for bound in (low, high))
    if left != right:
        raise ValueError("high-precision boundary did not select a unique input")
    return left


def error_inputs(fmt):
    yield from inverse_inputs(fmt)
    for center in (Fraction(1, 8), Fraction(1, 2), Fraction(3, 4), 1, Fraction(5, 4),
                   2, 3, 4, 5, 6, 8, 10, 16, 24, 32, 64, 128, 256):
        for sign in (-1, 1):
            yield from around(finite(fmt, sign * center), 5, "error-function-range")
    least = fmt.minimum - fmt.precision + 1
    for exponent in (-fmt.precision, -fmt.precision - 1, fmt.minimum, least, least - 1):
        with gmpy2.context(precision=fmt.precision + 180):
            target = mpfr_real(two(exponent))
            top = gmpy2.sqrt(gmpy2.mpfr(-exponent + fmt.precision + 8))
            center = crossing(fmt, gmpy2.mpfr(0), top, gmpy2.erfc, target, False)
        for sign in (False, True):
            yield from around(center.with_sign(sign), 8, "erfc-saturation-and-tiny-boundary")


def gamma_inputs(fmt):
    for center in (Fraction(1, 4), Fraction(1, 2), Fraction(3, 4), 1, Fraction(5, 4),
                   Fraction(3, 2), Fraction(7, 4), 2, Fraction(9, 4), 3, 4, 5, 6, 8, 9,
                   10, 12, 16, 21, 24, 32, 35, 36, 100, 171, 172, 1755, 1756, 4096):
        for sign in (-1, 1):
            yield from around(finite(fmt, sign * center), 4, "gamma-factorial-or-pole")
    with gmpy2.context(precision=fmt.precision + 180):
        one = gmpy2.mpfr(1)
        loggamma = lambda x: gmpy2.lgamma(x)[0]
        threshold = (fmt.maximum + 1) * gmpy2.const_log2()
        center = crossing(fmt, one * 2, one * 4096, loggamma, threshold, True)
        near_negative = int(center.value)
        maximum = representation(fmt, False, 2 * fmt.maximum, (1 << (fmt.precision - 1)) - 1)
        huge = mpfr_real(maximum.value)
        huge_center = rational(fmt, exact_fraction(huge / gmpy2.log(huge))).result
        near_roots = []
        for lower in (-3, -4, -5):
            middle = gmpy2.mpfr(lower) + one / 2
            near_roots.append(crossing(fmt, gmpy2.mpfr(lower) + one / 65536,
                                       middle, loggamma, gmpy2.mpfr(0), False))
            near_roots.append(crossing(fmt, middle, gmpy2.mpfr(lower + 1) - one / 65536,
                                       loggamma, gmpy2.mpfr(0), True))
    yield from around(center, 8, "gamma-overflow-boundary")
    yield from around(huge_center, 8, "lgamma-large-range")
    for root in near_roots:
        yield from around(root, 8, "lgamma-negative-zero-neighborhood")
    for step in (-10, -4, -2, -1, 0, 1, 2, 4, 10, 24, 100):
        for part in (Fraction(1, 4), Fraction(1, 2), Fraction(3, 4)):
            yield finite(fmt, -(near_negative + step + part)), "gamma-negative-tail"


def cases(kind, op, random_count=192):
    fmt = FORMATS[kind]
    rng = random.Random(SEED ^ fmt.bits ^ OP_ID[op] * 65537)
    if op in BINARY:
        seen = set()
        inputs = power_inputs if op == "pow" else atan2_inputs
        reference = expected_pow if op == "pow" else expected_atan2
        for base, power, label in inputs(fmt, rng, random_count):
            key = (base.low, base.high, power.low, power.high)
            if key in seen:
                continue
            seen.add(key)
            for mode in MODES:
                yield Case(op, base, mode, label, reference(base, power, mode), power)
        return
    if op == "exp2":
        directed = exp2_inputs(fmt)
    elif op in {"exp", "expm1"}:
        directed = exp_inputs(fmt)
    elif op == "log1p":
        directed = log1p_inputs(fmt)
    elif op in LOGS:
        directed = log_inputs(fmt)
    elif op in INVERSE:
        directed = inverse_inputs(fmt)
    elif op in HYPERBOLIC:
        directed = hyperbolic_inputs(fmt)
    elif op in INVERSE_HYPERBOLIC:
        directed = inverse_hyperbolic_inputs(fmt)
    elif op in ERROR_FUNCTIONS:
        directed = error_inputs(fmt)
    elif op in GAMMA:
        directed = gamma_inputs(fmt)
    else:
        directed = trig_inputs(fmt, rng)
    seen = set()
    for source in (special_inputs(fmt), directed, random_inputs(fmt, rng, random_count)):
        for value, label in source:
            if (value.low, value.high) in seen:
                continue
            seen.add((value.low, value.high))
            for mode in MODES:
                yield Case(op, value, mode, label, expected(op, value, mode))


def shard(op, first, count, mode, second=None):
    fmt = FORMATS["f32"]
    power = Number(fmt, second) if second is not None else None
    for encoding in range(first, first + count):
        value = Number(fmt, encoding)
        if op in BINARY:
            reference = (expected_pow if op == "pow" else expected_atan2)(value, power, mode)
        else:
            reference = expected(op, value, mode)
        yield Case(op, value, mode, "consecutive-binary32", reference, power)

"""Build independent bit, rational and MPFR expectations for typed math probes."""

from dataclasses import dataclass, replace
from fractions import Fraction
from itertools import product
from pathlib import Path
import random
import re
import struct
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "phase5"))
from vectors import (FORMATS, MPFR_MODES, MODES, DOWN, NEAREST, UP, ZERO, OVERFLOW,
                     UNDERFLOW, INEXACT, ERANGE, Vector, binary_exponent, check_mpfr,
                     encode, round_binary, two)
import gmpy2

OPERATIONS = re.findall(r"^OP\(([a-z]+)\)$", Path(__file__).with_name("operations.def").read_text(),
                        re.MULTILINE)
OP_ID = {op: index for index, op in enumerate(OPERATIONS)}
HEADER = struct.Struct("<HHHHqqII")
BITS = struct.Struct("<QH6x")
PACKET_SIZE = HEADER.size + 5 * BITS.size
INVALID, DIVBYZERO, EDOM = 0x01, 0x04, 33
INT_MIN, INT_MAX = -(1 << 31), (1 << 31) - 1
LONG_MIN, LONG_MAX = -(1 << 63), (1 << 63) - 1
SEED = 0x50483752


@dataclass(frozen=True)
class Number:
    fmt: object
    low: int
    high: int = 0

    @property
    def negative(self):
        return bool(self.high >> 15 if self.fmt.bits == 80 else self.low >> (self.fmt.bits - 1))

    @property
    def fraction(self):
        return self.low & ((1 << (self.fmt.precision - 1)) - 1)

    @property
    def field(self):
        if self.fmt.bits == 80:
            return self.high & 0x7fff
        return (self.low >> (self.fmt.precision - 1)) & (2 * self.fmt.maximum + 1)

    @property
    def category(self):
        if self.field == 2 * self.fmt.maximum + 1:
            if not self.fraction:
                return "inf"
            return "quiet" if self.fraction & (1 << (self.fmt.precision - 2)) else "signal"
        return "normal" if self.field else ("subnormal" if self.fraction else "zero")

    @property
    def value(self):
        if self.category in {"quiet", "signal"}:
            raise ValueError("NaN has no real value")
        if self.category == "inf":
            return float("-inf" if self.negative else "inf")
        significand = self.fraction | (1 << (self.fmt.precision - 1) if self.field else 0)
        exponent = max(1, self.field) - self.fmt.maximum - self.fmt.precision + 1
        result = significand * two(exponent)
        return -result if self.negative else result

    def with_sign(self, negative):
        return representation(self.fmt, negative, self.field, self.fraction)

    def quiet(self):
        return representation(self.fmt, self.negative, self.field,
                              self.fraction | (1 << (self.fmt.precision - 2)))

    def wire(self):
        return BITS.pack(self.low, self.high)


def representation(fmt, negative=False, field=0, fraction=0):
    significand = fraction | (1 << (fmt.precision - 1) if field else 0)
    return Number(fmt, *encode(fmt, negative, significand, field))


def signed_zero(fmt, negative=False):
    return representation(fmt, negative)


def infinity(fmt, negative=False):
    return representation(fmt, negative, 2 * fmt.maximum + 1)


def default_nan(fmt):
    return representation(fmt, False, 2 * fmt.maximum + 1, 1 << (fmt.precision - 2))


@dataclass(frozen=True)
class Outcome:
    result: Number
    secondary: Number | None = None
    integer: int = 0
    flags: int = 0
    error: int = 0
    policy: int = 0


def rational(fmt, value, mode=NEAREST, zero_negative=False, crosscheck=False):
    negative = value < 0 or not value and zero_negative
    exact = Vector("math", 0, abs(Fraction(value)), negative)
    rounded = round_binary(fmt, exact, mode)
    if crosscheck:
        check_mpfr(fmt, exact, mode, rounded)
    return Outcome(Number(fmt, rounded.low, rounded.high), flags=rounded.flags, error=rounded.error)


def finite(fmt, value, negative=False):
    outcome = rational(fmt, Fraction(value), zero_negative=negative)
    if outcome.flags:
        raise ValueError(f"directed input is not exactly representable in binary{fmt.bits}: {value}")
    return outcome.result


def integral(value, mode, away=False):
    negative = value < 0
    q, remainder = divmod(abs(value.numerator), value.denominator)
    if remainder and ((negative and mode == DOWN) or (not negative and mode == UP) or
                      (mode == NEAREST and (2 * remainder > value.denominator or
                       2 * remainder == value.denominator and (away or q & 1)))):
        q += 1
    return -q if negative else q


def signaled_nan(fmt, values):
    signals = [value for value in values if value.category == "signal"]
    quiet = [value for value in values if value.category == "quiet"]
    candidates = signals or quiet
    if not candidates:
        return None
    source = candidates[0]
    if source.fmt != fmt:
        return Outcome(default_nan(fmt), flags=INVALID if signals else 0, policy=1)
    return Outcome(source.quiet(), flags=INVALID if signals else 0,
                   policy=int(len(signals) + len(quiet) > 1))


def domain_error(fmt):
    return Outcome(default_nan(fmt), flags=INVALID, error=EDOM, policy=1)


def next_value(fmt, x, y):
    if x.value == y.value:
        return Outcome(x.with_sign(y.negative))
    exponent = 2 * fmt.maximum + 1
    if x.category == "zero":
        result = representation(fmt, y.negative, 0, 1)
    else:
        fraction_width = fmt.precision - 1
        code = (x.field << fraction_width) | x.fraction
        code += 1 if (x.value < y.value) != x.negative else -1
        result = representation(fmt, x.negative, code >> fraction_width,
                                code & ((1 << fraction_width) - 1))
    if result.field == exponent and x.field != exponent:
        return Outcome(result, flags=OVERFLOW | INEXACT, error=ERANGE)
    if not result.field:
        return Outcome(result, flags=UNDERFLOW | INEXACT, error=ERANGE)
    return Outcome(result)


def mpfr_real(value):
    return gmpy2.mpfr(gmpy2.mpq(value.numerator, value.denominator))


def root_rounded(name, fmt, x, y, mode):
    with gmpy2.context(precision=max(fmt.precision, 64)):
        a = mpfr_real(x.value)
        b = mpfr_real(y.value) if name == "hypot" else None
    with gmpy2.context(precision=fmt.precision, round=MPFR_MODES[mode],
                       emin=fmt.minimum - fmt.precision + 2, emax=fmt.maximum + 1,
                       subnormalize=True) as context:
        if name == "sqrt":
            calculated = gmpy2.sqrt(a)
        elif name == "cbrt":
            calculated = gmpy2.cbrt(a)
        else:
            calculated = gmpy2.hypot(a, b)
        overflowed = context.overflow
    if gmpy2.is_infinite(calculated):
        result = infinity(fmt, gmpy2.is_signed(calculated))
        return Outcome(result, flags=OVERFLOW | INEXACT, error=ERANGE)
    numerator, denominator = calculated.as_integer_ratio()
    value = Fraction(int(numerator), int(denominator))
    result = finite(fmt, value, gmpy2.is_signed(calculated))
    if overflowed:
        return Outcome(result, flags=OVERFLOW | INEXACT, error=ERANGE)
    comparison = x.value if name != "hypot" else x.value ** 2 + y.value ** 2
    if value ** (3 if name == "cbrt" else 2) == comparison:
        return Outcome(result)
    if result.field == 0:
        return Outcome(result, flags=UNDERFLOW | INEXACT, error=ERANGE)
    return Outcome(result, flags=INEXACT)

def reference(op, fmt, x, y, z, mode, parameter):
    positive_zero = Outcome(signed_zero(fmt))
    if op == "classify":
        category = {"quiet": 0, "signal": 0, "inf": 1, "zero": 2, "subnormal": 3,
                    "normal": 4}[x.category]
        mask = (category | (int(x.negative) << 3) | (int(category >= 2) << 4) |
                (int(category == 1) << 5) | (int(category == 0) << 6) |
                (int(category == 4) << 7))
        return replace(positive_zero, integer=mask)
    if op == "compare":
        if x.category in {"signal", "quiet"} or y.category in {"signal", "quiet"}:
            mask = 32
        else:
            mask = (3 | 16 if x.value > y.value else 4 | 8 | 16 if x.value < y.value else 2 | 8)
        return replace(positive_zero, integer=mask)
    if op == "fabs":
        return Outcome(x.with_sign(False))
    if op == "copysign":
        return Outcome(x.with_sign(y.negative))
    if op == "nan":
        return Outcome(default_nan(fmt))

    nans = signaled_nan(fmt, (x, y, z))
    if op == "ilogb" and x.category in {"quiet", "signal", "zero", "inf"}:
        return replace(positive_zero, integer=INT_MAX if x.category == "inf" else INT_MIN,
                       flags=INVALID, error=EDOM)
    if op in {"lrint", "llrint", "lround", "llround"}:
        if x.category in {"quiet", "signal", "inf"}:
            return replace(positive_zero, integer=LONG_MIN, flags=INVALID, error=EDOM)
        away = op in {"lround", "llround"}
        wanted = integral(x.value, NEAREST if away else mode, away)
        if not LONG_MIN <= wanted <= LONG_MAX:
            return replace(positive_zero, integer=LONG_MIN, flags=INVALID, error=EDOM)
        return replace(positive_zero, integer=wanted,
                       flags=INEXACT if not away and x.value != wanted else 0)

    if op in {"fmin", "fmax"}:
        if nans and nans.flags:
            signals = sum(value.category == "signal" for value in (x, y))
            return replace(nans, policy=int(signals > 1))
        if x.category == "quiet":
            return Outcome(y if y.category != "quiet" else x)
        if y.category == "quiet":
            return Outcome(x)
        if x.category == y.category == "zero":
            sign = (x.negative or y.negative) if op == "fmin" else (x.negative and y.negative)
            return Outcome(signed_zero(fmt, sign))
        take_x = x.value < y.value if op == "fmin" else x.value > y.value
        return Outcome(x if take_x else y)

    if op == "hypot":
        if nans and nans.flags:
            return nans
        if x.category == "inf" or y.category == "inf":
            return Outcome(infinity(fmt))

    if nans:
        if op == "modf":
            return replace(nans, secondary=nans.result)
        return nans

    if op in {"ceil", "floor", "trunc", "round", "nearbyint", "rint"}:
        if x.category in {"zero", "inf"}:
            return Outcome(x)
        integral_mode = {"ceil": UP, "floor": DOWN, "trunc": ZERO, "round": NEAREST}.get(op, mode)
        wanted = integral(x.value, integral_mode, op == "round")
        result = rational(fmt, wanted, zero_negative=x.negative)
        return replace(result, flags=INEXACT if op == "rint" and x.value != wanted else 0)

    if op == "frexp":
        if x.category in {"zero", "inf"}:
            return Outcome(x)
        exponent = binary_exponent(abs(x.value)) + 1
        return replace(rational(fmt, x.value / two(exponent)), integer=exponent)
    if op == "modf":
        if x.category in {"zero", "inf"}:
            return Outcome(signed_zero(fmt, x.negative), secondary=x)
        whole = int(x.value)
        result = rational(fmt, x.value - whole, zero_negative=x.negative)
        return replace(result, secondary=finite(fmt, whole, x.negative))
    if op in {"ldexp", "scalbn", "scalbln"}:
        if x.category in {"zero", "inf"}:
            return Outcome(x)
        return rational(fmt, x.value * two(max(-50000, min(parameter, 50000))),
                        mode, crosscheck=True)
    if op in {"nextafter", "nexttoward"}:
        return next_value(fmt, x, y)
    if op == "ilogb":
        return replace(positive_zero, integer=binary_exponent(abs(x.value)))
    if op == "logb":
        if x.category == "zero":
            return Outcome(infinity(fmt, True), flags=DIVBYZERO, error=ERANGE)
        if x.category == "inf":
            return Outcome(infinity(fmt))
        return rational(fmt, binary_exponent(abs(x.value)))
    if op in {"fmod", "remainder", "remquo"}:
        if x.category == "inf" or y.category == "zero":
            return domain_error(fmt)
        if y.category == "inf":
            return Outcome(x)
        quotient = integral(x.value / y.value, ZERO if op == "fmod" else NEAREST)
        result = rational(fmt, x.value - quotient * y.value, zero_negative=x.negative)
        low_quotient = (abs(quotient) % 128) * (-1 if quotient < 0 else 1)
        return replace(result, integer=low_quotient if op == "remquo" else 0)
    if op in {"sqrt", "cbrt", "hypot"}:
        if op == "sqrt" and x.negative and x.category != "zero":
            return domain_error(fmt)
        if op != "hypot" and x.category in {"zero", "inf"}:
            return Outcome(x)
        return root_rounded(op, fmt, x, y, mode)
    if op == "fdim":
        if x.value <= y.value:
            return positive_zero
        if x.category == "inf" or y.category == "inf":
            return Outcome(infinity(fmt))
        return rational(fmt, x.value - y.value, mode, crosscheck=True)
    if op == "fma":
        product_sign = x.negative != y.negative
        if x.category == "inf" or y.category == "inf":
            if x.category == "zero" or y.category == "zero" or (
                    z.category == "inf" and z.negative != product_sign):
                return domain_error(fmt)
            return Outcome(infinity(fmt, product_sign))
        if z.category == "inf":
            return Outcome(z)
        exact_product = x.value * y.value
        exact_sum = exact_product + z.value
        same_zero_signs = not exact_product and not z.value and product_sign == z.negative
        zero_negative = product_sign if same_zero_signs else mode == DOWN
        return rational(fmt, exact_sum, mode, zero_negative, crosscheck=True)
    raise ValueError(f"unhandled operation {op}")


@dataclass(frozen=True)
class Case:
    operation: str
    mode: int
    operands: tuple[Number, Number, Number]
    parameter: int
    expected: Outcome

    def wire(self):
        fmt = self.operands[0].fmt
        output = self.expected
        return (HEADER.pack(OP_ID[self.operation], self.mode, output.flags, output.error,
                            self.parameter, output.integer, output.policy, 0) +
                b"".join(number.wire() for number in (*self.operands, output.result,
                                                       output.secondary or signed_zero(fmt))))


def format_inputs(fmt):
    exponent = 2 * fmt.maximum + 1
    mask = (1 << (fmt.precision - 1)) - 1
    quiet = 1 << (fmt.precision - 2)
    directed = [signed_zero(fmt), signed_zero(fmt, True)]
    for negative in (False, True):
        directed.extend(representation(fmt, negative, field, fraction)
                        for field, fraction in ((0, 1), (0, mask), (1, 0), (1, 1),
                                                (fmt.maximum, 1), (exponent - 1, mask),
                                                (exponent, 0), (exponent, quiet | 29),
                                                (exponent, 17)))
    for value in (Fraction(1, 4), Fraction(1, 2), Fraction(3, 4), Fraction(3, 2),
                  Fraction(5, 2), Fraction(7, 2), Fraction(11, 4), 1, 2, 3, 4, 7, 8,
                  9, 17, 27, 126, 127, 128, 129, 255, 256, 257):
        directed.extend((finite(fmt, value), finite(fmt, -value)))
    directed.extend([finite(fmt, 1 << 63), finite(fmt, -(1 << 63))])
    directed.extend([representation(fmt, False, fmt.maximum + 62, mask),
                     representation(fmt, True, fmt.maximum + 62, mask),
                     representation(fmt, False, fmt.maximum + fmt.precision - 1, 1),
                     representation(fmt, True, fmt.maximum + fmt.precision - 1, 1)])
    return directed


def random_value(fmt, rng):
    finite_field = 2 * fmt.maximum
    field = rng.choice([0, 1, fmt.maximum, finite_field, rng.randrange(finite_field + 1)])
    return representation(fmt, bool(rng.getrandbits(1)), field, rng.getrandbits(fmt.precision - 1))


UNARY = {"fabs", "ceil", "floor", "trunc", "round", "nearbyint", "rint", "lrint", "llrint",
         "lround", "llround", "frexp", "modf", "ilogb", "logb", "sqrt", "cbrt", "classify"}
BINARY = {"copysign", "nextafter", "nexttoward", "fmin", "fmax", "fmod", "remainder",
          "remquo", "fdim", "hypot", "compare"}
SCALE = {"scalbn", "scalbln", "ldexp"}


def to_extended(number):
    fmt = FORMATS["f80"]
    if number.fmt == fmt:
        return number
    if number.category == "inf":
        return infinity(fmt, number.negative)
    if number.category in {"quiet", "signal"}:
        fraction = number.fraction << (fmt.precision - number.fmt.precision)
        return representation(fmt, number.negative, 2 * fmt.maximum + 1, fraction)
    return finite(fmt, number.value, number.negative)


def arguments(op, fmt, directed, rng, random_count):
    zero = signed_zero(fmt)
    unit = finite(fmt, 1)
    negative_unit = finite(fmt, -1)
    one_half = finite(fmt, Fraction(1, 2))
    minimum = representation(fmt, False, 0, 1)
    largest = representation(fmt, False, 2 * fmt.maximum, (1 << (fmt.precision - 1)) - 1)
    if op in UNARY:
        for value in directed:
            yield value, zero, zero, 0
        for _ in range(random_count):
            yield random_value(fmt, rng), zero, zero, 0
    elif op in SCALE:
        shifts = (-2, -1, 0, 1, 2, fmt.minimum, fmt.maximum,
                  fmt.minimum - fmt.precision, fmt.minimum - fmt.precision + 1,
                  INT_MIN, INT_MAX)
        if op == "scalbln":
            shifts += (LONG_MIN, LONG_MAX, 1 << 32, -(1 << 32))
        for value, shift in product(directed[:22], shifts):
            yield value, zero, zero, shift
        for _ in range(random_count):
            yield random_value(fmt, rng), zero, zero, rng.randint(-2 * fmt.maximum, 2 * fmt.maximum)
    elif op in BINARY:
        pairs = list(product(directed[:4], directed[:4]))
        for value in directed:
            pairs.extend(((value, unit), (negative_unit, value), (value, value)))
        pairs.extend((x, y) for x, y in product(directed[:20:2], directed[1:20:2]))
        pairs.extend((finite(fmt, x), finite(fmt, y)) for x, y in (
            (3, 2), (5, 2), (7, 2), (-5, 2), (7, -2), (-7, -2), (255, 2),
            (257, 2), (257, 1), (256, -1), (-257, 1), (3, 4), (5, 12)))
        pairs.extend(((largest, largest), (minimum, minimum), (largest, minimum),
                      (minimum, largest), (minimum, minimum.with_sign(True)),
                      (largest, infinity(fmt)), (largest.with_sign(True), infinity(fmt, True))))
        pairs.extend((random_value(fmt, rng), random_value(fmt, rng)) for _ in range(random_count))
        for left, right in pairs:
            yield left, to_extended(right) if op == "nexttoward" else right, zero, 0
        if op == "nexttoward":
            extended = FORMATS["f80"]
            yield unit, representation(extended, False, extended.maximum, 1), zero, 0
            yield unit, representation(extended, False, extended.maximum - 1, (1 << 63) - 1), zero, 0
    elif op == "fma":
        closer = representation(fmt, False, fmt.maximum, 1)
        below = representation(fmt, False, fmt.maximum - 1, (1 << (fmt.precision - 1)) - 1)
        pairs = ((unit, unit, negative_unit), (closer, below, negative_unit),
                 (minimum, one_half, zero), (minimum.with_sign(True), one_half, zero),
                 (largest, finite(fmt, 2), largest.with_sign(True)),
                 (largest, finite(fmt, 2), largest), (largest, minimum, zero),
                 (infinity(fmt), zero, unit), (infinity(fmt), unit, infinity(fmt, True)),
                 (infinity(fmt, True), unit, infinity(fmt, True)), (unit, unit, infinity(fmt)),
                 (zero, negative_unit, zero), (zero, negative_unit, zero.with_sign(True)))
        for triplet in pairs:
            yield *triplet, 0
        for value in directed:
            yield value, one_half, unit, 0
            yield unit, value, negative_unit, 0
            yield closer, below, value, 0
        for _ in range(random_count):
            yield *(random_value(fmt, rng) for _ in range(3)), 0
    elif op == "nan":
        for tag in range(4):
            yield zero, zero, zero, tag
    else:
        raise ValueError(op)


def samples(kind, random_count=96, operations=OPERATIONS):
    fmt = FORMATS[kind]
    directed = format_inputs(fmt)
    for op in operations:
        rng = random.Random(SEED ^ fmt.bits ^ (OP_ID[op] << 8))
        for x, y, z, parameter in arguments(op, fmt, directed, rng, random_count):
            for mode in MODES:
                outcome = reference(op, fmt, x, y, z, mode, parameter)
                yield Case(op, mode, (x, y, z), parameter, outcome)


def describe(case):
    inputs = " ".join(f"{number.high:04x}:{number.low:016x}" for number in case.operands)
    result = case.expected
    return (f"{case.operation} mode={case.mode:#x} args={inputs} param={case.parameter} "
            f"want={result.result.high:04x}:{result.result.low:016x} integer={result.integer} "
            f"flags={result.flags:#x} errno={result.error}")


def hosted_subset(case):
    """The exact finite common domain of the same packet checker and host libm."""
    op = case.operation
    values = case.operands
    if op == "nan":
        return case.parameter == 0
    if op in SCALE and abs(case.parameter) > 2:
        return False
    if any(value.category not in {"normal", "zero"} or abs(value.value) > 256 or
           value.value.denominator > 16 for value in values):
        return False
    if op in {"fmin", "fmax"} and values[0].category == values[1].category == "zero":
        return values[0].negative == values[1].negative
    if case.expected.error:
        return False
    if op == "remquo" and abs(integral(values[0].value / values[1].value, NEAREST)) > 7:
        return False
    if op == "cbrt" and (case.mode != NEAREST or abs(values[0].value) > 8):
        return False
    if op in {"sqrt", "cbrt", "hypot"} and case.expected.flags:
        return False
    return True


def memcheck_subset(kind, case):
    """Nearest-mode finite cases avoid Memcheck's extended and control-state limits."""
    return kind != "f80" and case.mode == NEAREST and hosted_subset(case)


if __name__ == "__main__":
    if len(sys.argv) not in {2, 3} or sys.argv[1] not in {"f32", "f64", "f80"}:
        raise SystemExit("usage: math_vectors.py f32|f64|f80 [operation]")
    operations = (sys.argv[2],) if len(sys.argv) == 3 else OPERATIONS
    for case in samples(sys.argv[1], operations=operations):
        sys.stdout.buffer.write(case.wire())

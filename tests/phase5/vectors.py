"""Construct independent x86 floating conversion packets from exact rationals."""

from dataclasses import dataclass
from fractions import Fraction
from pathlib import Path
import hashlib
import os
import random
import re
import struct
import sys

import gmpy2

sys.set_int_max_str_digits(0)

NEAREST, DOWN, UP, ZERO = 0, 0x400, 0x800, 0xc00
MODES = (NEAREST, DOWN, UP, ZERO)
OVERFLOW, UNDERFLOW, INEXACT = 0x08, 0x10, 0x20
ERANGE = 34
SEED = 0x50483552
PIN = "55d79b184b7d8fac2e143e89dc19b766ec4e54b8"
PACKET = struct.Struct("<IIHHHHQ")


@dataclass(frozen=True)
class Format:
    bits: int
    precision: int
    minimum: int
    maximum: int


FORMATS = {
    "f32": Format(32, 24, -126, 127),
    "f64": Format(64, 53, -1022, 1023),
    "f80": Format(80, 64, -16382, 16383),
}
FORMATS["atof"] = FORMATS["f64"]


@dataclass(frozen=True)
class Vector:
    text: str
    end: int
    value: Fraction | str
    negative: bool = False


@dataclass(frozen=True)
class Rounded:
    low: int
    high: int
    flags: int
    error: int
    magnitude: Fraction | None


def two(exponent):
    return Fraction(1 << exponent) if exponent >= 0 else Fraction(1, 1 << -exponent)


def binary_exponent(value):
    numerator, denominator = value.numerator, value.denominator
    exponent = numerator.bit_length() - denominator.bit_length()
    return exponent - (value < two(exponent))


def encode(fmt, negative, significand, exponent_field):
    if fmt.bits == 80:
        return significand, (int(negative) << 15) | exponent_field
    fraction_bits = fmt.precision - 1
    low = (int(negative) << (fmt.bits - 1)) | (exponent_field << fraction_bits)
    return low | (significand & ((1 << fraction_bits) - 1)), 0


def round_binary(fmt, vector, mode):
    value, negative = vector.value, vector.negative
    precision = fmt.precision
    implicit = 1 << (precision - 1)
    infinite_exponent = 2 * fmt.maximum + 1
    if value in ("infinity", "nan"):
        significand = implicit if value == "infinity" else implicit | (implicit >> 1)
        return Rounded(*encode(fmt, negative, significand, infinite_exponent), 0, 0, None)
    if not value:
        return Rounded(*encode(fmt, negative, 0, 0), 0, 0, Fraction())

    exponent = max(binary_exponent(value), fmt.minimum)
    quantum = exponent - precision + 1
    scaled = value / two(quantum)
    significand, remainder = divmod(scaled.numerator, scaled.denominator)
    twice = remainder * 2
    if remainder and (mode == UP and not negative or mode == DOWN and negative
                      or mode == NEAREST and (twice > scaled.denominator
                                                or twice == scaled.denominator and significand & 1)):
        significand += 1
    if significand == 1 << precision:
        significand >>= 1
        exponent += 1
        quantum += 1
    if exponent > fmt.maximum:
        outward = mode == NEAREST or mode == UP and not negative or mode == DOWN and negative
        if outward:
            return Rounded(*encode(fmt, negative, implicit, infinite_exponent),
                           OVERFLOW | INEXACT, ERANGE, None)
        maximum_significand = 2 * implicit - 1
        maximum = maximum_significand * two(fmt.maximum - precision + 1)
        return Rounded(*encode(fmt, negative, maximum_significand, infinite_exponent - 1),
                       OVERFLOW | INEXACT, ERANGE, maximum)

    normal = significand >= implicit
    exponent_field = exponent + fmt.maximum if normal else 0
    flags = INEXACT if remainder else 0
    error = 0
    if flags and not normal:
        flags |= UNDERFLOW
        error = ERANGE
    return Rounded(*encode(fmt, negative, significand, exponent_field),
                   flags, error, significand * two(quantum))


MPFR_MODES = {
    NEAREST: gmpy2.RoundToNearest,
    DOWN: gmpy2.RoundDown,
    UP: gmpy2.RoundUp,
    ZERO: gmpy2.RoundToZero,
}


def check_mpfr(fmt, vector, mode, expected):
    if not isinstance(vector.value, Fraction):
        return False
    value = vector.value
    context = gmpy2.context(precision=fmt.precision, round=MPFR_MODES[mode],
                            emin=fmt.minimum - fmt.precision + 2, emax=fmt.maximum + 1,
                            subnormalize=True)
    with context:
        if not value and vector.negative:
            actual = gmpy2.mpfr("-0")
        else:
            signed_numerator = -value.numerator if vector.negative else value.numerator
            actual = gmpy2.mpfr(gmpy2.mpq(signed_numerator, value.denominator))
        valid = gmpy2.is_signed(actual) == vector.negative
        if expected.magnitude is None:
            valid = valid and gmpy2.is_infinite(actual)
        else:
            valid = valid and not gmpy2.is_infinite(actual)
            if valid:
                numerator, denominator = actual.as_integer_ratio()
                valid = Fraction(abs(int(numerator)), int(denominator)) == expected.magnitude
    if not valid:
        raise ValueError(f"MPFR disagreed for binary{fmt.bits}, mode {mode:#x}, {vector.text[:90]!r}")
    return True


DECIMAL = re.compile(r"([+-]?)([0-9]*)(?:\.([0-9]*))?(?:[eE]([+-]?[0-9]+))?")


def decimal_value(subject):
    match = DECIMAL.fullmatch(subject)
    if not match:
        raise ValueError(f"expected well-formed published decimal {subject!r}")
    sign, whole, fractional, exponent = match.groups()
    fractional = fractional or ""
    digits = (whole + fractional).lstrip("0")
    if not whole and not fractional:
        raise ValueError(f"empty decimal subject {subject!r}")
    if not digits:
        return Fraction(), sign == "-"
    scale = int(exponent or "0") - len(fractional)
    order = scale + len(digits)
    # These stand-ins lie beyond the range of every target under all modes.
    if order > 6000:
        return two(20000), sign == "-"
    if order < -6000:
        return two(-20000), sign == "-"
    magnitude = int(digits)
    return (Fraction(magnitude * 10 ** scale) if scale >= 0
            else Fraction(magnitude, 10 ** -scale)), sign == "-"


def decimal(subject, suffix=""):
    value, negative = decimal_value(subject)
    return Vector(subject + suffix, len(subject), value, negative)


def hex_power(significand, exponent, negative=False, suffix="!"):
    subject = ("-" if negative else "") + f"0x{significand:x}p{exponent:+d}"
    return Vector(subject + suffix, len(subject), significand * two(exponent), negative)


def exact_decimal(value):
    numerator, denominator = value.numerator, value.denominator
    places = denominator.bit_length() - 1
    if denominator != 1 << places:
        raise ValueError("expected a binary rational")
    digits = str(numerator * 5 ** places).zfill(places + 1)
    return digits if not places else digits[:-places] + "." + digits[-places:]


def lexical():
    yield decimal("1.25", "!")
    for subject in ("0", "-0", "+0e99999999999999999999999", "-0e-99999999999999999999999",
                    "1e99999999999999999999999", "-1e-99999999999999999999999",
                    "0.1", "-0.1", "125.125e-1", "9007199254740993", ".00025", "1."):
        yield decimal(subject, "?")
    for text in ("", " \t\n", "+", "-.", ".", " +junk", "\x0e1"):
        yield Vector(text, 0, Fraction())
    yield Vector(" \t\n\r\v\f-125.125e-1tail", 17, Fraction(1001, 80), True)
    yield decimal("12", "e+tail")
    yield decimal("0.5", "E-?")
    yield decimal("0", "x.p1?")
    yield decimal("-0", "xZ")
    yield Vector("0x.8p+1tail", 7, Fraction(1))
    yield Vector("0x1p+?", 3, Fraction(1))
    yield Vector("-0x1.Ap2x", 8, Fraction(13, 2), True)
    yield Vector("0Xf.f?", 5, Fraction(255, 16))
    for text, end, value, negative in (
        ("+INFinity?", 9, "infinity", False), ("-inf!", 4, "infinity", True),
        ("Infi?", 3, "infinity", False), ("naN(payload_012)!", 16, "nan", False),
        ("NaN(bad-char)!", 3, "nan", False), ("nan(", 3, "nan", False),
        ("-NaN()!", 6, "nan", True),
    ):
        yield Vector(text, end, value, negative)


def boundaries(fmt):
    p, minimum, maximum = fmt.precision, fmt.minimum, fmt.maximum
    implicit = 1 << (p - 1)
    subnormal_exponent = minimum - p + 1
    for negative in (False, True):
        yield hex_power(1, subnormal_exponent, negative)
        yield hex_power(1, subnormal_exponent - 1, negative)
        yield hex_power(3, subnormal_exponent - 2, negative)
        yield hex_power(2 * implicit - 1, subnormal_exponent - 1, negative)
        yield hex_power(implicit, subnormal_exponent, negative)
        yield hex_power(2 * implicit - 1, maximum - p + 1, negative)
        yield hex_power(4 * implicit - 1, maximum - p, negative)
        yield hex_power(1, maximum + 1, negative)
        for delta in (1, 2, 3, 6):
            yield hex_power(4 * implicit + delta, -p - 1, negative)
        halfway = Fraction(1) + two(-p)
        text = exact_decimal(halfway)
        yield Vector(("-" if negative else "") + text, len(text) + negative, halfway, negative)
        above = text + "0" * 22000 + "1"
        fractional_places = len(above) - above.index(".") - 1
        yield Vector(("-" if negative else "") + above + "!",
                     len(above) + negative, halfway + Fraction(1, 10 ** fractional_places), negative)
        digits = (p + 3) // 4
        half_hex = f"{1 << (4 * digits - p):0{digits}x}"
        sticky_hex = half_hex + "0" * 32 + "1"
        subject = ("-" if negative else "") + "0x1." + sticky_hex + "p0"
        yield Vector(subject + "!", len(subject), halfway + two(-4 * len(sticky_hex)), negative)


def random_vector(fmt, rng, index):
    negative = bool(rng.randrange(2))
    if index % 2:
        coefficient = rng.randrange(1, 1 << rng.randrange(2, 98))
        exponent = rng.randrange(fmt.minimum - fmt.precision - 12, fmt.maximum + 15)
        return hex_power(coefficient, exponent, negative, "?")
    digits = rng.randrange(1, 10 ** rng.randrange(1, 91))
    limit = (fmt.maximum * 30103) // 100000 + 30
    exponent = rng.randrange(-limit - 110, limit)
    return decimal(("-" if negative else "") + f"{digits}e{exponent:+d}", "tail")


def sampled(fmt):
    rng = random.Random(SEED)
    return (random_vector(fmt, rng, index) for index in range(96))


def encode_packet(vector, mode, expected):
    text = vector.text.encode("ascii")
    return PACKET.pack(len(text), vector.end, mode, expected.flags,
                       expected.error, expected.high, expected.low) + text


def fuzz_packets(target, seed, batch_size):
    fmt = FORMATS[target]
    rng = random.Random(seed)
    index = 0
    while True:
        payload = bytearray()
        for _ in range(batch_size):
            vector = random_vector(fmt, rng, index)
            mode = MODES[(index // 2) % len(MODES)]
            expected = round_binary(fmt, vector, mode)
            check_mpfr(fmt, vector, mode, expected)
            payload.extend(encode_packet(vector, mode, expected))
            index += 1
        yield bytes(payload)


def pinned_rows():
    directory = Path(os.environ["OPEN_ASSEMBLY_FLOAT_VECTORS"])
    data = (directory / "vectors.txt").read_bytes()
    license_text = (directory / "LICENSE").read_bytes()
    if b"Apache License" not in license_text:
        raise ValueError("unexpected published vector license")
    rows = []
    for line in data.decode("ascii").splitlines():
        _, binary32, binary64, subject = line.split(None, 3)
        rows.append((decimal(subject), int(binary32, 16), int(binary64, 16)))
    if len(rows) != 60:
        raise ValueError("unexpected published vector count")
    metadata = {
        "revision": PIN, "source": "nigeltao/parse-number-fxx-test-data/data/more-test-cases.txt",
        "license": "Apache-2.0", "sha256": hashlib.sha256(data).hexdigest(),
        "license_sha256": hashlib.sha256(license_text).hexdigest(),
    }
    return rows, metadata


def corpus(target, *, compatible_host=None):
    if compatible_host not in (None, "glibc", "musl"):
        raise ValueError("unknown conversion comparison host")
    fmt = FORMATS[target]
    published, metadata = pinned_rows()
    records = [(vector, mode) for vector in lexical() for mode in MODES]
    records += [(vector, mode) for vector in boundaries(fmt) for mode in MODES]
    if target != "atof":
        records += [(vector, mode) for vector in sampled(fmt) for mode in MODES]
    if target in ("f32", "f64"):
        for vector, bits32, bits64 in published:
            expected = bits32 if target == "f32" else bits64
            if round_binary(fmt, vector, NEAREST).low != expected:
                raise ValueError(f"published binary{fmt.bits} bits disagreed for {vector.text!r}")
            records.append((vector, NEAREST))
    payload = bytearray()
    checked = count = 0
    exclusions = {}
    for vector, mode in records:
        expected = round_binary(fmt, vector, mode)
        reason = None
        if compatible_host and vector.value == "nan":
            reason = "NaN payload representation is implementation-defined"
        elif compatible_host == "musl":
            if expected.flags & UNDERFLOW and not expected.magnitude:
                reason = "pinned musl differs for inexact underflow to signed zero"
            elif target == "f32" and mode != NEAREST:
                reason = "pinned musl differs on directed binary32 rounding"
        if reason:
            exclusions[reason] = exclusions.get(reason, 0) + 1
            continue
        checked += check_mpfr(fmt, vector, mode, expected)
        count += 1
        payload.extend(encode_packet(vector, mode, expected))
    return bytes(payload), {
        "records": count, "mpfr_crosschecks": checked, "host_exclusions": exclusions,
        "mpfr_version": gmpy2.mpfr_version(), "gmpy2_version": gmpy2.version(),
        "published": metadata if target in ("f32", "f64") else None, "seed": SEED,
    }

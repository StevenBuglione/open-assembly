"""Arbitrary-precision reference model for the documented LP64 arena contract."""

from struct import Struct
import sys

REQUEST = Struct("<7Q")
RESPONSE = Struct("<q5Q")
MAX = (1 << 64) - 1
EINVAL, EOVERFLOW, ENOSPC, EDOM = 22, 75, 28, 33


def initialize(base, capacity, used, a, b, flags, output):
    # Packet transforms weight small valid spans and the upper address boundary.
    selector = (flags >> 4) & 3
    if selector == 0:
        a %= 65536
        b %= 65536
    elif selector == 1:
        a = 0
        b %= 2
    elif selector == 2:
        a = MAX - a % 64
        b %= 128

    if flags % 16 == 0 or a == 0 < b:
        return -EINVAL, base, capacity, used, output
    if a + b > MAX:
        return -EOVERFLOW, base, capacity, used, output
    return 0, a, b, 0, output


def allocate(base, capacity, used, size, align, flags, output):
    selector = (flags >> 4) & 3
    if selector == 0:
        base %= 65536
        capacity %= 4096
        used %= capacity + 1
        size %= 4096
        align = 2 ** (align % 8)
    elif selector == 1:
        base = MAX - base % 64
        capacity %= 128
        used %= capacity + 1
        size %= 16
        align = 2 ** (align % 64)
    elif selector == 2:
        base %= 4096
        capacity %= 4096
        used %= 4096
        size = 0 if flags & 64 else MAX - size % 64
        align = 2 ** (align % 8)

    before = base, capacity, used, output
    if flags % 16 in (0, 1) or not align or align.bit_count() != 1:
        return -EINVAL, *before
    if used > capacity or base == 0 < capacity:
        return -EINVAL, *before
    if base + capacity > MAX:
        return -EOVERFLOW, *before
    aligned = -(-(base + used) // align) * align
    end = aligned - base + size
    if aligned > MAX or end > MAX:
        return -EOVERFLOW, *before
    if end > capacity:
        return -ENOSPC, *before
    return 0, base, capacity, end if size else used, aligned


def reset(base, capacity, used, _a, _b, flags, output):
    if flags % 16 == 0:
        return -EINVAL, base, capacity, used, output
    return 0, base, capacity, 0, output


def main(operation):
    data = sys.stdin.buffer.read()
    if len(data) % REQUEST.size:
        raise SystemExit(2)
    sys.stdout.buffer.write(b"".join(
        RESPONSE.pack(*operation(*row), EDOM) for row in REQUEST.iter_unpack(data)
    ))

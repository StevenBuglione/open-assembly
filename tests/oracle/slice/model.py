"""Independent Python range, sequence and endian oracles for slice packets."""

from struct import Struct
import sys

REQUEST = Struct("<4Q")
RESPONSE = Struct("<q4Q")
EINVAL, EOVERFLOW, ERANGE, ENOENT, EDOM = 22, 75, 34, 2, 33
MAX = (1 << 64) - 1


def span(flags, extent, content):
    mode = flags % 16
    extent %= 9
    if mode == 1:
        return mode, 0, 0
    if mode == 2:
        return mode, 0, extent + 1
    if mode == 3:
        return mode, MAX - 2, extent + 4
    return mode, content % (1 << 28) + 1, extent


def take(flags, extent, requested, content):
    mode, base, extent = span(flags, extent, content)
    requested %= 12
    output = 0x6F31
    if mode in (4, 5, 6) or not base and extent:
        return -EINVAL, base, extent, output
    if base + extent > MAX:
        return -EOVERFLOW, base, extent, output
    if requested > extent:
        return -ERANGE, base, extent, output
    return 0, base + requested, extent - requested, base


def find(flags, extent, requested, content):
    mode, base, extent = span(flags, extent, content)
    data = content.to_bytes(8, "little")
    output = 0x92DC6716AF
    if mode == 7:
        return -EINVAL, 0, 0, output
    if mode == 4 or not base and extent:
        return -EINVAL, 0, 0, output
    if base + extent > MAX:
        return -EOVERFLOW, 0, 0, output
    needle = data[requested % 8] if mode >= 8 and mode % 2 else requested % 256
    index = data[:extent].find(bytes((needle,)))
    return (-ENOENT, 0, 0, output) if index < 0 else (0, 0, 0, index)


def load(flags, extent, _requested, content):
    mode, base, extent = span(flags, extent, content)
    output = 0x912ABB33
    if mode == 4 or not base and extent:
        return -EINVAL, 0, 0, output
    if base + extent > MAX:
        return -EOVERFLOW, 0, 0, output
    if extent < 4:
        return -ERANGE, 0, 0, output
    return 0, 0, 0, int.from_bytes(content.to_bytes(8, "little")[:4], "big")


def main(operation):
    data = sys.stdin.buffer.read()
    if len(data) % REQUEST.size:
        raise SystemExit(2)
    sys.stdout.buffer.write(b"".join(RESPONSE.pack(*operation(*row), EDOM)
                                     for row in REQUEST.iter_unpack(data)))

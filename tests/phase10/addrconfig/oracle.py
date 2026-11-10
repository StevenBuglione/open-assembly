"""Independent Linux route-netlink records and configured-family rules."""

import errno
from ipaddress import ip_address
import random
from struct import Struct, pack

REQUEST = Struct("<II")
RESULT = Struct("<iI")
HEADER = Struct("<IHHII")
ADDRESS = Struct("<BBBBI")
ATTRIBUTE = Struct("<HH")
SEED = 0x6C41951F

NEWADDR, DONE, ERROR, NOOP = 20, 3, 2, 1
MULTI, INTERRUPTED = 2, 0x10
IFA_ADDRESS, IFA_LOCAL, IFA_FLAGS = 1, 2, 8
TENTATIVE, DADFAILED = 0x40, 0x08
MALFORMED, RETRY = -errno.EIO, -errno.EAGAIN


def aligned(data):
    return data + b"\0" * (-len(data) % 4)


def message(kind, payload=b"", *, flags=MULTI, sequence=1, length=None):
    actual = HEADER.size + len(payload)
    return aligned(HEADER.pack(actual if length is None else length, kind, flags, sequence, 0) + payload)


def attribute(kind, value, length=None):
    return aligned(ATTRIBUTE.pack(ATTRIBUTE.size + len(value) if length is None else length, kind) + value)


def address(text, *, local=None, fixed=0, override=None, extra=b""):
    primary = ip_address(text)
    family, prefix = (2, 24) if primary.version == 4 else (10, 64)
    attributes = attribute(IFA_ADDRESS, primary.packed)
    if local is not None:
        attributes += attribute(IFA_LOCAL, ip_address(local).packed)
    if override is not None:
        attributes += attribute(IFA_FLAGS, pack("<I", override))
    return message(NEWADDR, ADDRESS.pack(family, prefix, fixed, 0, 5) + attributes + extra)


def row(packet, initial, status, after, label):
    return REQUEST.pack(len(packet), initial) + packet, RESULT.pack(status, after), label


def directed():
    v4, v6 = address("192.0.2.77"), address("2001:db8::99")
    rows = [
        (v4, 0, 0, 1, "ipv4"),
        (v6, 0, 0, 2, "ipv6"),
        (v4 + v6, 0, 0, 3, "both"),
        (v6, 1, 0, 3, "merge-existing"),
        (address("127.99.37.3") + address("::1"), 0, 0, 0, "loopback"),
        (address("0.0.0.0") + address("::"), 0, 0, 0, "unspecified"),
        (address("169.254.4.5") + address("fe80::3"), 0, 0, 3, "link-local"),
        (address("192.0.2.1", local="127.0.0.1"), 2, 0, 2, "local-overrides-address"),
        (address("127.0.0.1", local="192.0.2.1"), 0, 0, 1, "configured-local"),
        (address("2001:db8::4", fixed=TENTATIVE), 1, 0, 1, "tentative"),
        (address("2001:db8::4", fixed=DADFAILED), 1, 0, 1, "dad-failed"),
        (address("2001:db8::4", fixed=TENTATIVE, override=0), 0, 0, 2, "flags-override-fixed"),
        (address("192.0.2.4", override=DADFAILED), 2, 0, 2, "flags-clear-family"),
        (address("192.0.2.4", extra=attribute(37, b"odd")), 0, 0, 1, "unknown-attribute"),
        (message(NOOP) + v6, 0, 0, 2, "noop"),
        (message(DONE), 2, 1, 2, "empty-done"),
        (v4 + message(DONE, pack("<i", 0)), 2, 1, 3, "zero-status-done"),
        (v4 + message(DONE, flags=MULTI | INTERRUPTED), 2, RETRY, 2, "interrupted"),
        (v4 + message(DONE, pack("<i", -errno.EINTR)), 2, RETRY, 2, "error-done"),
        (v4 + message(DONE) + v6, 2, MALFORMED, 2, "non-final-done"),
        (message(ERROR, pack("<i", -errno.EPERM)), 1, RETRY, 1, "netlink-error"),
        (message(0xf3), 3, MALFORMED, 3, "unknown-message"),
        (message(NOOP, sequence=2), 1, MALFORMED, 1, "wrong-sequence"),
        (message(NOOP, length=15), 2, MALFORMED, 2, "short-header-length"),
        (message(NOOP, length=300), 2, MALFORMED, 2, "length-past-datagram"),
        (v4 + address("192.0.2.4", extra=attribute(IFA_ADDRESS, ip_address("192.0.2.5").packed)),
         0, MALFORMED, 0, "duplicate-address"),
        (address("192.0.2.4", extra=attribute(37, b"", length=2)), 3, MALFORMED, 3, "short-attribute"),
        (message(NEWADDR, ADDRESS.pack(2, 24, 0, 0, 5) + attribute(IFA_ADDRESS, b"\1\2")),
         2, MALFORMED, 2, "short-address"),
        (b"", 2, MALFORMED, 2, "empty"),
        (message(NOOP, b"\0" * (32768 - HEADER.size)), 2, 0, 2, "datagram-capacity"),
        (message(NOOP, b"\0" * (32772 - HEADER.size)), 2, MALFORMED, 2, "oversize"),
    ]
    rows.extend((v6[:length], 1, MALFORMED, 1, "truncated") for length in range(1, len(v6)))
    return [row(*item) for item in rows]


def sampled(count):
    random_source = random.Random(SEED)
    rows = []
    ipv4 = ("0.0.0.0", "127.23.1.9", "192.0.2.64", "169.254.9.10")
    ipv6 = ("::", "::1", "2001:db8::a4", "fe80::b3")
    for index in range(count):
        initial = random_source.randrange(4)
        expected = initial
        datagram = b""
        for _ in range(1 + random_source.randrange(9)):
            family = random_source.randrange(2)
            primary, local = random_source.randrange(4), random_source.choice((None, 0, 1, 2, 3))
            fixed, override = random_source.choice((0, TENTATIVE, DADFAILED)), random_source.choice(
                (None, 0, TENTATIVE, DADFAILED))
            options = ipv6 if family else ipv4
            datagram += address(options[primary], local=None if local is None else options[local],
                                fixed=fixed, override=override,
                                extra=attribute(37, random_source.randbytes(index % 7)))
            if (primary if local is None else local) >= 2 and not (fixed if override is None else override):
                expected |= 1 << family
        mode = index % 4
        if mode == 0:
            rows.append(row(datagram, initial, 0, expected, "seeded-data"))
        elif mode == 1:
            rows.append(row(datagram + message(DONE), initial, 1, expected, "seeded-done"))
        elif mode == 2:
            rows.append(row(datagram + b"\0", initial, MALFORMED, initial, "seeded-partial"))
        else:
            rows.append(row(datagram + message(DONE, flags=MULTI | INTERRUPTED), initial, RETRY, initial,
                            "seeded-interrupted"))
    return rows

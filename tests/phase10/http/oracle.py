"""Independent byte grammar for the loopback acceptance application."""

import re
from struct import Struct

LIMIT = 8192
HEAD = 1 << 16
PACKET = Struct("<I")
TOKEN = rb"[!#$%&'*+.^_`|~0-9A-Za-z-]+"
REQUEST_LINE = re.compile(rb"(" + TOKEN + rb") (/[^ #\x00-\x1f\x7f-\xff]*) HTTP/(1\.[01])")
FIELD = re.compile(rb"(" + TOKEN + rb"):[\x09\x20-\x7e]*")
HOST = re.compile(rb"[A-Za-z0-9.-]+(?::([0-9]{1,5}))?")
LENGTH = re.compile(rb"0+")


def classify(raw):
    end = raw[:LIMIT].find(b"\r\n\r\n")
    if end < 0:
        return 431 if len(raw) >= LIMIT else 0
    first, *lines = raw[:end].split(b"\r\n")
    request = REQUEST_LINE.fullmatch(first)
    if not request:
        return 400
    host = length = 0
    for line in lines:
        header = FIELD.fullmatch(line)
        if not header:
            return 400
        name = header[1].lower()
        value = line[len(name) + 1:].strip(b" \t")
        if name == b"host":
            host += 1
            authority = HOST.fullmatch(value)
            if host > 1 or not authority or authority[1] and int(authority[1]) > 65535:
                return 400
        elif name == b"content-length":
            length += 1
            if length > 1 or not LENGTH.fullmatch(value):
                return 400
        elif name == b"transfer-encoding":
            return 400
    if request[3] == b"1.1" and host != 1:
        return 400
    method, target = request.group(1, 2)
    if method not in (b"GET", b"HEAD"):
        return 405
    return (200 if target == b"/" else 404) | (HEAD if method == b"HEAD" else 0)


def request(method=b"GET", target=b"/", version=b"1.1", fields=(b"Host: localhost",)):
    line = b" ".join((method, target, b"HTTP/" + version))
    return b"\r\n".join((line, *fields, b"", b""))


def directed():
    cases = [
        (b"", 0), (b"malformed", 0), (b"\r\n\r\n", 400),
        (request(), 200), (request(b"HEAD"), HEAD | 200),
        (request(b"GET", b"/missing"), 404), (request(b"HEAD", b"/?x"), HEAD | 404),
        (request(b"HEAD", b"/%2F"), HEAD | 404),
        (request(b"OPTIONS"), 405), (request(b"head"), 405), (request(b"GET!"), 405),
        (request(b"GE\x00T"), 400), (request(b"GET", b"*"), 400),
        (request(b"GET", b"/#bad"), 400), (request(b"GET", b"/\x7f"), 400),
        (request(b"GET", b"/\xff"), 400), (request(version=b"2.0"), 400),
        (request(version=b"1.0", fields=()), 200), (request(fields=()), 400),
        (request(fields=(b"HoSt: \tmy-host.EXAMPLE:65535 \t",)), 200),
        (request(fields=(b"Host: host:00000",)), 200),
        (request(fields=(b"Host: host:65536",)), 400),
        (request(fields=(b"Host: host:000001",)), 400),
        (request(fields=(b"Host: host:",)), 400),
        (request(fields=(b"Host: host_01",)), 400),
        (request(fields=(b"Host: [::1]",)), 400),
        (request(fields=(b"Host: \t ",)), 400),
        (request(fields=(b"Host: one", b"hOsT: two")), 400),
        (request(fields=(b"Host: one", b"cOnTeNt-LeNgTh:\t 000\t")), 200),
        (request(fields=(b"Host: one", b"Content-Length: 01")), 400),
        (request(fields=(b"Host: one", b"Content-Length: +0")), 400),
        (request(fields=(b"Host: one", b"Content-Length: 0", b"Content-Length: 0")), 400),
        (request(fields=(b"Host: one", b"Transfer-Encoding: identity")), 400),
        (request(fields=(b"Host: one", b"Field:\t ~")), 200),
        (request(fields=(b"Host: one", b"Field:\x7f")), 400),
        (request(fields=(b"Host: one", b"Field:\x80")), 400),
        (request(fields=(b"Host: one", b" Field: x")), 400),
        (request(fields=(b"Host: one", b"Field : x")), 400),
        (request(fields=(b"Host: one", b": x")), 400),
        (request(fields=(b"Host: one", b"X@X: x")), 400),
        (request().replace(b"GET /", b"GET  /"), 400),
        (request().replace(b" / HTTP", b" /\tHTTP"), 400),
        (request().replace(b"\r\n", b"\n"), 0),
        (request() + b"POST bad\r\n\r\n\x00\xff", 200),
    ]
    base = request(fields=(b"Host: localhost", b"Pad: "))
    for cap in (8190, 8191, 8192, 8193, 8194, 12288, 16384):
        adjusted = request(fields=(b"Host: localhost", b"Pad: " + b"a" * (cap - len(base))))
        cases.append((adjusted, 200 if cap <= LIMIT else 431))
    for cap in (8191, 8192, 8193, 16384):
        cases.append((b"x" * cap, 0 if cap < LIMIT else 431))
    for value in (request(), request(b"HEAD"), request(fields=(b"Host: host:65536",))):
        cases.extend((value[:cut], 0) for cut in range(len(value)))
    if any(classify(data) != expected for data, expected in cases):
        raise ValueError("HTTP grammar disagrees with the manually specified cases")
    return cases


def random_request(rng):
    method = rng.choice((b"GET", b"HEAD", b"POST", b"GE T", b"", b"foo!", b"\xff"))
    target = rng.choice((b"/", b"/%00", b"/abc", b"/?query", b"*", b"/#frag", b"/\x00"))
    version = rng.choice((b"1.0", b"1.1", b"1.1", b"2.0", b"1.01"))
    fields = []
    for _ in range(rng.randrange(6)):
        fields.append(rng.choice((
            b"Host: h.local", b"hOSt: h.local:65535", b"Host: h.local:65536", b"Host: ",
            b"Content-Length: 0", b"Content-Length: 1", b"Transfer-Encoding: chunked",
            b"Some-Header: hello\tworld", b"Bad Header: x", b"Header: \x00",
        )))
    return request(method, target, version, fields)


def fuzz_record(rng, bases):
    kind = rng.randrange(10)
    if kind == 0:
        return rng.randbytes(rng.randrange(160))
    if kind == 1:
        size = LIMIT + rng.randrange(-12, 13)
        return (b"GET / HTTP/1.1\r\nHost: local\r\nPad: " + b"x" * size)[:size] + b"\r\n\r\n"
    if kind < 4:
        return random_request(rng)
    data = bytearray(rng.choice(bases))
    for _ in range(1 + rng.randrange(4)):
        pos = rng.randrange(len(data) + 1)
        edit = rng.randrange(4)
        if edit == 0:
            del data[pos:pos + rng.randrange(1, 9)]
        elif edit == 1:
            data[pos:pos] = rng.choice((b"\r", b"\n", b"\r\n\r\n", b" ", b"\x00", b"\xff"))
        elif edit == 2 and pos < len(data):
            data[pos] ^= 1 << rng.randrange(8)
        else:
            del data[pos:]
    return bytes(data[:16384])

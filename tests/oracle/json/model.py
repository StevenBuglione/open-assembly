#!/usr/bin/env python3
"""Independent bounded-token model based on RFC 8259 and strict UTF-8."""

import errno
import json
import re
import struct
import sys

MASK = (1 << 64) - 1
CANARY = 0x8DE1EA30AB5F4307
WHITESPACE = b" \t\n\r"
STRING = re.compile(rb'"(?:[^"\\]|\\[\x00-\xff])*"')
INTEGER = re.compile(rb"-?(?:0|[1-9][0-9]*)")
DIGITS = re.compile(rb"[0-9]+")
EXPONENT = re.compile(rb"[eE][+-]?[0-9]+")
PUNCT = dict(zip(b"{}[]:,", range(6, 12)))
DOCUMENTS = (
    b'{"a":[true,false,null],"a":"\\uD834\\uDD1E"}',
    b'\t[-0,1.25e-12,7E+31]\r\n', b'"a\\u0000\\/\\b\\f\\r\\n\\t"',
    b'"\xc2\x80\xe0\xa0\x80\xf4\x8f\xbf\xbf"', b'[[[[0]]]]', b'{"":{}, "b":[]}',
    b'01', b'1.', b'0E+', b'{"a":1,}', b'[true false]', b'"\\uD800!"',
    b'"\xed\xa0\x80"', b'"\xf0\x8f\xbf\xbf"', b'trueX', b'\xef\xbb\xbfnull',
)


class Fault(ValueError):
    def __init__(self, code=errno.EILSEQ):
        self.code = code


def scan_string(data, start):
    match = STRING.match(data, start)
    if match is None:
        raise Fault()
    try:
        # Python's strict UTF-8 decoder rejects malformed and overlong bytes.
        # Encoding the resulting value rejects Python's unpaired escapes.
        value = json.loads(match[0].decode("utf-8"))
        value.encode("utf-8")
    except (UnicodeError, ValueError) as exc:
        raise Fault() from exc
    return match.end()


def scan_number(data, start):
    match = INTEGER.match(data, start)
    if match is None:
        raise Fault()
    end = match.end()
    if end < len(data) and data[end] in b"0123456789":
        raise Fault()
    if data[end:end + 1] == b".":
        fractional = DIGITS.match(data, end + 1)
        if fractional is None:
            raise Fault()
        end = fractional.end()
    if data[end:end + 1] in (b"e", b"E"):
        exponent = EXPONENT.match(data, end)
        if exponent is None:
            raise Fault()
        end = exponent.end()
    return end


def lex(data, offset):
    start = offset
    while start < len(data) and data[start] in WHITESPACE:
        start += 1
    if start == len(data):
        return (0, start, start)
    byte = data[start]
    if byte in PUNCT:
        return (PUNCT[byte], start, start + 1)
    if byte == ord('"'):
        return (1, start, scan_string(data, start))
    if byte in b"-0123456789":
        return (2, start, scan_number(data, start))
    for kind, name in enumerate((b"true", b"false", b"null"), 3):
        if data.startswith(name, start):
            return (kind, start, start + len(name))
    raise Fault()


def parse(data, frames):
    tokens = []
    position = 0

    def take():
        nonlocal position
        token = lex(data, position)
        position = token[2]
        return token

    def value(token, parent, depth):
        kind, start, end = token
        if kind in (1, 2, 3, 4, 5):
            tokens.append((*token, parent))
            return
        if kind not in (6, 8):
            raise Fault()
        if depth == frames:
            raise Fault(errno.ENOSPC)
        index = len(tokens)
        tokens.append(None)
        close = kind + 1
        child = take()
        if child[0] != close:
            while True:
                if kind == 6:
                    if child[0] != 1:
                        raise Fault()
                    tokens.append((*child, index))
                    if take()[0] != 10:
                        raise Fault()
                    child = take()
                value(child, index, depth + 1)
                child = take()
                if child[0] == close:
                    break
                if child[0] != 11:
                    raise Fault()
                child = take()
        tokens[index] = (kind, start, child[2], parent)

    value(take(), MASK, 0)
    if data[position:].strip(WHITESPACE):
        raise Fault()
    return tokens


def decode(packet, operation):
    layout, first, second, frame_byte, cap_byte, cut, opt, seed = packet[:8]
    mode = layout & 7
    if mode == 0:
        data = packet[8:8 + first % 57]
    else:
        index = first % len(DOCUMENTS)
        if mode == 1 and operation == "string":
            index = 2 + first % 2
        elif mode == 1 and operation == "number":
            data = (b"-" if first & 1 else b"") + str(int.from_bytes(packet[8:12], "little")).encode()
            if second & 1:
                data += b".025"
            if second & 2:
                data += b"e+09"
            return data, 0, frame_byte % 9, cap_byte % 8
        data = DOCUMENTS[index]
        if mode == 2:
            data = data[:cut % (len(data) + 1)]
        elif mode == 3:
            pos = cut % len(data)
            data = data[:pos] + packet[8:9] + data[pos + 1:]
        elif mode == 4:
            data = b" " * (seed % 4) + data
        elif mode == 5:
            data += packet[8:9]
        elif mode == 6:
            data = b"[" * (seed % 7) + data + b"]" * (seed % 7)
    offset = 0 if not (opt & 1) or operation == "parse" else second % (len(data) + 2)
    return data, offset, frame_byte % 9, cap_byte % 8


def observe(operation, packet):
    data, offset, frames, capacity = decode(packet, operation)
    words = [CANARY] * 28
    try:
        if offset > len(data):
            raise Fault(errno.EINVAL)
        if operation == "string":
            result = scan_string(data, offset)
        elif operation == "number":
            result = scan_number(data, offset)
        elif operation == "lex":
            words[:3] = lex(data, offset)
            result = 0
        elif operation == "parse":
            tokens = parse(data, frames)
            if len(tokens) > capacity:
                raise Fault(errno.ENOSPC)
            for index, record in enumerate(tokens):
                words[index * 4:index * 4 + 4] = record
            result = len(tokens)
        else:
            raise RuntimeError(f"unknown operation {operation!r}")
    except Fault as exc:
        result = -exc.code
    return struct.pack("<q29Q", result, errno.EDOM, *words)


if __name__ == "__main__":
    stream = sys.stdin.buffer.read()
    if len(stream) % 64:
        sys.exit(90)
    sys.stdout.buffer.write(b"".join(observe(sys.argv[1], stream[i:i + 64])
                                    for i in range(0, len(stream), 64)))

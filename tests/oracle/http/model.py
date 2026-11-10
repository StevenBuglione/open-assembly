#!/usr/bin/env python3
"""Packet model for the public bounded HTTP extension contract."""

import errno
from pathlib import Path
import re
import runpy
import struct
import sys

APP = runpy.run_path(str(Path(__file__).resolve().parents[2] / "phase10/http/oracle.py"))
TOKEN = re.compile(APP["TOKEN"])
LIMIT = APP["LIMIT"]
HEADS = (
    b"GET / HTTP/1.1\r\nHost:x\r\n\r\n",
    b"HEAD /?q HTTP/1.0\r\n\r\n",
    b"OPTIONS / HTTP/1.1\r\nHost:x\r\n\r\n",
    b"GET / HTTP/1.1\r\nHost:x:65535\r\nContent-Length:000\r\n\r\n",
    b"GET / HTTP/1.1\r\nHost:x:65536\r\n\r\n",
    b"GET / HTTP/1.1\r\nHost:x\r\nTransfer-Encoding:identity\r\n\r\n",
    b"GET / HTTP/1.1\r\nHost:x\r\nHost:y\r\n\r\n",
    b"GET / HTTP/1.0\r\nX:\t ~\r\n\r\n",
)


def span(packet):
    mode, first, second, replacement = packet[0] & 7, *packet[1:4]
    terminator = b"\r\n\r\n"
    if mode in (0, 5):
        data = packet[8:8 + first % 57]
        if mode == 5 and len(data) >= 4:
            index = second % (len(data) - 3)
            data = data[:index] + terminator + data[index + 4:]
        return data
    if mode in (6, 7):
        end = LIMIT - 8 + first % 17
        prefix = b"GET / HTTP/1.0\r\nPad:"
        closing = terminator if mode == 6 else terminator[:3] + bytes((second,))
        return prefix + b"x" * (end - len(prefix) - 4) + closing
    data = HEADS[first % len(HEADS)]
    if mode == 2:
        return data[:second % (len(data) + 1)]
    if mode == 3:
        index = second % len(data)
        return data[:index] + bytes((replacement,)) + data[index + 1:]
    if mode == 4:
        return data + packet[8:8 + second % 57]
    return data


def observe(operation, packet):
    if operation == "token":
        value = int(TOKEN.fullmatch(packet[1:2]) is not None)
    elif operation == "find":
        index = span(packet).find(b"\r\n\r\n")
        value = 0 if index < 0 else index + 4
    elif operation == "parse":
        value = APP["classify"](span(packet))
    else:
        raise RuntimeError(f"unknown HTTP operation {operation!r}")
    return struct.pack("<QQ", value, errno.EDOM)


if __name__ == "__main__":
    stream = sys.stdin.buffer.read()
    if len(stream) % 64:
        sys.exit(90)
    sys.stdout.buffer.write(b"".join(observe(sys.argv[1], stream[i:i + 64])
                                    for i in range(0, len(stream), 64)))

"""Independent unsigned minimum oracle for little-endian uint32 pairs."""

import struct
import sys

request = struct.Struct("<II")
result = struct.Struct("<I")
source = sys.stdin.buffer.read()
if len(source) % request.size:
    raise SystemExit(2)
sys.stdout.buffer.write(b"".join(result.pack(min(left, right)) for left, right in request.iter_unpack(source)))

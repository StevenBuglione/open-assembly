"""Construct DNS wire records with independently specified expected outcomes."""

import random
import socket
import struct

HEADER = struct.Struct("!6H")
FRAME = struct.Struct("<5I")
RESULT = struct.Struct("<iI")
BODY = struct.Struct("<II")
A, PTR, AAAA = 1, 12, 28
ID = 0x9c39
SEED = 0x8a2c6bc1


def labels(name):
    if name == b".":
        return b"\0"
    return b"".join(bytes([len(part)]) + part.lower() for part in name.rstrip(b".").split(b".")) + b"\0"


def query(name, qtype, ident):
    return HEADER.pack(ident & 0xffff, 0x0100, 1, 0, 0, 0) + labels(name) + struct.pack("!HH", qtype, 1)


def parse_name(wire):
    position = 0
    while position < len(wire):
        length = wire[position]
        position += 1
        if not length:
            return wire[:position], wire[position:]
        if length > 63 or position + length >= len(wire):
            break
        position += length
    raise ValueError("invalid expanded DNS name in a fixture response")


def unpack_query(raw):
    ident, flags, questions, answers, authority, additional = HEADER.unpack_from(raw)
    name, remaining = parse_name(raw[HEADER.size:])
    if (flags, questions, answers, authority, additional) != (0x0100, 1, 0, 0, 0):
        raise ValueError("unexpected DNS query header")
    qtype, qclass = struct.unpack("!HH", remaining)
    if qtype not in (A, PTR, AAAA) or qclass != 1:
        raise ValueError("unexpected DNS question type or class")
    return ident, name, qtype


def pointer(offset):
    return struct.pack("!H", 0xc000 | offset)


def rr(owner, kind, data, *, record_class=1):
    return owner + struct.pack("!HHIH", kind, record_class, 137, len(data)) + data


def reply(original, records=(), *, flags=0x8180, ident=None, question=None, count=None):
    original_id = struct.unpack_from("!H", original)[0]
    if ident is None:
        ident = original_id
    if question is None:
        question = original[HEADER.size:]
    return HEADER.pack(ident, flags, 1, len(records) if count is None else count, 0, 0) + question + b"".join(records)


def answer(kind, canonical, addresses):
    items = sorted({value.ljust(16, b"\0") for value in addresses})
    return BODY.pack(len(items), kind) + canonical + b"".join(items)


def build_record(name, kind, ident, capacity, expected):
    return FRAME.pack(0, len(name), capacity, kind, ident) + name, (len(expected), expected)


def parse_record(original, response, status, expected=b""):
    return FRAME.pack(1, len(response), len(original), 0, 0) + response + original, (status, expected)


def decoded(data, requests):
    cursor = 0
    results = []
    for row in requests:
        if len(data) - cursor < RESULT.size:
            raise ValueError(f"truncated fixture reply at record {len(results)}")
        status, size = RESULT.unpack_from(data, cursor)
        cursor += RESULT.size
        payload = data[cursor:cursor + size]
        cursor += size
        if len(payload) != size:
            raise ValueError(f"incomplete fixture payload at record {len(results)}")
        mode = FRAME.unpack_from(row[0])[0]
        if mode == 1 and status == 0:
            count, kind = BODY.unpack_from(payload)
            canonical, addresses = parse_name(payload[BODY.size:])
            if kind == PTR:
                _, excess = parse_name(addresses)
                if count != 1 or excess:
                    raise ValueError("invalid DNS PTR answer count or target extent")
            else:
                if len(addresses) != count * 16 or not 1 <= count <= 16:
                    raise ValueError("invalid DNS answer count")
                payload = answer(kind, canonical, [addresses[i:i + 16] for i in range(0, len(addresses), 16)])
                if BODY.unpack_from(payload)[0] != count:
                    raise ValueError("candidate returned duplicate DNS addresses")
        results.append((status, payload))
    if cursor != len(data):
        raise ValueError("unexpected trailing fixture reply bytes")
    return results


def directed():
    rows = []
    maximum = b".".join([b"a" * 63, b"b" * 63, b"c" * 63, b"d" * 61])
    for name in (b"Example", b"MiX.Example.", b"_srv.-route.012", maximum, b"."):
        for kind in (A, AAAA):
            expected = query(name, kind, ID)
            for cap in (0, len(expected) - 1, len(expected), len(expected) + 7):
                rows.append(build_record(name, kind, ID | 0xabc00000, cap,
                                         expected if cap >= len(expected) else b""))
    for name in (b"", b".a", b"a..b", b"a..", b"a/b", b"a b", b"a\xff", b"a" * 64, maximum + b"d"):
        rows.append(build_record(name, A, ID, 512, b""))
    for kind in (0, 2, 255):
        rows.append(build_record(b"example", kind, ID, 512, b""))

    q = query(b"alias.example", A, ID)
    owner = pointer(12)
    first, second = b"\xc0\x00\x02\x01", b"\xc6\x33\x64\x09"
    addr = rr(owner, A, first)
    complete = reply(q, (addr,))
    expected = answer(A, labels(b"alias.example"), (first,))
    rows += [
        parse_record(q, complete, 0, expected),
        parse_record(q, reply(q, (addr,), question=b"\x05ALIAS\x07ExaMple\0" +
                              struct.pack("!HH", A, 1)), 0, expected),
        parse_record(q, reply(q, (addr, rr(owner, A, second), addr)), 0,
                     answer(A, labels(b"alias.example"), (first, second))),
        parse_record(q, reply(q, (rr(labels(b"other.example"), A, second), addr)), 0, expected),
        parse_record(q, reply(q, (rr(owner, A, second, record_class=3),)), socket.EAI_NONAME),
        parse_record(q, reply(q), socket.EAI_NONAME),
        parse_record(q, reply(q, flags=0x8183), socket.EAI_NONAME),
        parse_record(q, reply(q, flags=0x8182), socket.EAI_AGAIN),
        parse_record(q, reply(q, flags=0x8185), socket.EAI_FAIL),
        parse_record(q, reply(q, flags=0x8380), 1),
        parse_record(q, reply(q, flags=0x8380, ident=ID + 1), 2),
        parse_record(q, reply(q, ident=ID + 1), 2),
        parse_record(q, reply(q, question=query(b"wrong.example", A, ID)[12:]), 2),
        parse_record(q, reply(q, question=query(b"alias.example", AAAA, ID)[12:]), 2),
        parse_record(q, reply(q, (rr(owner, A, b"\0\1\2"),)), socket.EAI_FAIL),
        parse_record(q, reply(q, (rr(pointer(0x3fff), A, first),)), socket.EAI_FAIL),
        parse_record(q, reply(q, (rr(pointer(len(q)), A, first),)), socket.EAI_FAIL),
        parse_record(q, reply(q, (rr(owner, 5, owner),)), socket.EAI_FAIL),
    ]
    # CNAME target uses a backward pointer to the original question's suffix.
    target = b"\x05final" + pointer(18)
    target_offset = len(q) + 2 + 10
    cname = rr(owner, 5, target)
    destination = rr(pointer(target_offset), A, first)
    rows.append(parse_record(q, reply(q, (cname, destination)), 0,
                             answer(A, labels(b"final.example"), (first,))))
    for cut in [*range(12), *range(len(q), len(complete))]:
        rows.append(parse_record(q, complete[:cut], socket.EAI_FAIL))
    q6 = query(b"v6.example", AAAA, ID)
    v6 = bytes.fromhex("20010db80000000000000000000000ff")
    rows.append(parse_record(q6, reply(q6, (rr(owner, AAAA, v6),)), 0,
                             answer(AAAA, labels(b"v6.example"), (v6,))))
    return rows


def sampled(count):
    rng = random.Random(SEED)
    rows = []
    owner = pointer(12)
    for index in range(count):
        kind = A if rng.randrange(2) else AAAA
        name = f"H{rng.randrange(65536):x}.x{index:x}.Example".encode()
        ident = rng.randrange(65536)
        q = query(name, kind, ident)
        choice = rng.randrange(6)
        if choice == 0:
            cap = len(q) + rng.randrange(-1, 3)
            rows.append(build_record(name, kind, ident, cap, q if cap >= len(q) else b""))
        else:
            width = 4 if kind == A else 16
            addresses = [rng.randbytes(width) for _ in range(1 + rng.randrange(7))]
            records = [rr(owner, kind, address) for address in addresses]
            records += [records[-1], rr(labels(b"other.example"), kind, rng.randbytes(width))]
            status, body = {
                1: (0, answer(kind, labels(name), addresses)),
                2: (0, answer(kind, labels(name), addresses)),
                3: (2, b""), 4: (1, b""), 5: (socket.EAI_FAIL, b""),
            }[choice]
            response = reply(q, records, flags=0x8380 if choice == 4 else 0x8180,
                             ident=(ident ^ 1) if choice == 3 else ident)
            if choice == 5:
                response = response[:-1]
            rows.append(parse_record(q, response, status, body))
    return rows


def ptr_directed():
    name = b"77.2.0.192.in-addr.arpa"
    q = query(name, PTR, ID)
    owner = pointer(12)
    target = b"\x05MiXeD\x07ExAmPlE\0"
    canonical = labels(name)
    expected = BODY.pack(1, PTR) + canonical + labels(b"mixed.example")
    record = rr(owner, PTR, target)
    # The first target may compress its suffix against an earlier RR owner.
    alias = labels(b"example")
    prior = rr(alias, A, b"\xc0\x00\x02\x01")
    compressed = rr(owner, PTR, b"\x05MiXeD" + pointer(len(q)))
    # Indirection through CNAME uses the selected target as canonical owner.
    cname = rr(owner, 5, b"\x05AlIaS" + pointer(12))
    cname_name = b"\x05alias" + canonical
    target_owner = pointer(len(q) + 12)
    forwarded = rr(target_owner, PTR, target)
    return [
        build_record(name.upper(), PTR, ID | 0x12340000, len(q), q),
        build_record(name, PTR, ID, len(q) - 1, b""),
        parse_record(q, reply(q, (record,)), 0, expected),
        parse_record(q, reply(q, (prior, compressed)), 0, expected),
        parse_record(q, reply(q, (record, rr(owner, PTR, labels(b"second.example")))), 0, expected),
        parse_record(q, reply(q, (cname, forwarded)), 0,
                     BODY.pack(1, PTR) + cname_name + labels(b"mixed.example")),
        parse_record(q, reply(q, (rr(labels(b"wrong.example"), PTR, target),)), socket.EAI_NONAME),
        parse_record(q, reply(q, (rr(owner, PTR, target, record_class=3),)), socket.EAI_NONAME),
        parse_record(q, reply(q, (rr(owner, PTR, b""),)), socket.EAI_FAIL),
        parse_record(q, reply(q, (rr(owner, PTR, target + b"\x01"),)), socket.EAI_FAIL),
        parse_record(q, reply(q, (rr(owner, PTR, pointer(len(q) + 12)),)), socket.EAI_FAIL),
        parse_record(q, reply(q, (record[:-1],)), socket.EAI_FAIL),
        parse_record(q, reply(q, flags=0x8380), 1),
        parse_record(q, reply(q, (record,), ident=ID ^ 1), 2),
        parse_record(q, reply(q, flags=0x8183), socket.EAI_NONAME),
        parse_record(q, reply(q, flags=0x8182), socket.EAI_AGAIN),
    ]


def ptr_sampled(count):
    rng = random.Random(SEED ^ 12)
    rows = []
    for index in range(count):
        name = f"{rng.randrange(256)}.{rng.randrange(256)}.0.192.in-addr.arpa".encode("ascii")
        target = f"Name{index}.H{rng.randrange(65536):04X}.EXample".encode("ascii")
        mixed = b"".join(bytes([len(part)]) + part for part in target.split(b".")) + b"\0"
        q = query(name, PTR, rng.randrange(65536))
        record = rr(pointer(12), PTR, mixed)
        expected = BODY.pack(1, PTR) + labels(name) + labels(target)
        choice = index % 4
        if choice == 1:
            record = rr(pointer(12), PTR, mixed[:-1])
        if choice == 2:
            record = rr(pointer(12), PTR, mixed, record_class=3)
        status, body = ((0, expected), (socket.EAI_FAIL, b""), (socket.EAI_NONAME, b""),
                        (2, b""))[choice]
        ident = (struct.unpack_from("!H", q)[0] ^ 1) if choice == 3 else None
        rows.append(parse_record(q, reply(q, (record,), ident=ident), status, body))
    return rows

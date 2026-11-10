"""Independent integer mixer and bounded map model for LP64 packet observations."""

from struct import Struct
import sys

REQUEST = Struct("<4Q")
RESPONSE = Struct("<q23Q24s")
U64 = 1 << 64
EINVAL, ENOSPC, ENOENT, EOVERFLOW, EDOM = 22, 28, 2, 75, 33


def first_slot(seed, key, capacity):
    state = seed ^ len(key) ^ 0xD915B31D72A14E87
    for byte in key:
        product = ((state + byte + 1) * 0xB7192A6F49D38BE5) % U64
        state = product ^ product // (1 << 27)
    product = ((state ^ state // (1 << 23)) * 0x9BE540C7D2F163A9) % U64
    return (product ^ product // (1 << 31)) % capacity


def initialize(flags, seed):
    mode = flags % 8
    if mode in (0, 7):
        capacity = 2 ** ((flags // 16) % 3)
        slots = [0] * (4 * capacity) + [0x9985172521] * (16 - 4 * capacity)
        return RESPONSE.pack(0, EDOM, 1, capacity, 0, seed, 0, 0, *slots, bytes(24))
    error = EOVERFLOW if mode in (3, 5) else EINVAL
    return RESPONSE.pack(-error, EDOM, 13, 17, 19, 23, 0, 0, *([0x9985172521] * 16), bytes(24))


def find_slot(slots, capacity, seed, key):
    first = first_slot(seed, key, capacity)
    tombstone = None
    for step in range(capacity):
        index = (first + step) % capacity
        item = slots[index]
        if item is None:
            return False, index if tombstone is None else tombstone
        if item == "removed":
            if tombstone is None:
                tombstone = index
        elif item[0] == key:
            return True, index
    return False, tombstone


def observe(operation, flags, seed, keys, value):
    if operation == "init":
        return initialize(flags, seed)
    capacity = 2 ** ((flags // 16) % 3)
    inserted = (flags // 256) % (capacity + 1)
    keys_bytes = keys.to_bytes(8, "little")
    universe = [bytes((keys_bytes[i], i, 0x80))[:2 + ((flags >> (16 + i)) & 1)] for i in range(4)]
    slots = [None] * 4
    backing = bytearray([0xCC] * 24)
    first = None
    for i in range(inserted):
        key = universe[i]
        _, index = find_slot(slots, capacity, seed, key)
        if first is None:
            first = index
        start = 3 * i
        backing[start:start + len(key)] = key
        slots[index] = key, start + 1, value ^ i
    if first is not None and flags & (1 << 12):
        slots[first] = "removed"
    used, limit = 3 * inserted, 3 * inserted + value % 8
    count = sum(item is not None and item != "removed" for item in slots)
    mode = flags % 16
    key = universe[keys % inserted] if inserted and mode != 1 else bytes((0x67, 0xE1, keys_bytes[4]))
    if mode == 2:
        key = b""
    out = 0x918501664FC00123
    if mode in (3, 5) or (operation == "get" and mode == 6):
        status = -EINVAL
    elif mode == 4:
        status = -EOVERFLOW
    else:
        present, index = find_slot(slots, capacity, seed, key)
        if operation == "probe":
            status = -ENOSPC if index is None else 2 * index + present
        elif operation in {"get", "remove"}:
            status = 0 if present else -ENOENT
            if present:
                if mode != 6:
                    out = slots[index][2]
                if operation == "remove":
                    slots[index] = "removed"
                    count -= 1
        elif index is None:
            status = -ENOSPC
        elif present:
            status = 0
            slots[index] = key, slots[index][1], value
        elif key and mode == 6:
            status = -EINVAL
        elif used + len(key) > limit:
            status = -ENOSPC
        else:
            status = 0
            slots[index] = key, used + 1 if key else 0, value
            backing[used:used + len(key)] = key
            used += len(key)
            count += 1
    words = []
    for item in slots:
        if item is None:
            words.extend((0, 0, 0, 0))
        elif item == "removed":
            words.extend((1, 0, 0, 0))
        else:
            key, offset, value = item
            words.extend((2, offset, len(key), value))
    return RESPONSE.pack(status, EDOM, 1, capacity, count, seed, used, out, *words, backing)


def main():
    operation, = sys.argv[1:]
    data = sys.stdin.buffer.read()
    if len(data) % REQUEST.size:
        raise SystemExit(2)
    sys.stdout.buffer.write(b"".join(observe(operation, *row) for row in REQUEST.iter_unpack(data)))


if __name__ == "__main__":
    main()

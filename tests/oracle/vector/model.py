"""Independent abstract vector and backing-byte model."""

from struct import Struct
import sys

REQUEST = Struct("<4Q")
REPLY = Struct("<q8Q64s80s")
EINVAL, ENOENT, ENOSPC, EOVERFLOW, ERANGE, EDOM = 22, 2, 28, 75, 34, 33


def observe(operation, flags, dimensions, limits, content):
    mode = flags % 8
    power = dimensions % 4 or int(operation == "reserve" and mode == 3)
    width = 2 ** power
    alignment = 2 ** ((dimensions // 16) % (power + 1))
    count = (dimensions // 256) % 4
    capacity = count + (dimensions // 4096) % 4
    raw = content.to_bytes(8, "little")
    old = bytearray(raw[i % 8] ^ ((i * 29 + 73) % 256) for i in range(64))
    arena = bytearray([0xCC] * 80)
    limit = limits % 64 + 8
    used = (limits // 256) % 8
    address = int(capacity != 0)
    output = 0xA5A5A5A5A5A5A5A5
    status = 0

    # The actual aligned array starts at 0 in this address-relative model.
    # The arena starts at byte 1 and carries an independent used count.
    start = (1 + used + alignment - 1) // alignment * alignment

    def reserve(requested, available=True):
        nonlocal capacity, used, address
        if requested <= capacity:
            return 0
        if not available:
            return -EINVAL
        needed = width * requested
        if needed >= (1 << 64):
            return -EOVERFLOW
        end = start + needed - 1
        if end > limit:
            return -ENOSPC
        arena[start:start + count * width] = old[:count * width]
        address, used, capacity = 129 + start, end, requested
        return 0

    if operation == "init":
        if mode in (1, 2, 3, 4, 5):
            status = -EINVAL
        else:
            count = capacity = address = 0
    elif operation == "reserve":
        if mode == 4:
            status = -EINVAL
        else:
            requested = {1: capacity, 2: capacity + 1, 3: (1 << 64) - 1}.get(mode, (limits >> 16) % 9)
            status = reserve(requested, mode not in (1, 2))
    elif operation == "push":
        if mode in (2, 3):
            status = -EINVAL
        else:
            element = bytes(old[(count - 1) * width:count * width]) if mode == 1 and count else raw[:width]
            if count == capacity:
                status = reserve(max(1, 2 * capacity), mode != 4)
                if status == -ENOSPC:
                    status = reserve(count + 1, mode != 4)
            if not status:
                data, base = (old, 0) if address == 1 else (arena, start)
                data[base + count * width:base + (count + 1) * width] = element
                count += 1
    elif operation == "pop":
        if mode == 3:
            status = -EINVAL
        elif not count:
            status = -ENOENT
        else:
            count -= 1
            popped = bytes(old[count * width:(count + 1) * width])
            if mode == 2:
                old[count * width + 1:(count + 1) * width + 1] = popped
            elif mode != 1:
                output = int.from_bytes(popped.ljust(8, b"\xa5"), "little")
    elif operation == "at":
        output = 208
        index = (limits >> 16) % 8
        if mode in (1, 2):
            status = -EINVAL
        elif index >= count:
            status = -ERANGE
        else:
            output = 1 + index * width
    else:
        raise ValueError(f"unknown vector operation {operation}")
    return REPLY.pack(status, EDOM, address, count, capacity, width, alignment, used, output, old, arena)


def main():
    operation, = sys.argv[1:]
    data = sys.stdin.buffer.read()
    if len(data) % REQUEST.size:
        raise SystemExit(2)
    sys.stdout.buffer.write(b"".join(observe(operation, *row) for row in REQUEST.iter_unpack(data)))


if __name__ == "__main__":
    main()

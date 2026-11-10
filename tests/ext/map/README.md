# Independent map verification

The public four-word state and slot layouts and the original mixer are
specified in [the package contract](../../../ext/map/README.md). The unit
cases use fixed collisions, empty and binary keys, exact arena bytes,
overflow checks and failure-preserved state. In the bucket-zero case,
one-byte keys `k` and `l` both start at slot zero for seed zero. A put
and remove leave a tombstone before a never-used slot. Probing for the
other key must return the tombstone index.

The guard case places a one-slot array and a read-only three-byte key
next to inaccessible pages on both edges. The SysV probe runs natively
and under QEMU, including a high-bit value and seed. Its nondefault x87
state control exceeds Memcheck emulation. The semantic and guard cases
still run under Memcheck.

The packet oracle models bounded linear probing, the documented mixer
and the arena's byte ownership independently in Python. Fixed little-endian
32-byte inputs select capacity, seed, occupancy, key bytes and update value.
216-byte results preserve exact status, errno, all four state words with
a normalized table pointer, the result value, every slot and all arena bytes.
Pointers into the arena are encoded as offsets plus one.

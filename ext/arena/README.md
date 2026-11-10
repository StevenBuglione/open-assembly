# Caller-owned arena

The caller provides three aligned size_t words and a backing
region. On x86-64 the words hold the base address, capacity and
used byte count in that order. Each call preserves errno and
returns zero or a negative error number. Calls on the same state
require caller synchronization. The state and output pointer
storage are separate from each other and from the backing region.

Arena_init sets the base and capacity and clears used. A null
state or a null backing address with nonzero capacity returns
-EINVAL. An extent that wraps the address space returns
-EOVERFLOW. Both failures preserve the state.

Arena_alloc requires a nonnull state and output pointer and a
positive power-of-two alignment. A used count above capacity or
an absent backing address with nonzero capacity returns -EINVAL.
The calculation checks the backing extent, aligned cursor and
new used count for overflow. An unrepresentable calculation
returns -EOVERFLOW. A representable allocation beyond capacity
returns -ENOSPC. State and output remain intact on failure.

Success stores the aligned pointer in the output and advances
used past a nonempty allocation. A zero-byte request leaves used
intact and can return a pointer one past the region. An empty
region with a null base can return null for a zero-byte request.
The package reads and writes state and output words only.

Arena_reset clears used and preserves the base and capacity.
It returns -EINVAL for a null state. The caller retains ownership
of the backing region throughout all operations.

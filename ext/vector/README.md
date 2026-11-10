# Arena-backed vectors

A vector has five caller-owned size_t words. On x86-64 these
hold the active data address, element count, capacity, element
size and alignment. Initialize the state with vector_init before
use, and keep its metadata and backing storage valid. A nonzero element size must be a multiple of its positive
power-of-two alignment. Calls preserve errno and return zero or
a negative error number. Shared state requires caller synchronization.

Reserve grows the vector to exactly the requested capacity when
necessary. The supplied arena provides the new buffer. An arena
is required only when reserve or push grows the vector. Existing elements
retain their values and earlier buffers remain in their arenas.
The caller keeps the active buffer valid until the next growth.
A failed reserve preserves both the vector and the arena.

Push copies one element and doubles capacity when growth is
needed, starting with one slot. When the arena lacks space for
geometric growth, push tries the exact next capacity. The source
may refer to an element of the current vector. Pop removes the
last element and can discard it with a null result pointer. The
copy permits overlap with the vector element storage.
An empty vector returns -ENOENT. At publishes a pointer for a
valid index or returns -ERANGE. A subsequent growth can change
the active element addresses.

A null required pointer or invalid initialization returns
-EINVAL. A capacity product that exceeds the address word
returns -EOVERFLOW. An exhausted arena returns -ENOSPC.
The state words, the supplied arena state and output metadata
are separate caller-owned objects.

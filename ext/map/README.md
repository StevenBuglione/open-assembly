# Bounded byte-key map

The caller provides four size_t state words and a slot array.
The state contains the slot address, capacity, live count and
hash seed. Each slot has four size_t words for its marker, key
address, key length and value. A marker of zero means never
used, one means removed, and two means live. The caller keeps
these objects and the key arenas valid while the map uses them.
Operations on the same map require caller synchronization.

Map_init requires a positive power-of-two capacity and clears
four slot words per entry. It publishes an empty state after
checking the slot extent. Key lookup starts with 64-bit FNV-1a
using the standard offset basis XOR the supplied seed. The low
bits select the first slot. Probing wraps at capacity and visits
each slot at most once. The first removed slot is available for
insertion once the search establishes that a key is absent.

Map_probe returns twice the slot index plus one for a live key,
or twice the reusable slot index for an absent key. A full
live table yields -ENOSPC for a missing key. Map_get and
map_remove return -ENOENT for any missing key. Remove can
discard its value by accepting a null output pointer.

Map_put updates an existing value in place. For a new nonempty
key it copies the bytes into the supplied arena and publishes
the slot after the copy. Empty keys consume no arena bytes.
The key length controls comparison, including embedded zeros.
Removing or replacing a key leaves its bytes in its arena.

All calls preserve errno. A null required pointer, null key
with nonzero length, or invalid capacity returns -EINVAL.
A wrapping address or size returns -EOVERFLOW. A failed update
preserves both states and any caller outputs.

[FNV-1a, RFC 9923](https://www.rfc-editor.org/rfc/rfc9923.html#section-2).

# Bounded byte slices

A slice pairs a byte pointer with its available length. A null
pointer represents an empty slice. A nonempty slice refers to
readable bytes in the caller's address space. Every call preserves
errno and returns zero or a negative error number. Output and
cursor metadata occupy separate caller-owned objects.

Slice_take publishes the current cursor, advances it by the
requested length and reduces available by the same amount. It
reads no bytes from the region. A zero-length take publishes
the cursor and retains both cursor and length.

Slice_find_byte returns the first offset containing a value
from zero through 255. An absent byte returns -ENOENT. A search
examines at most the supplied length. Slice_load_u32be loads
exactly four bytes as an unsigned big-endian value, with no
alignment requirement.

Invalid metadata pointers, a null base with nonzero length,
or a search value above 255 return -EINVAL. A wrapping address
extent returns -EOVERFLOW. An insufficient slice for take or
load returns -ERANGE. Failures leave output and cursor objects
unchanged.

# Independent open and openat additions

The original Phase 6 directed cases cover ordinary opens, error
translation, exclusive creation, mode and umask, relative and
absolute resolution, and both generated stubs. The original open
case also checks O_TMPFILE against the same filesystem's raw result.
These inputs remain in the verification suite.

The supplemental ABI cases reuse the existing variadic shims,
which set the vector-argument count. They poison the upper flag
and optional mode register bits, and openat also poisons the
directory descriptor. The shared SysV probe captures the signed
result and checks preserved state. The fixture observes creation
and O_TMPFILE modes, the directory-only flag pattern, a failed
open, errno, and the kernel close-on-exec setting. A raw O_TMPFILE
call on the same tmpfs is the filesystem capability reference.

The new timed fixture uses 16-byte little-endian input records and
64-byte responses. It creates only named test fixtures within its
working directory and uses unnamed temporary files on tmpfs.
The normalized result contains status, errno, mode, descriptor
and access flags, and regular-file extent, link count, and bytes.
The same fixture runs against the project, pinned glibc and pinned
musl. The original ABI cases and typed stubs are retained.

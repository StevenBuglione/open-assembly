# Public stream descriptor domain

The scoped `fileno` trace executes the nonnegative outcome of
`js .no_descriptor` on line 38. The taken outcome requires a negative
descriptor word in a stream that a caller may still use. This review
covers the shipped x86-64 Linux runtime and its opaque public `FILE`
type.

| Public entry | Descriptor when the stream becomes usable |
| --- | --- |
| `stdin`, `stdout`, `stderr` | 0, 1 and 2 from `__al_stdio_init`, which `_start` calls before `main`. The optional PIE entry reaches the same startup. |
| `fopen` | The nonnegative `__al_stdio_open` result passed to `__al_stream_init`. |
| `tmpfile` | The successful anonymous open or named temporary file descriptor passed to `__al_stream_init`. Unlinking the name preserves the descriptor. |
| `popen` | The selected parent descriptor from a successful `pipe2`, passed to `__al_stream_init`. |
| Successful `freopen` | The nonnegative replacement descriptor passed to `__al_stream_rebind` before releasing stream ownership. |

These entries exhaust the reviewed public constructors across the
inventoried declarations. The standard stream variables refer to the
three initialized objects. The declarations expose neither the object
layout nor a descriptorless constructor. See the [stdio ABI](../adr/0005-stdio-varargs.md),
[wide stream ABI](../adr/0021-wide-stream-orientation.md), and
[static PIE startup](../adr/0028-static-pie.md).

`__al_stream_init` calls `__al_stream_rebind` to install the association.
The reviewed runtime writes `-1` to the descriptor field only in
`__al_stream_close`. Its callers are `fclose`, `pclose`, and
`freopen`. Closing or failing to reassociate disassociates the stream
and ends the caller's right to use that handle. Rejection of an unrelated
stream by `pclose` leaves the association intact. Registry pins can
retain a retired object for internal work, while ownership serializes
successful reassociation with public access to the stream. Ordinary
byte and wide I/O, positioning, status indicators, and ownership
operations preserve the descriptor word. See [C17 §§7.21.3, 7.21.5.1 and 7.21.5.4](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf).

The threaded fork contract restricts child operations before `exec`
or `_exit` to the documented async-signal-safe subset. `fileno` is
outside that subset. A child snapshot taken during disassociation
therefore gives no additional legal `fileno` entry. A successful
`exec` initializes new streams. See the [threaded fork contract](../adr/0043-threaded-fork.md).

A kernel descriptor can be closed or replaced independently of a
stream. Such a change leaves the stream's descriptor word unchanged,
including for standard stream numbers that entered the process
closed. POSIX distinguishes a stream with no associated file from one
whose underlying descriptor is invalid. See [POSIX `fileno`](https://www.man7.org/linux/man-pages/man3/fileno.3p.html).

The stream verification runner compares the exact reviewed fingerprint
with a canonical path-to-SHA-256 map of the runtime assembly, assembly
includes, public specifications, generated C headers, runtime build
and declaration tooling, and the applicable ABI contracts and this
review. This intentionally requires a fresh review after any change to
those inputs, including a new constructor outside `stdio` or a
different lifetime transition. The gate preserves the raw trace at
1/2, reports 1/1 applicable only while the fingerprint matches, and
leaves the shared ownership and error helper proof pending.

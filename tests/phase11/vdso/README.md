# Independent vDSO clock checks

Run `./tools/container make phase11-vdso`. The guard-page fixture creates an
ELF64 image from the public ELF record formats. It checks the positive lookup
and rejects short ranges, malformed headers, invalid dynamic table ranges,
incorrect or undefined symbol names and types, and invalid version metadata.
Inputs are read-only and placed against each guard edge.

The native positive route verifies that the selected function points into
the original auxiliary-vector kernel mapping and that realtime succeeds
even when the raw fallback is forced to fail. It also checks the public
raw clock's inaccessible-pointer error. Other backends assert their
observed raw fallback route separately. The same suite tests missing,
unreadable, short, misaligned and overflowing auxiliary image addresses,
the 128-entry auxiliary vector bound, and raw error output preservation.

A synthetic read-only executable image supplies a callable entry that
records invocation and returns an error, requiring the raw fallback.
Other tests trigger a signal or fork during image resolution and check
reentry without waiting for the interrupted cache owner. These wrappers
are active only in the designated cases. The hosted check brackets both
public time results with realtime clock reads, and the generated public
`time` stub is rejected in the missing-image case.

[Linux vDSO ABI](https://man7.org/linux/man-pages/man7/vdso.7.html)
[ELF program headers](https://gabi.xinuos.com/elf/07-pheader.html)
[ELF dynamic records](https://gabi.xinuos.com/elf/08-dynamic.html)

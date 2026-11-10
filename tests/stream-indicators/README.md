# Independent stream indicator fixtures

The directed cases follow C17 §7.21.10, POSIX fileno and
[ADR 0005](../../docs/adr/0005-stdio-varargs.md). A separately
opened seekable memfd supplies binary bytes, EOF, and a
read-only stream for failed writes. The assertions distinguish
clean, EOF-only, error-only and simultaneous indicators.
They exercise the persistent error indicator through a seek
and confirm that clearerr preserves the current position,
pending pushback, buffered output and errno.

The borrowed fileno result is checked against the standard
descriptors and through Linux fcntl, lseek and pread on a
separate stream. Recursive explicit ownership exercises
fileno while the same thread holds the stream. A raw fcntl
query on the saved integer after fclose confirms that the
stream closed its descriptor and the separately opened memfd
remains live. The current public inventory has no constructor
for a live descriptorless FILE. The conditional fileno EBADF
path remains outside these public-input fixtures.

Sixteen-byte little-endian packets select bounded read counts,
failed writes, one pushback, a seek and a following read. The
64-byte result preserves normalized indicator values, associated
descriptor identity, errno and logical positions. The fixture
uses the same source with the candidate, pinned glibc and pinned
musl. The shared SysV state probe runs natively and under QEMU.
Its nondefault x87 control value exceeds Memcheck emulation.
The other cases still run under Memcheck.

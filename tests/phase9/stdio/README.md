# Independent wide stdio checks

Run `./tools/container make phase9-stdio`. The gate runs the unmodified pinned
libc-test `functional/swprintf.c`, `functional/fwscanf.c` and
`regression/fgetwc-buffering.c` with verified candidate symbol references.
It records their source hashes and runs the same binaries natively, under
QEMU user mode and under strict Memcheck.

The directed fixtures cover all 22 published basic and formatted wide stdio
entry points. The common cases also run against pinned glibc and musl. They
check UTF-8 stream reads and writes, field widths, wide-unit `%n`, explicit
va_list and direct variadic entry points, and mixed integer, double, and
extended arguments spilling from register arguments onto the stack.
Each public symbol has a direct generated-stub rejection.

Project cases cover terminated partial formatting, captured stream encoding,
byte orientation, pushback, error indicators, and byte positions with Unicode
lookahead. A test-only wrapper injects a single EAGAIN on one selected
unbuffered stream after its first UTF-8 byte. Its case tests the preserved
decoder state by observing positions and subsequent decoded characters.
Host comparisons omit these project-specific semantics.

[C17 wide formatted and unformatted I/O](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

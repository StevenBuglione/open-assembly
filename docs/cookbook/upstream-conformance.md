# Named gnulib and Linux Test Project subsets

Run `./tools/container make phase10-gnulib phase10-native-ltp`. The two
reports bind the pinned archive, each original test and supporting file,
compiled artifacts, runner, and observed outcomes. The upstream sources
are unpacked into temporary build storage. The test-only GNU GPL source
and executables are separate from the shipped assembly library.

The gnulib lane runs `test-lseek` on files, pipes, and closed descriptors.
It also runs `test-memchr` with its original inaccessible-page probes.
Both are compared with pinned glibc and musl. The `lseek` candidate uses
Open Assembly startup and archive. The `memchr` candidate links the
actual archive member with a test-only symbol name and static musl support
for `mprotect`. The name isolates the candidate call from musl's own calls.
The Linux test configuration enables guard-page support, and test-only
linker wrappers turn any failure to create or protect a guard into a
harness failure. The candidate cases also run under QEMU user mode and
Memcheck. Typed stubs must reach a named assertion in each original test.
[gnulib test sources at the pinned revision](https://github.com/coreutils/gnulib/tree/41bae5c2f367ca71652f3b1f98f1257035994acd/tests)

The native LTP lane runs the unmodified `dup01`, `dup02`, and `lseek01`
syscall tests, with pinned glibc and musl control builds. The small
compatibility header executes the selected LTP setup, assertions and
cleanup in an isolated temporary working directory. It requires exact
positive counts, distinguishes assertion failures from broken setup, and
checks the `dup01` and `lseek01` typed stubs against named assertions. This
lane covers these three native syscall tests. The Open POSIX test subset
has its own gate and evidence.
[Linux Test Project syscall sources at the pinned revision](https://github.com/linux-test-project/ltp/tree/2279d708c817db657611a30c427c7d06c4360049/testcases/kernel/syscalls)

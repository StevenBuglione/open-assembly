# Private Linux stat-query fixtures

The directed cases call the documented private helper with legal fstat and
newfstatat requests. Each success compares the full public stat record to
independent Linux calls. The exact linker witness forwards the syscall and
poisons only the reserved raw bytes after Linux succeeds. The caller record
must clear them. The same sequence verifies untouched output on kernel
errors and the documented null-result and selector rejection order.
The typed case captures the full long result with poisoned high selector bits.
[Project stat-query ABI](../../../docs/adr/0007-linux-files-process-signal-time.md)

The separate native seccomp case proves that real fstat and newfstatat
requests return raw -4095 and -EACCES under an installed filter. The helper
must translate both and preserve the entire output box. QEMU returns ENOSYS
and Memcheck reports unhandled syscall 317 when installing the filter.
The wrapped unit also checks the -4095 boundary using the same documented
Linux errno range. [Linux seccomp errno boundary](https://github.com/torvalds/linux/blob/f91a3aa6bce480fe6e08df540129f4a923222419/tools/testing/selftests/seccomp/seccomp_bpf.c#L923)

The timed fixtures reuse the frozen public stat packet dataset and its
16-byte input and 64-byte output. The candidate routes the two selectors
directly to the private helper. A separate hosted build uses raw Linux
calls, publishes the documented field ranges on success, and supplies the
comparison records without importing the helper.

Unit statuses 11–17 identify return and errno, success conversion, output
bounds or failure atomicity, syscall count, arguments, scratch separation,
and machine state. The generated zero stub has status 14 and empty streams.
Filter statuses 41–42 identify returned error and output atomicity. The
90s identify fixture setup, raw oracle, and cleanup failures.

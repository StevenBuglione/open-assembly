# Independent Phase 6 clock and sleep fixtures

The fixtures compare clock values with bracketing raw Linux time64
observations and resolutions with exact kernel results. Realtime and
process CPU values, signed LP64 storage, output sentinels, unsupported
bases, and success errno preservation are checked separately. Pinned
glibc sets EINVAL for an unsupported timespec_get base. The project
and musl preserve errno for that result. All three leave the output
untouched.

Sleep tests use monotonic elapsed time with a lower bound. A periodic
kernel alarm interrupts the relative and absolute requests without a
race on a one-shot alarm. The fixtures distinguish nanosleep's -1 and
errno from clock_nanosleep's positive error and preserved errno. Relative
interruption returns a remaining interval. Both successful and interrupted
absolute sleep leave the remaining-output slot untouched.

The test-only syscall wrapper is inactive until explicitly armed and
matches only a clock_gettime call with the requested clock ID and a
result pointer. It checks process CPU microsecond truncation and overflow,
realtime seconds above 32 bits, and kernel error behavior for clock,
time, and timespec_get. The ordinary clock cases link without the wrapper.
Each of the seven public APIs has an attributable generated stub rejection.

[Phase 6 time contract](../../../docs/adr/0007-linux-files-process-signal-time.md) ·
[Linux clock_gettime](https://man7.org/linux/man-pages/man2/clock_gettime.2.html) ·
[Linux clock_nanosleep](https://man7.org/linux/man-pages/man2/clock_nanosleep.2.html)

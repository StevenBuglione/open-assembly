# Warm vDSO realtime benchmark

Compare the warmed public `time(NULL)` call in the static Open Assembly
runtime with pinned static musl. Each sample calls `time` one million times
and verifies every returned second against a nearby raw clock observation.
The fixture installs a Linux seccomp filter that rejects raw `time` and
`gettimeofday`. Raw `clock_gettime` allows only the monotonic and thread
CPU timing clocks. Successful samples measure the realtime userspace path. The separate vDSO behavior
gate exercises fallback, signal reentry, and failed metadata lookup.

Run nine alternating pairs on one quiet native Linux CPU. Use the same
90% idle preflight and wall-time versus thread CPU-time control as the
[copy benchmark](../adr/0035-memcpy-dispatch.md). The Open Assembly median
must be at most 1.50 times the musl median. Startup, resolver cold work,
and filter setup are outside the measured interval. `clock_gettime` and
other public clock operations have their own scope.

Run `./tools/container make phase11-vdso-benchmark`. The report is written
to `build/evidence/phase11-vdso-benchmark.json`. A missing quiet core,
unavailable filter, or unavailable accelerated path makes the run
incomplete and returns a nonzero result.

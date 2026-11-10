# Linux file descriptor production checks

Run `./tools/container make production-linux-files` for `lseek`, `dup`, and
`dup2`. The checks link the real `crt1.o` and static archive and compare
independent Phase 6 fixtures with the pinned glibc and musl builds. The
existing descriptor and offset oracles, SysV probe, and typed zero-stub
rejections are also used by the earlier Phase 6 gate.

QEMU executes the original candidate's source-mapped entry in an isolated
fixture directory. Candidate coverage and mutation are reported for the
selected function. The normal and timed tests link the runtime and exercise
the common syscall and errno path. Each timed differential runs for at
least 60 seconds and compares deterministic input packets on the three
linked implementations. Descriptor results are expressed relative to the
observed input or target descriptor so unrelated process-local allocation
of file descriptor numbers does not affect the result.

Run `./tools/container make production-linux-io` for `read`, `write`,
`close`, `pread`, and `pwrite`. The batch checks independently authored
Phase 1 pipe, EOF, interruption, and descriptor-closing cases alongside
Phase 6 positional I/O and SysV state probes. Each gate runs a typed
zero-stub rejection, source-mapped QEMU coverage, and the 90% mutation
threshold. An entry observation is required even for functions with zero
conditional edges. The seeded descriptor packets compare the static
archive, glibc, and musl for at least 60 seconds per function.

Positional write packets use non-append file descriptions. Separate
project cases exercise append semantics on memfd and at the syscall
boundary. The append trace identifies its scoped test-only syscall
wrapper in the report. The current/old kernel and real seccomp gates
provide additional append observations under their own profiles.

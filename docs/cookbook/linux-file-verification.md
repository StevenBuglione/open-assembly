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

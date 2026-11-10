# Independent Phase 6 process fixtures

The fixture uses the public generated declarations and the separate raw Linux
test boundary. The same probes run with pinned glibc and musl headers and
binaries. The raw helper creates pipes and children when the public operation
under test requires a controlled process. Each of the seven public symbols
has a generated zero-stub rejection.

- The process identity tests compare the public results with Linux and check
  that success preserves errno. The fork case validates the parent and
  child IDs, fork's return split, inherited errno, private memory and TLS
  changes, a pipe transfer, and the raw child exit status.
- The pipe2 case verifies both descriptor flags and both access modes, empty
  nonblocking input, byte transfer and EOF. An invalid flag leaves the
  descriptor slots and adjacent sentinels unchanged.
- The waitpid case uses a blocked child so the WNOHANG observation is
  deterministic. It checks unchanged output for WNOHANG and errors, EINVAL,
  normal and signaled status with the public macros, and ECHILD after reaping.
  The wait case covers ordinary status and a null result pointer.
- The failed exec checks ENOENT and a kernel-rejected executable while
  preserving the process, caller vectors and an open descriptor. The
  successful exec replaces the fixture with itself using explicit argv and
  envp, checks a custom argv[0], verifies the old environment is absent,
  checks that a close-on-exec descriptor is gone, and reads a marker from
  an inherited descriptor. The successful exec process may continue as a
  native executable after QEMU or Memcheck passes it to the host kernel.

[Phase 6 process contract](../../../docs/adr/0007-linux-files-process-signal-time.md) ·
[Linux x86-64 syscall table](https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_64.tbl) ·
[POSIX exec](https://pubs.opengroup.org/onlinepubs/9799919799/functions/exec.html) ·
[POSIX wait and waitpid](https://pubs.opengroup.org/onlinepubs/9799919799/functions/wait.html)

# Independent process identity fixtures

The public signatures use signed 32-bit pid_t on the target.
The reference is the Linux getpid and getppid syscall result.
The direct SysV probe checks the low return word, preserved errno,
the shared register and floating controls, and both the current
process and a child with a guaranteed live parent. A current
parent outside the PID namespace can yield zero. The original
Phase 6 process cases retain their typed stub controls.

Each 16-byte input has two little-endian uint64 words for role
selection and errno. A raw fork produces a child or grandchild
while the intermediate parent waits. Results have eight
little-endian uint64 words for the role, public result equality
to the raw oracle, self validity, parent validity, expected
live-parent relation, entry errno, exit errno, and stable raw
identity before and after the public call. Two final little-endian
uint32 words hold the raw PID and PPID.

The candidate, glibc and musl compare the first 64 result bytes.
The raw final 8 bytes document observed identity diversity in
each execution. Child output uses a private pipe, and each
process is reaped before continuing. The packet source exits
silently with no input and never assumes a particular PID value.

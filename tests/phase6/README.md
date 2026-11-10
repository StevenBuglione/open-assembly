# Independent file and directory fixtures

The C fixtures use public headers generated from the Phase 6 specifications.
The same hosted probes use the pinned glibc and musl headers and binaries.
File fixtures are created by the raw Linux boundary. Result checks use raw
kernel metadata, descriptor state, byte transfers, or explicit POSIX
requirements. Successful cases remove their files and close their descriptors.

- `files.c` checks two-argument and mode-taking opens, relative and absolute
  `openat`, process-local umask, exclusive creation, close-on-exec, truncation,
  shared offsets and descriptor replacement, sparse offsets beyond 32 bits,
  pipe end order and blocking state, and removal of names while descriptions
  remain open. The Linux `O_TMPFILE` expectation is selected from the raw
  kernel result on the same directory. The process-local descriptor limit
  tests genuine pipe exhaustion and unchanged output.
- `stat.c` checks the x86-64 layouts of the public record and the independent
  kernel record, pathname and descriptor lookup, symlink following, empty
  pathname lookup with `AT_EMPTY_PATH`, all named fields, adjacent sentinels,
  and unchanged output after failed calls. The project build also checks the
  specified zero padding. The host comparisons cover the named fields.
- `directory.c` compares the name set, inode, record length and entry type to
  Linux `getdents64`, including a 255-byte name. It checks repeated EOF with
  preserved errno, descriptor ownership and close-on-exec, failed transfers,
  and a 150-entry directory spanning multiple project input buffers. The
  hosted comparisons cover shared semantics. The project-only fdopendir
  checks cover the declared close-on-exec and path-only descriptor policies.
- `fault.c` installs a one-shot linker wrapper around the private syscall
  boundary. The wrapper forwards ordinary calls and injects one specified
  result after the case arms it. The directory cases provide a short header,
  zero record length, a length exceeding the returned bytes, a missing NUL,
  and a name exceeding the public field. The pipe case returns `EMFILE`
  without modifying the caller array. The unwrapped cases exercise normal
  kernel operations independently.
- `abi.c` uses the inherited System V register and control-state probe. The
  variadic open calls use test assembly trampolines that set the vector
  argument count. The remaining functions use the generic integer/pointer
  caller. The manifest records the Valgrind limitations on control-state
  observation and process-local descriptor limits. All nineteen public
  symbols have a distinct generated stub control.

Primary references are the project ABI, Linux UAPI, and POSIX.

- [Phase 6 contract](../../docs/adr/0007-linux-files-process-signal-time.md)
- [Linux x86-64 stat UAPI](https://github.com/torvalds/linux/blob/master/arch/x86/include/uapi/asm/stat.h)
- [Linux file status flags](https://github.com/torvalds/linux/blob/master/include/uapi/asm-generic/fcntl.h)
- [Linux getdents64 record producer](https://github.com/torvalds/linux/blob/master/fs/readdir.c)
- [POSIX open and openat](https://pubs.opengroup.org/onlinepubs/9799919799/functions/open.html)
- [POSIX stat family](https://pubs.opengroup.org/onlinepubs/9799919799/functions/stat.html)
- [POSIX readdir](https://pubs.opengroup.org/onlinepubs/9799919799/functions/readdir.html)
- [System V AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI)

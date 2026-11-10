# Independent BusyBox compatibility API fixtures

The native, QEMU and Valgrind probes link to the candidate runtime. The
ordinary API cases also run against pinned glibc and musl. Each of the
fourteen public symbols has an independent generated zero-stub rejection.

- Path and descriptor probes compare kernel mode bits and the working-directory
  pathname, verify successful and failed terminal queries, preserve readlink
  sentinels, and exercise ioctl with a pointer payload and with no payload.
  The lexical and allocation probes check dirname and independently writable
  strdup storage.
- The getopt probe checks grouped options, attached and following arguments,
  a first operand, double-hyphen termination, unknown and incomplete options,
  and a reset during a group. The hosted environment sets
  `POSIXLY_CORRECT=1` to select glibc's POSIX ordering. On a missing final
  option argument, pinned musl advances optind to four. Glibc and the project
  advance it to three. The hosted musl case checks the result and optopt.
- The ordinary vasprintf case compares bytes, an ordered count store, a
  terminator, and ownership for both nonempty and empty output. The project's
  one-pass case places a count store inside a string argument. A formatting
  prepass would change the bytes before the real call's first conversion.
  The allocation fault probe injects one ENOMEM during a real buffer growth,
  verifies exactly one release of the old buffer, and checks the count stores
  on both sides of the failure.
- The unlocked byte-stream cases check unsigned byte results, EOF, error
  state, string output and character conversion. The lock observation
  fixture first verifies balanced lock hooks on a normal fgetc call.
  All four unlocked calls then complete with zero hook observations.

[Phase 6 compatibility contract](../../../docs/adr/0007-linux-files-process-signal-time.md) ·
[POSIX getopt](https://pubs.opengroup.org/onlinepubs/9799919799/functions/getopt.html) ·
[Linux ioctl UAPI](https://github.com/torvalds/linux/blob/master/include/uapi/asm-generic/ioctls.h)

# Phase 6 file, process, signal, and time ABI

The runtime remains x86-64 Linux LP64, static non-PIE and System V. Only
the existing private syscall layer executes kernel instructions. Wrappers
pass six machine-word arguments to `__al_syscall`, zero unused arguments,
and use `__al_syscall_result` for the ordinary `-1` and TLS errno convention.
Successful calls preserve errno. An API that returns an error number
directly keeps raw kernel status private and follows its own contract.
The project will verify Linux constants and structure layouts against
its pinned UAPI headers. [Linux x86-64 syscall table](https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_64.tbl)

## First file interfaces

The first slice contains `open`, `openat`, `creat`, `lseek`, `dup`,
`dup2`, `pipe`, `mkdir`, `rmdir`, and `unlink`. Public `off_t` is a
signed 64-bit `long`. Public `mode_t` is an unsigned 32-bit `int`.
Descriptors, flags, and `whence` are signed 32-bit `int` arguments.
The generated test and assembly headers declare the selected flags,
seek origins, and mode bits.

`open` and `openat` use Linux `openat`. `open` uses `AT_FDCWD` as its
directory descriptor. A relative path in `openat` uses the caller's
directory descriptor, and an absolute path follows the kernel's usual
rules. Consume the optional mode word only for `O_CREAT` or the complete
Linux `O_TMPFILE` bit pattern. `O_DIRECTORY` alone takes no mode word.
The kernel applies the umask and handles atomic descriptor flags.
`creat` opens with `O_WRONLY | O_CREAT | O_TRUNC`.
The named Linux subset exposes close-on-exec. Support for close-on-fork
requires separate kernel and descriptor-policy work.
[POSIX open](https://pubs.opengroup.org/onlinepubs/9799919799/functions/open.html) · [Linux open and openat](https://man7.org/linux/man-pages/man2/open.2.html)

`lseek` forwards the full signed offset and returns the full result.
It updates the shared open file description. The initial scope includes
`SEEK_SET`, `SEEK_CUR`, and `SEEK_END`. Linux hole and data seeks use
the filesystem's result. `dup` and `dup2` share the underlying offset
and status flags. `dup2` uses the kernel's atomic replacement and preserves
an existing descriptor when both arguments identify it. `pipe` writes
exactly two native 32-bit descriptors on success and leaves the array
unchanged on kernel failure.
[Linux lseek](https://man7.org/linux/man-pages/man2/lseek.2.html) · [Linux dup](https://man7.org/linux/man-pages/man2/dup.2.html) · [Linux pipe](https://man7.org/linux/man-pages/man2/pipe.2.html)

`mkdir` forwards the path and mode for kernel umask processing.
`rmdir` removes an empty directory. `unlink` removes a directory entry
and leaves any already-open description usable. These wrappers use
the kernel's path and permission checks and make one operation per call.
[Linux mkdir](https://man7.org/linux/man-pages/man2/mkdir.2.html) · [Linux rmdir](https://man7.org/linux/man-pages/man2/rmdir.2.html) · [Linux unlink](https://man7.org/linux/man-pages/man2/unlink.2.html)

The independent file probes should use temporary directory descriptors
and controlled file modes. Cover the two-argument open path, mode and
umask handling, exclusive creation, shared offsets, sparse seeks beyond
32 bits, descriptor replacement, the ordering of pipe ends, and errno
on success and failure. Use kernel results for filesystem-dependent
features. The tests should record any backend or filesystem skip.

## File information and directories

The next slice includes `stat`, `lstat`, `fstat`, and `fstatat`.
Use `newfstatat` for pathname variants and `fstat` for a descriptor.
The public x86-64 LP64 stat record is 144 bytes with eight-byte
alignment. The three timestamp fields use signed 64-bit seconds and
nanoseconds. Reserve the padding and trailing words.

| Field | Offset | Representation |
| --- | ---: | --- |
| `st_dev`, `st_ino`, `st_nlink` | 0, 8, 16 | unsigned 64-bit |
| `st_mode`, `st_uid`, `st_gid` | 24, 28, 32 | unsigned 32-bit |
| `st_rdev` | 40 | unsigned 64-bit |
| `st_size`, `st_blksize`, `st_blocks` | 48, 56, 64 | signed 64-bit |
| `st_atim`, `st_mtim`, `st_ctim` | 72, 88, 104 | two signed 64-bit words each |

A private wrapper owns the kernel record and the conversion into the
public record. Clear public padding and write results only after
a successful kernel operation. The independent layout test should
assert sizes, alignment, and every offset in both records. Treat symlink
following and descriptor-relative lookup as distinct operations.
[Linux stat](https://man7.org/linux/man-pages/man2/stat.2.html) · [x86-64 Linux stat UAPI](https://github.com/torvalds/linux/blob/master/arch/x86/include/uapi/asm/stat.h)

`opendir` opens a directory descriptor with close-on-exec, then
allocates an opaque `DIR`. `fdopendir` transfers ownership after a
successful stream creation. A private buffer holds `getdents64`
records. Before copying an entry, check that its length reaches the
name, stays within the bytes returned, and contains a terminating NUL.
The public `dirent` has a 64-bit inode and cookie, a 16-bit record
length, an 8-bit type, and a 256-byte name. Its field offsets are
0, 8, 16, 18, and 19. Treat the offset as a seek cookie. `readdir`
returns a pointer into the stream's own storage, reports EOF without
changing errno, and sets errno for errors. `closedir` releases the
descriptor and storage. Directory stream locking follows the existing
runtime hooks. The stream header places the lock and owned descriptor
at offsets 0 and 4, then the record cursor and byte count at 8 and 16.
Its public entry slot starts at 32, and its private 4096-byte kernel
buffer starts at 312. A successful `fdopendir` rejects path-only or
unreadable descriptors and sets close-on-exec before transferring
ownership. A malformed kernel record reports EIO and discards the
remaining entries in that batch.
[Linux getdents64](https://man7.org/linux/man-pages/man2/getdents.2.html) · [POSIX readdir](https://pubs.opengroup.org/onlinepubs/9799919799/functions/readdir.html)

## Processes and spawning

Use the x86-64 `fork` syscall for the initial single-thread runtime.
The child inherits its stack and TLS values in a separate address
space. The later threading work owns at-fork handlers and lock recovery.
`execve` passes the supplied argument and environment vectors to the
kernel. Its ordinary return is an error. Convenience wrappers can use
the runtime's `environ` and implement PATH search separately.
`waitpid` uses `wait4` without a resource-usage result. Preserve
the raw wait-status bits for the public macros. Test normal exit,
signaled exit, invalid child IDs, and `WNOHANG`.
[Linux fork](https://man7.org/linux/man-pages/man2/fork.2.html) · [Linux execve](https://man7.org/linux/man-pages/man2/execve.2.html) · [Linux wait](https://man7.org/linux/man-pages/man2/wait.2.html)

The first `posix_spawn` implementation can use fork and an error pipe
created with close-on-exec. The parent reads either EOF after exec or a
complete error word from the child. Move the handshake descriptor away
from file-action descriptors before the fork, apply file actions in
their registered order, and reap a child that reports setup failure.
The child uses prepared state and raw operations before exec. Handle
interrupted and short handshakes. Public errors are returned as positive
codes. Use separate opaque, 16-byte public attribute and file-action
objects with eight-byte alignment. Their internal state lives in
library-owned storage.
[POSIX posix_spawn](https://pubs.opengroup.org/onlinepubs/9799919799/functions/posix_spawn.html)

## Signals and non-local control flow

The public signal mask has 128 bytes of storage with 64 kernel-supported
signal bits in its first word. Conversion to the kernel's eight-byte
mask stays private. A public `struct sigaction` uses a union of handler
pointers at byte 0, the public mask at byte 8, flags at byte 136,
and a reserved restorer word at byte 144. The kernel x86-64 record
has its handler, flags, restorer, and mask at bytes 0, 8, 16, and 24.
The kernel call uses a mask size of eight. Handler installation adds
the private restorer when needed and uses the existing
`__al_rt_sigreturn` trampoline. User handlers enter through the
kernel's System V ABI frame. Test mask round trips, real signal delivery,
restart policy, and three-argument handler dispatch.
[Linux sigaction](https://man7.org/linux/man-pages/man2/sigaction.2.html) · [Linux sigreturn](https://man7.org/linux/man-pages/man2/sigreturn.2.html)

A jump buffer stores RBX, RBP, R12 through R15, the caller's resumed RSP,
and the return PC in eight successive words with eight-byte alignment.
A signal-aware buffer adds a four-byte saved-mask indicator at byte 64
and a 128-byte mask at byte 72. Test
declarations mark the save routines as returning twice and the restore
routines as non-returning. Restore a zero requested result as one.
Ordinary jumps preserve the current signal mask and floating-point
control state. Signal-aware jumps restore a saved mask when requested.
The checker needs a dedicated validated resume sequence for the indirect
transfer. Add tests for nested contexts, live saved registers, volatile
C locals, and mask restoration.
[C17 non-local jumps](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf) · [AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI)

## Time and zone data

Public `time_t` is a signed 64-bit `long`. Public `timespec` uses two
signed 64-bit fields at bytes 0 and 8. Implement clock queries and
nanosleep through the private time64 kernel boundary, including remaining
time after `EINTR`. Calendar conversion uses checked Gregorian arithmetic
for timestamps on both sides of the Unix epoch. Differential tests should
use fixed timestamps and explicit time zones. Timer tests should compare
monotonic intervals with tolerances and handle interruption.

The calendar record uses nine consecutive 32-bit integers from `tm_sec`
through `tm_isdst`, then a signed offset in seconds at byte 40 and a zone
abbreviation pointer at byte 48. Its LP64 size and alignment are 56 and 8.

For local time, consume TZif using bounded input and checked byte counts.
Use the 64-bit transition block when present. Validate transition order,
type indices, string offsets, and the format version before publishing a
parsed zone. Apply the trailing POSIX rule when it governs timestamps
beyond the recorded transitions. An empty `TZ` selects UTC. An absent
`TZ` reads the system zone file. If a selected zone is unavailable or
invalid, the initial policy falls back to UTC. Keep POSIX leap-free
timestamps separate from leap-second metadata in TZif.
Keep zone storage ownership and synchronization separate from clock syscalls.
[TZif format](https://www.rfc-editor.org/rfc/rfc9636.html) · [Linux clock_gettime](https://man7.org/linux/man-pages/man2/clock_gettime.2.html)

The Phase 6 exit gate is a pinned BusyBox applet subset linked against the
actual freestanding runtime. Choose its configuration by auditing the
applets' unresolved symbols and record the build and executable hashes.
The file slice's independent probes give component evidence. The applet
gate and later ABI slices each require their own execution evidence.

## Phase 6 BusyBox compatibility batch

The pinned source for the candidate applet gate is BusyBox 1.37.0.
Its compressed source SHA-256 is
`3311dff32e746499f4df0d5df04d7eb396382d7e108bb9250e7b519b837043a4`.
The initial build configuration selects cat, wc, mkdir, rmdir, pwd,
and ls plus the BusyBox dispatcher. Disable the default shell and
build the target applets with `-ffreestanding -fno-builtin -fno-pie`.
Hosted compilation uses pinned musl C declarations. Replay Kbuild's
exact object and archive list with Open Assembly startup and archive.
The candidate link may use the selected upstream BusyBox object files
and Open Assembly runtime only. GNU C source remains outside the
runtime and serves as a build and application test fixture.

The stat and directory slice provides closedir, lstat, opendir,
readdir, and stat. Provide chmod, getcwd, isatty, readlink, and umask
through the existing syscall boundary. isatty uses an independent
bounded termios record and sets errno for a failed terminal query.
readlink returns a byte count and writes no terminator. getcwd supports
the Linux allocator convention when buf is null and the ordinary
caller-owned form. With buf null and size zero, allocate enough for
Linux's direct getcwd limit. Validate nonnull buffer size and preserve
errno on successful operations.

Provide dirname, getopt, and strdup under their named POSIX headers.
The lexical dirname may mutate a caller buffer and returns a stable
dot string when no directory component exists. The getopt state
includes the four conventional exported data objects. Implement POSIX
stop-at-first-operand semantics, grouped options, `--`, missing and
unknown-option state, and the leading-colon diagnostic policy. Use
optind=1 as initialization and optind=0 as an explicit extension reset.
Use one allocation for strdup and copy the terminator.

Expose ioctl and the nonstandard unlocked byte-stream variants under
a named Linux compatibility inventory. The initial ioctl contract
forwards a Linux 32-bit command and its machine-word payload. No-payload
commands ignore the third machine word. The unlocked functions use
the stream primitives without acquiring the global stdio lock. The
caller owns synchronization of concurrent operations on the stream.

The vasprintf sink grows its buffer and executes the formatter exactly
once. It returns an owned NUL-terminated allocation, including for
empty output, and sets the output pointer to null on failure. Every
format conversion and `%n` side effect occurs in ordinary format order.
Use the same byte, integer, and floating conversions as the integrated formatter.
Allocation or formatting failure releases temporary storage while
preserving errno. Exercise allocator faults and `%n` side effects in
independent tests.

[BusyBox source and license](https://busybox.net/downloads/)
[Linux ioctl](https://man7.org/linux/man-pages/man2/ioctl.2.html)
[Linux unlocked stdio](https://man7.org/linux/man-pages/man3/unlocked_stdio.3.html)

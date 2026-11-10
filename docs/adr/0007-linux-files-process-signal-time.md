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

## Temporary files and name changes

`rename` forwards one Linux atomic rename operation. `remove` first
attempts unlink. An EISDIR result selects removal of an empty directory.
Existing open file descriptions stay usable after either operation.

`mkstemp` replaces six final X bytes with random alphanumeric bytes from
Linux getrandom, then creates a read-write file with O_CREAT and O_EXCL.
It uses mode 0600 and retries collisions with new randomness. A failed
name attempt restores the placeholders. `tmpfile` opens an anonymous
inode in `/tmp` where supported. Its fallback uses the same exclusive
name creation, sets close-on-exec atomically, and unlinks the name before
publishing the binary update stream. The stream owns its descriptor.
[Linux getrandom](https://man7.org/linux/man-pages/man2/getrandom.2.html) · [Linux temporary files](https://man7.org/linux/man-pages/man2/open.2.html)

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

## Variadic descriptor control

`fcntl` chooses its variadic argument type from the command. Descriptor
and status queries and pipe-size queries take no argument. Descriptor
duplication, flag setters, simple owner setting, and pipe-size setting
take a promoted signed `int`. Process and OFD record locking use a
pointer to `struct flock`. Extended owner operations use a pointer
to `struct f_owner_ex`. Unknown commands return EINVAL before
forwarding anything to Linux.

The public LP64 lock record occupies 32 bytes. Lock type and origin
are signed shorts at offsets 0 and 2. The signed start and length
are eight-byte values at offsets 8 and 16. The process ID is a
signed int at offset 24. The owner record uses two signed ints at
offsets 0 and 4. F_GETOWN obtains the typed owner record first, then
returns the signed process or group ID separately from the kernel
status. If the group ID would produce the reserved return value -1,
report EOVERFLOW and use F_GETOWN_EX to obtain the identity.
Blocking lock calls retain Linux EINTR behavior.
[Linux fcntl UAPI](https://github.com/torvalds/linux/blob/master/include/uapi/asm-generic/fcntl.h) ·
[POSIX fcntl](https://pubs.opengroup.org/onlinepubs/9799919799/functions/fcntl.html)

## Processes and spawning

The x86-64 `fork` syscall supplies the raw process snapshot. The
child inherits its stack and TLS values in a separate address space.
Public `fork` uses the [threaded fork guards and callbacks](0043-threaded-fork.md).
`_Fork` is the callback-free, async-signal-safe entry.
`execve` passes the supplied argument and environment vectors to the
kernel. Its ordinary return is an error. `execv` uses the runtime's
`environ`. `execvp` and `posix_spawnp` search the calling environment's
PATH when the name contains no slash. Search left to right and treat empty
elements as the current directory. An unset PATH selects `/bin:/usr/bin`.
Keep at most 4095 pathname bytes plus the terminator per candidate. If all
candidates exceed that bound, return ENAMETOOLONG. Continue past ENOENT and
ENOTDIR, and return EACCES if a candidate was denied and none succeeds.
Other kernel errors terminate the search. For ENOEXEC, `execvp` invokes
`/bin/sh` with the candidate and arguments after the original argv[0].
`posix_spawnp` reports ENOEXEC through the child handshake. It uses the
caller's PATH and passes the supplied envp to the new image. The parent
prepares pathname storage before fork. The child searches after applying
attributes and file actions, without allocating. PATH callers must
serialize concurrent mutation of the environment.
[Linux exec](https://man7.org/linux/man-pages/man3/exec.3.html) ·
[POSIX spawn](https://pubs.opengroup.org/onlinepubs/9799919799/functions/posix_spawn.html) ·
[Austin Group ENOEXEC interpretation](https://www.austingroupbugs.net/view.php?id=1674)
`pid_t` is a signed 32-bit integer. `getpid` and `getppid` make raw
Linux queries and preserve errno. `pipe2` creates the two descriptors
with atomic flags and preserves its output array on error. The selected
POSIX flags are close-on-exec and nonblocking. Linux-specific flags are
validated by the kernel, and close-on-fork is outside this Linux slice.
`waitpid` uses `wait4` without a resource-usage result. Preserve
the raw wait-status bits for the public macros. A zero `WNOHANG` result
leaves output untouched, as does an error. Test normal exit,
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
library-owned storage. File actions support close, dup2, and open.
Open actions copy the path at registration. A same-descriptor dup2
validates the descriptor and clears close-on-exec. The selected flags
are reset IDs, set process group, set default dispositions, and set
signal mask. Child signal delivery stays blocked through descriptor and
attribute setup. The parent restores its own mask and publishes a child
ID only after the handshake succeeds.
[POSIX posix_spawn](https://pubs.opengroup.org/onlinepubs/9799919799/functions/posix_spawn.html)

## Positional I/O, mapping, and wall time

The Linux AMD64 LP64 interface exports pread, pwrite, ftruncate,
access, fchmod, fchown, geteuid, and fsync. The generated declarations
keep file offsets and transfer sizes at 64 bits. Descriptor and
access-mode arguments retain their C integer widths. The value
(uid_t)-1 or (gid_t)-1 keeps the corresponding ownership field.
Access queries real IDs. The selected sysconf queries are
_SC_PAGESIZE and _SC_PAGE_SIZE, both sourced from AT_PAGESZ.
Other names return EINVAL in this scope.

Positional I/O keeps the open file description's current offset.
A negative pwrite offset returns EINVAL even for zero bytes. A
zero-byte pwrite uses the kernel positional write boundary and
does not change the contents or offset of a regular file. Nonempty
pwrite uses pwrite64 on a description without O_APPEND. A description
with O_APPEND uses pwritev2 with RWF_NOAPPEND on a supported filesystem.
When the kernel lacks this operation or the file is on OverlayFS,
the append case returns EOPNOTSUPP before any data transfer. On Linux
6.18.59 with the pinned container, a raw RWF_NOAPPEND control honored
the position on tmpfs and the ext-family checkout mount. On OverlayFS
it returned success while appending instead. This scope does not
serialize changes to O_APPEND made concurrently by another owner of
the open file description.
[Linux positional writes](https://man7.org/linux/man-pages/man2/writev.2.html)

The mapping interface uses byte offsets and returns MAP_FAILED for
kernel errors. The Linux mremap extension reads its optional new
address only with MREMAP_FIXED. It retains the native kernel behavior
for overlap, alignment, and resize flags.

The generated sys/types.h uses project LP64 types throughout. The
sys/time.h and time.h declarations share the time_t type. timeval contains
two signed eight-byte fields for seconds and microseconds. The
gettimeofday compatibility function retains the historical Linux
timezone argument. utimes accepts either two timeval values or a
null pointer for the current time. The C17 localtime entry uses
static result storage and the same civil-time engine as localtime_r.
[Linux gettimeofday](https://man7.org/linux/man-pages/man2/gettimeofday.2.html) ·
[Linux mremap](https://man7.org/linux/man-pages/man2/mremap.2.html)

## Shell commands and pipe streams

`system` and `popen` execute the system command interpreter at `/bin/sh`.
A child-side shell execution failure has exit status 127. `system` serializes
temporary SIGINT and SIGQUIT dispositions, blocks SIGCHLD in the waiting
thread, and restores the inherited child mask and dispositions before exec.
`popen` creates a one-way pipe, redirects the child's input or output, and
closes older pipe streams in the child. The optional `e` mode keeps the
parent descriptor close-on-exec. A pipe stream stores its child PID in the
private stream record at byte 88. `pclose` removes the stream from the
registry, closes it, and waits for that PID with the stdio lock released.
[Linux system](https://man7.org/linux/man-pages/man3/system.3.html) · [Linux popen](https://man7.org/linux/man-pages/man3/popen.3.html)

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
kernel's System V ABI frame. The public `siginfo_t` is 128 bytes with an
eight-byte alignment. The signal number, error, and code are 32-bit words
at bytes 0, 4, and 8. For sender information, the process ID and user ID
appear at bytes 16 and 20. Public signals occupy the full Linux range
1 through 64. Host libraries may reserve their own internal signal numbers.
A successful mask read clears the high public words. The kernel handles
uncatchable dispositions and unmaskable signals. Test mask round trips,
real signal delivery, restart policy, and three-argument handler dispatch.
[Linux sigaction](https://man7.org/linux/man-pages/man2/sigaction.2.html) · [Linux sigreturn](https://man7.org/linux/man-pages/man2/sigreturn.2.html)

A jump buffer stores RBX, RBP, R12 through R15, the caller's resumed RSP,
and the return PC in eight successive words with eight-byte alignment.
The ordinary buffer occupies 64 bytes. A signal-aware buffer adds a
four-byte saved-mask indicator at byte 64 and a 128-byte mask at byte 72,
for a total of 200 bytes. Both have eight-byte alignment. Jump targets
must still be live in the same thread. Test
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
signed 64-bit fields at bytes 0 and 8. `clockid_t` is signed 32-bit and
`clock_t` is signed 64-bit. Clock queries and sleep operations use the
private time64 kernel boundary. Relative sleep publishes a remaining
interval after `EINTR`; absolute sleep leaves it untouched. `clock_nanosleep`
returns the positive error code while preserving errno. `clock` reports
process CPU time with one million ticks per second. `time` and
`timespec_get(TIME_UTC)` use realtime seconds. `difftime` computes the full signed integer difference before rounding
to double. UTC conversion uses checked Gregorian arithmetic for timestamps
on both sides of the Unix epoch. A 400-year era has 146097 days. There
are 719528 days from 0000-01-01 to the Unix epoch. Leap years are
multiples of four, with the century exception and the 400-year exception. Differential tests should
use fixed timestamps and explicit time zones. Timer tests should compare
monotonic intervals with tolerances and handle interruption.

The calendar record uses nine consecutive 32-bit integers from `tm_sec`
through `tm_isdst`, then a signed offset in seconds at byte 40 and a zone
abbreviation pointer at byte 48. Its LP64 size and alignment are 56 and 8.

`strftime` supports the C17 C locale conversions. Expand its compound
forms through the same bounded renderer. Reserve the destination
terminator before writing the first byte. The year and ISO week-year use
at least four magnitude digits, with a sign for negative years. The
two-digit forms use a nonnegative modulo 100. A negative `tm_isdst`
makes the zone unavailable. Otherwise `%z` uses `tm_gmtoff` with minute
precision when the hour magnitude fits two digits, and `%Z` uses the
null-terminated `tm_zone` when present. Unsupported conversion sequences
return zero. [C17 time formatting](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

For local time, consume TZif using bounded input and checked byte counts.
Use the 64-bit transition block when present. Validate transition order,
type indices, string offsets, and the format version before publishing a
parsed zone. Apply the trailing POSIX rule when it governs timestamps
beyond the recorded transitions. An empty `TZ` selects UTC. An absent
`TZ` reads the system zone file. If a selected zone is unavailable or
invalid, the initial policy falls back to UTC. Keep POSIX leap-free
timestamps separate from leap-second metadata in TZif.
A file-backed zone is a regular file of at most 1 MiB. Open it without
blocking, read its exact declared extent, and reject an incomplete record.
Absolute paths are read directly. Relative zone names use
`/usr/share/zoneinfo`, then `/etc/zoneinfo` for distributions with that
layout. An initial colon selects file interpretation.
Other TZ values may select an explicit POSIX rule. Rule designations
have three through 63 ASCII characters. Support month/week/weekday
and both year-day rule forms. An omitted DST schedule uses the March
and November US transitions. A TZif v3 or v4 footer supports signed
transition times through 167 hours. A validated cached
zone owns its bytes until the environment value changes. A zone
abbreviation remains usable until the caller changes TZ. Serialize zone
replacement and conversion. Application code must synchronize concurrent
changes to the environment.

`localtime_r` adds the selected offset with checked signed arithmetic
before applying the existing UTC Gregorian conversion. It publishes the
offset, DST flag, and abbreviation with the calendar fields. `mktime`
first normalizes arbitrary signed calendar fields. It checks candidate
UTC instants against the zone rather than accepting an offset from the
caller. A supplied DST flag selects a matching candidate when available.
An unspecified fold selects the earlier instant. An unspecified gap
normalizes forward from the pre-transition offset. Return an exact
`time_t` and preserve errno on success, including a result of minus one.
Leave the caller's record unchanged on representation failure.
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

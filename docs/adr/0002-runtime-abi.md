# Linux x86-64 startup and runtime ABI

Open Assembly links ELF64 static non-PIE executables with the System V AMD64
calling convention. Link the startup object explicitly and the runtime archive
after application objects; use `_start` as the ELF entry. No dynamic loader,
host CRT, or host libc is part of the executable. The entry point and TLS
layout follow the [AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI).

At `_start`, Linux supplies a 16-byte-aligned stack containing a machine-word
`argc`, `argv` entries and their null terminator, `envp` entries and their null
terminator, then `Elf64_auxv_t` pairs ending in `AT_NULL`. The runtime clears
DF and calls `main` using the ordinary System V function ABI with
`int argc`, `char **argv`, and `char **envp`. A two-argument C `main` ignores
the third register. Returning from `main` passes its `int` result to `exit`.
The private pointer objects `__al_initial_envp` and `__al_auxv` retain the
original vector addresses. Only startup writes the objects; they do not serve
as mutable environment variables. The stack strings and vectors retain their
initial lifetimes. Initialization and finalization arrays are deferred.

Phase 3 initializes the public `environ` variable after TLS and before `main`.
It starts with a shallow copy of the `envp` pointer vector. The original
stack vector and its following auxiliary vector remain available through
the established private pointers. See [the allocator and environment
contract](0004-allocator-environment.md).

Phase 4 initializes the three standard streams after the environment and
before calling `main`. Normal exit flushes streams after the registered
callbacks have run. [Byte streams and variadics](0005-stdio-varargs.md)

The first thread has one anonymous writable allocation for the thread control
block and optional executable `PT_TLS` image. FS base is the thread pointer,
installed using [Linux `ARCH_SET_FS`](https://docs.kernel.org/6.6/arch/x86/x86_64/fsgs.html).
The compiler ABI is compatible at the offsets below; the rest of the block is
private to this runtime.

| Offset from FS base | Field |
| --- | --- |
| `0x00` | Thread pointer (self) |
| `0x10` | Self, also at the GNU thread descriptor offset |
| `0x28` | Stack guard: first `AT_RANDOM` word with its low byte cleared |
| `0x30` | Pointer guard: second `AT_RANDOM` word |
| `0x40` | Four-byte `errno` object, initially zero |

The executable's local-exec TLS image is below the thread pointer. Startup
locates `PT_TLS` via `AT_PHDR`, `AT_PHENT`, and `AT_PHNUM`, copies `p_filesz`
bytes from `p_vaddr`, and leaves the remainder zero, including `.tbss`.
The thread pointer is aligned to at least 16 bytes and to the TLS segment's
alignment. The image has the same address residue modulo `p_align` as
`p_vaddr`; the distance from the image to the thread pointer is
`align_up((p_vaddr mod p_align) + p_memsz, p_align) - (p_vaddr mod p_align)`.
This is the variant II offset used by the static linker. `p_align` of zero
or one means no alignment constraint. There is no dynamic TLS lookup in
Phase 1. `__errno_location()` returns the writable thread's `int *`; no
global or shared fallback exists. Invalid or missing bootstrap metadata, a
failed TLS mapping, or failure to set FS abort startup through `__al_panic`.

Only `src/x86_64-linux/internal/` executes kernel instructions. The private
System V function `long __al_syscall(long nr, long a1, long a2, long a3,
long a4, long a5, long a6)` takes all seven arguments (unused arguments are
zero), moves argument four to `r10`, and returns the raw kernel word in
`rax`. `rcx` and `r11` are clobbered. `long __al_syscall_result(long result)`
converts values from `-4095` through `-1` to `-1` and writes their positive
error number to TLS; it returns other values unchanged and preserves `errno`.
`close`, `read`, and `write` forward one operation, preserving Linux short
I/O, `EINTR`, and other error behavior without an internal retry. Public
wrappers extend the signed `int` descriptor before using the kernel ABI.

`_exit` terminates the process through Linux `exit_group`; the low eight
status bits are visible to its parent. If `exit_group` unexpectedly returns,
the runtime tries the single-thread `exit` syscall, then traps if that
returns too. `_Exit` delegates to `_exit`. Neither invokes termination
callbacks. `exit` invokes the `atexit` registrations in reverse order before
`_exit`. There are 32 pending slots. A callback may register another
callback; the running callback's slot has already been freed and the new
registration participates in LIFO order. An `exit` call from a callback is
outside the C17 contract. The registry calls the private lock hooks around
updates and releases the lock before user code. The hooks take a pointer to
a zero-initialized, four-byte lock word. The threading contract makes
them live for the initial thread as well as workers.
[Thread lifecycle and locks](0010-thread-lifecycle-locks.md)

`__al_panic(const char *message, size_t length)` makes a best-effort write of
the supplied bytes to standard error and exits with status 127. It requires
neither initialized FS nor libc streams. The compiler entry `__stack_chk_fail`
uses the same diagnostic path for `open-assembly: stack smashing detected\n`,
then forces the default `SIGABRT` disposition, unblocks that signal on the
current thread, and sends it to that thread. If the kernel does not terminate
the process, the failure path exits with status 134. No fatal path runs exit
callbacks. This diagnostic path is the crash-reporting foundation; unwinding,
automatic crash signal handlers, and public signal APIs are deferred.

`__al_rt_sigreturn` is an x86-64 Linux `SA_RESTORER` entry for
`rt_sigaction`; it must be used as a restorer address rather than called as a
System V function. Linux requires the original signal-frame stack on entry.
The restorer invokes `rt_sigreturn` directly and traps if it ever returns.
The [Linux x86-64 signal interface](https://github.com/torvalds/linux/blob/master/arch/x86/include/uapi/asm/signal.h)
uses an eight-byte kernel signal mask and the kernel `sigaction` layout;
neither is a promise about the future public libc types.

The [Linux x86-64 syscall table](https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_64.tbl)
and Linux UAPI headers define the kernel numbers, masks, and structures;
the [ELF specification](https://gabi.xinuos.com/elf/07-pheader.html) defines
program-header fields. The bootstrap labels numeric operands with these
names in assembly, and independent tests obtain kernel numbers from the
pinned UAPI headers. Future public kernel structure translations should
share named layout definitions and verify offsets against those headers.

## Assertion diagnostics

The C17 assert header evaluates the inclusion-time NDEBUG setting
on every inclusion. A disabled assertion does not evaluate its
argument. An enabled assertion evaluates the scalar expression
once. Failure passes its text and the file, line, and function
to the freestanding assertion ABI. The helper writes to standard
error through the raw fatal diagnostic path and then calls abort.
The static_assert macro expands to the compiler's _Static_assert.
[C17 7.2 draft](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

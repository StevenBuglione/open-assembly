# Phase 1 runtime oracles

These tests were authored against the runtime ABI and external references.
The manifest specifies exact process status, stdout and stderr. A negative
status is a signal observed by the parent. The C programs are freestanding
fixtures. They use declarations and constants from the compiler and Linux
headers and link only against the candidate runtime.

## Independent references

| Oracle ID | Reference |
| --- | --- |
| `abi:sysv-amd64` | AMD64 psABI §3.2 for the call boundary, §3.4 for the initial stack, and Appendix A.2.1 for Linux syscall registers. [AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI) |
| `abi:elf-tls` | Variant II places static TLS below the thread pointer and initializes it from `PT_TLS`. The compiler emits local-exec accesses that must locate the same objects as their C addresses. [ELF TLS specification](https://www.akkadia.org/drepper/tls.pdf), [GCC TLS](https://gcc.gnu.org/onlinedocs/gcc/Thread-Local.html) |
| `c17:errno`, `c17:main-exit`, `c17:atexit`, `c17:immediate-exit` | ISO C17 §7.5 for the per-thread `errno`, §5.1.2.2.3 for return from `main`, §7.22.4.2 for `atexit`, §7.22.4.4 for `exit`, and §7.22.4.5 for `_Exit`. [WG14 C17 draft record](https://open-std.org/jtc1/sc22/wg14/www/wg14_document_log_v2.htm) |
| `gcc:stack-protector` | `-fstack-protector-explicit` instruments functions marked `stack_protect`. A changed guard must call the failure routine on function return. [GCC instrumentation options](https://gcc.gnu.org/onlinedocs/gcc/Instrumentation-Options.html) |
| `linux:exec-auxv`, `linux:fs-base` | The Linux ELF loader supplies `AT_ENTRY`, `AT_PAGESZ` and a 16-byte random payload through `AT_RANDOM`. `ARCH_GET_FS` returns the current thread's FS base. [Linux ELF loader](https://github.com/torvalds/linux/blob/master/fs/binfmt_elf.c), [Linux FS documentation](https://docs.kernel.org/arch/x86/x86_64/fsgs.html) |
| `linux:syscall-abi`, `linux:syscall-errors` | A file-backed `mmap` makes the descriptor and nonzero file offset observable. Linux reserves the inclusive range `[-4095, -1]` for encoded errors. [AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI), [Linux error encoding](https://github.com/torvalds/linux/blob/master/include/linux/err.h) |
| `linux:nonblocking-pipe` | A nonblocking pipe can return `EAGAIN`. A nonblocking write larger than `PIPE_BUF` can return a positive short count. The test uses the live pipe capacity and compares the received bytes. [Linux pipe implementation](https://github.com/torvalds/linux/blob/master/fs/pipe.c) |
| `linux:signal-frame` | The x86-64 kernel `rt_sigaction` takes an eight-byte signal set and installs an `SA_RESTORER` address. The interrupted context resumes when the restorer completes. [x86 signal UAPI](https://github.com/torvalds/linux/blob/master/arch/x86/include/uapi/asm/signal.h), [Linux x86-64 signal return](https://github.com/torvalds/linux/blob/master/arch/x86/kernel/signal_64.c) |
| `linux:wait-status` | Normal exit exposes the low eight bits of the status. Signal death reports the terminating signal separately. [Linux process exit and wait](https://github.com/torvalds/linux/blob/master/kernel/exit.c) |
| `posix:read`, `posix:write`, `posix:close`, `posix:immediate-exit` | [POSIX `read`](https://pubs.opengroup.org/onlinepubs/9799919799/functions/read.html), [POSIX `write`](https://pubs.opengroup.org/onlinepubs/9799919799/functions/write.html), [POSIX `close`](https://pubs.opengroup.org/onlinepubs/9799919799/functions/close.html), [POSIX `_exit`](https://pubs.opengroup.org/onlinepubs/9799919799/functions/_exit.html) |
| `project:runtime-abi` | The fixed thread-block offsets, random guard derivation, `errno` preservation, 32-slot registry, and fatal diagnostics are project-specific requirements. [Runtime ABI](../../docs/adr/0002-runtime-abi.md) |

## Expected observations

| Cases | Observations |
| --- | --- |
| `hello-asm`, `hello-c` | Exact output and successful exit under native execution, QEMU and Valgrind. Assembly checks entry stack alignment and clear DF. GCC emits a real canary comparison and failure reference. |
| `startup`, `startup-empty-env`, `startup-valgrind` | The vectors passed to `main` match the process inputs, include their terminators, and meet at the expected auxv address. The test checks the entry address, page size, FS base and self fields, both `AT_RANDOM` words, stable writable errno, and initialized and zeroed local-exec TLS with 64-byte and 256-byte alignment. The Valgrind run also expects the single `LD_PRELOAD` entry that Memcheck adds. |
| `syscall-args`, `syscall-result` | The six-argument mapping exposes the second file page. The raw path returns `-EBADF` after closing the descriptor and preserves errno. Synthetic raw results exercise the error boundary, successful high and negative words, and errno preservation or positive error translation. |
| `io-read`, `io-write`, `io-close` | The fixtures exercise zero counts, short transfers and their contents, empty/full nonblocking pipes, EOF, closed descriptors, and errno preservation on success. `io-close` independently checks that the descriptor was removed via a raw kernel read. |
| `eintr` | A real timer interrupts a blocked read before transferring a byte. The runtime restorer resumes execution and the wrapper returns `-1` with `EINTR`. The fifth timer tick closes the writer as a bounded escape for a wrapper that wrongly retries. |
| `exit-return`, `exit-explicit` | Returning from `main` and calling `exit` each yield status `0x34` and output `MBDCA`. The running `B` callback registers `C` and then `D`, so both run before the older pending `A` callback. |
| `atexit-capacity` | All 32 slots accept registrations and the 33rd is rejected. A callback reuses the freed slot. The fixture observes 31 duplicate invocations and output `RF`. |
| `immediate-c`, `immediate-posix` | `_Exit(0x171)` yields `0x71` and `_exit(-2)` yields `0xfe`. The registered callback never runs. |
| `panic` | The counted diagnostic includes an embedded zero and excludes the trailing sentinel. Status is 127 and no exit callback runs. |
| `stack-fail`, `stack-fail-masked` | The protected function changes the saved guard's TLS source without an out-of-bounds C access. Both cases emit the fixed diagnostic and die from `SIGABRT`. The latter first ignores and blocks `SIGABRT` to exercise the failure path's reset and unblock behavior. |

The manifest also specifies the exact output and status each generated
public-function stub must produce. A zero-return stub makes `io-read` reject
`read` at status 22, `hello-asm` reject `write` at 42, `io-close` reject
`close` at 42, and `atexit-capacity` reject `atexit` at 23. The startup
fixture rejects a null errno pointer at 31 before dereferencing it. The
nonreturning stubs terminate with status zero. The `exit` stub leaves only
the `M` output. The immediate exit and stack-failure stubs leave no output.

The TLS fixtures exercise the initial thread. TLS isolation across newly
created threads belongs to the threading phase. ELF constructor and
finalizer arrays are deferred by the Phase 1 ABI.

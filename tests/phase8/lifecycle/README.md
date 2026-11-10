# Independent Phase 8 lifecycle checks

The fixtures exercise all six initial pthread APIs through their public
entry points. Four concurrent workers check compiler local-exec TLS,
the initial data image and zero-filled BSS, 64-byte and 256-byte
alignment, distinct errno cells, SysV stack alignment and direction
flag, copied guard words, and inherited signal masks and rounding
modes. The initial thread and each worker modify their own state.

Separate cases transport both returned and explicit `pthread_exit`
pointers. A surviving worker joins the initial thread and observes
process exit handlers after the last thread leaves. A self-join checks
the project EDEADLK result and an untouched result pointer. Pinned
glibc corroborates that case. The pinned musl process waited on its
own handle, so the shared hosted matrix uses the other cases.

The mapping fixture observes the ABI's separate TLS and stack ranges,
then checks kernel unmapping after live and already-exited detach.
It never uses the detached handle after the detach call. Its guard
probe verifies EFAULT for a kernel read from the guard page and success
for the adjacent writable page. The intentional EFAULT produces a
Memcheck syscall-buffer diagnostic, so this case runs on native and
QEMU. Memcheck still runs the detach and join reclamation fixtures.

An armed syscall wrapper fails the first or second worker mmap, or the
protection change within the worker stack. The fixture checks EAGAIN,
unchanged handle and errno, and reclamation of every mapping observed
before the fault. A successful create and join follow after disarming.
A separate mode targets the joining thread's shared clear-TID futex.
It injects EINTR and EAGAIN before allowing the worker to complete
and requires the real wait path to transport the result.

The contention fixture checks preserved allocation contents through
realloc and verifies that the shared stream receives every distinct
record exactly once. Typed zero-return controls reject each public
entry. The noreturn pthread_exit control exits the process immediately,
which the survivor case detects by its missing result marker.

[Lifecycle contract](../../../docs/adr/0010-thread-lifecycle-locks.md) ·
[AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI) ·
[Linux clone](https://man7.org/linux/man-pages/man2/clone.2.html) ·
[Linux clear TID](https://man7.org/linux/man-pages/man2/set_tid_address.2.html) ·
[Linux futex](https://man7.org/linux/man-pages/man2/futex.2.html)

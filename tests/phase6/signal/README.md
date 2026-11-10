# Independent Phase 6 signal fixtures

The fixtures use the published x86-64 signal layouts and compare visible
state with raw Linux operations. The signal cases run in separate processes.
They check preserved errno, mask words and surrounding sentinels, real
delivery, handler arguments and masks, synchronous raise, pending-signal
consumption, and restoration after sigsuspend. The BSD signal case checks
the kernel's restart flag and persistent disposition.

The mask tests cover the full project signal range, including 32–34 and 64.
Hosted comparisons omit reserved realtime bits and project-only padding.
Pinned musl returns zero and preserves errno for invalid sigismember values.
The project and glibc cases require -1 and EINVAL, with the shared hosted
case retaining the valid membership checks.

The ordinary sigprocmask and sigaction cases run on all three backends.
Memcheck emits a process-specific diagnostic for deliberately invalid how
values, so that separate case runs on native and QEMU. Memcheck's simulated
SA_SIGINFO delivery leaves the added SIGUSR2 unblocked inside the handler
despite the action round trip. The separate extra-mask check runs on
native and QEMU, and the ordinary Memcheck case still verifies delivery,
sender identity, context presence, and SA_NODEFER behavior.

Each of the twelve public API symbols has an attributable generated zero
stub rejection. Hosted comparisons use the same C fixture and raw kernel
observations over the shared domain.

[Phase 6 signal contract](../../../docs/adr/0007-linux-files-process-signal-time.md) ·
[Linux sigaction](https://man7.org/linux/man-pages/man2/sigaction.2.html) ·
[Linux sigprocmask](https://man7.org/linux/man-pages/man2/sigprocmask.2.html)

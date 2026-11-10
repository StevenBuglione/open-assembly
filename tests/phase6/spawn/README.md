# Independent Phase 6 spawn fixtures

The self-spawn case supplies explicit argv and envp, copies and then
changes an open-action pathname, and exercises open, dup2 and close
actions in registration order. It checks same-descriptor close-on-exec
clearing, descriptor movement near the initial low-numbered descriptors,
the child process group, reset IDs, signal defaults and mask, and the
parent's unchanged mask. Missing executable and child file-action
failures preserve the PID slot and leave no child to reap.

The attribute and action cases check initialized defaults, updated
values, copied masks, canaries, invalid descriptors, and the project's
invalid flag and process-group behavior. Hosted glibc and musl return
the error number through the function and may also set errno. Pinned
glibc leaves EBADF after the successful descriptor-action case.
The candidate preserves its caller's errno in every case.

The teardown fixture wraps the public malloc, calloc, realloc and free
boundaries during setup and destroy. It tracks successful top-level
allocation identities, treats successful reallocation as a replacement,
and requires that every recorded allocation be released. The optional
`report` argument prints the observed counts for each candidate binary.
The frozen attribute case observed one allocation and one release. The
frozen action case with two open actions and one close observed three
allocations and three releases. The oracle checks balance and identities.

All sixteen public symbols have separate generated stub rejections.
The manifest binds the teardown probes to the exact allocator wrappers.
QEMU and Memcheck can transfer the child to native execution after exec.

[Phase 6 spawn contract](../../../docs/adr/0007-linux-files-process-signal-time.md) ·
[POSIX posix_spawn](https://pubs.opengroup.org/onlinepubs/9799919799/functions/posix_spawn.html)

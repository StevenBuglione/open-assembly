# Independent Phase 6 shell process fixtures

The shell cases run the pinned /bin/sh with explicit commands. They
check availability, ordinary and signaled wait statuses, restoration of
the parent signal mask and dispositions, binary read streams and buffered
write streams, close-on-exec, and closure of prior popen descriptors in
the next child. The project-only pclose case verifies an unrelated stream
stays usable after EINVAL.

Hosted comparisons cover the shared shell and stream behavior. Pinned
glibc can leave ENOSYS after its successful system availability check.
Pinned musl accepts the noncanonical popen mode rw. The corresponding
project assertions retain unchanged errno and rejection of that mode.

The scoped syscall wrapper injects one fork error at a time and verifies
signal restoration or descriptor cleanup. A separate probe injects one
EINTR into a real pclose wait and observes a retry. At the system wait
boundary it queries the actual parent dispositions and mask, checking
ignored SIGINT and SIGQUIT and blocked SIGCHLD. Ordinary cases link
without the wrapper. All three public entries have generated stub
rejections.

[POSIX system](https://pubs.opengroup.org/onlinepubs/9799919799/functions/system.html) ·
[POSIX popen](https://pubs.opengroup.org/onlinepubs/9799919799/functions/popen.html) ·
[POSIX pclose](https://pubs.opengroup.org/onlinepubs/9799919799/functions/pclose.html)

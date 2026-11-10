# Linux socket and readiness ABI

This first network slice covers socket and socketpair, bind,
connect, listen, accept and accept4, local and peer address
queries, shutdown, socket options and the scalar, addressed
and message send and receive calls. It provides poll and ppoll,
epoll_create and epoll_create1, epoll_ctl, epoll_wait and
epoll_pwait. Four byte-order helpers convert 16- and 32-bit
values between the host and network encodings.

Calls enter the existing private x86-64 syscall boundary and
translate errors through thread-local errno. Success preserves
errno. Short transfers, EOF, EINTR, nonblocking errors, flags
and SIGPIPE follow Linux behavior. Callers can use MSG_NOSIGNAL
to suppress SIGPIPE for one send. Accept4 applies CLOEXEC and
NONBLOCK atomically. The supplied socket address length and
message buffers follow kernel update rules. These wrappers
establish kernel behavior for the project before cancellation
support is integrated. [Linux x86-64 syscall table](https://github.com/torvalds/linux/blob/master/arch/x86/entry/syscalls/syscall_64.tbl).

The socket ABI uses a 32-bit unsigned socklen_t and a 16-bit
unsigned sa_family_t. The generic sockaddr is 16 bytes.
Sockaddr_storage is 128 bytes aligned to eight. IPv4 and IPv6
records occupy 16 and 28 bytes, and the Unix address has a
108-byte path after its family. The native LP64 message header
is 56 bytes, the control message header is 16 bytes and each
iovec is 16 bytes. Ancillary record alignment is eight bytes.
IPv4 and IPv6 ports and addresses use network byte order.

The pollfd record occupies eight bytes. A negative descriptor
is ignored by the kernel, and an invalid nonnegative descriptor
sets POLLNVAL. The public nfds_t is an unsigned long. A count
outside the kernel's unsigned 32-bit argument range fails
with EINVAL before the syscall. Ppoll copies a nonnull
timeout so the caller's const object stays intact. Ppoll and
epoll_pwait pass the eight-byte Linux kernel signal mask and
leave the public mask object intact.

The x86-64 epoll_event record is packed. It contains a 32-bit
event mask and an eight-byte payload at offset four, for a
12-byte stride. Epoll preserves the entire user payload.
[Linux eventpoll UAPI](https://raw.githubusercontent.com/torvalds/linux/master/include/uapi/linux/eventpoll.h).

Resolver policy, the higher-level network application, and the
SQLite acceptance gate follow this kernel wrapper slice.

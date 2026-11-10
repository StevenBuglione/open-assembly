# Socket and readiness endpoint verification

Run `./tools/container make phase10-endpoints`. The 25 direct API stub
controls exercise error translation or an independently specified poll
result. The shared ABI trampoline tests the target symbols with poisoned
upper argument bits on native Linux and QEMU. A no-op calibration for that
trampoline reports FP control differences in pinned Memcheck. All endpoint
semantics also run under Memcheck.

The functional cases check loopback TCP connect, accept and accept4 flags,
short address lengths, UDP truncation and zero-byte datagrams, Unix
socketpair nonblocking state, half-close, short transfers and SIGPIPE.
The ancillary test passes a real pipe descriptor across a datagram socket
and checks its close-on-exec state. The project macro fixture checks
malformed and truncated ancillary records. Poll and epoll checks cover
negative or invalid descriptors, wide counts, packed output tags, input
and output sentinels and temporary signal masks restored after EINTR.

The pinned container returns EPERM for an out-of-range socket domain, while
socketpair reports EAFNOSUPPORT. The direct socket stub controls instead
use an invalid type on AF_UNIX, which produces EINVAL for both APIs on
this kernel. The common hosted cases run against pinned glibc and musl.

[Linux socket and readiness ABI](../../../docs/adr/0013-linux-sockets-readiness.md)

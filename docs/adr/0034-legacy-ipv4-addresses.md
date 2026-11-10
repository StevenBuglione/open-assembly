# Legacy IPv4 addresses

Inet_addr accepts one to four unsigned parts. The first parts
occupy one byte each and the last part occupies the remaining
bytes. A leading zero selects octal and 0x or 0X selects
hexadecimal. Other parts use decimal. A part needs at least one
digit and the entire spelling must be an address. An invalid
address returns INADDR_NONE, which is also the bit pattern for
255.255.255.255. The function preserves errno. Pinned musl
also requires the complete spelling. Pinned glibc accepts
trailing ASCII whitespace and ignores text after that whitespace.

Inet_ntoa emits four decimal octets using the same IPv4 writer
as inet_ntop. The calling thread's descriptor contains a
16-byte text buffer at 0xe0 and four scratch bytes at 0xf0.
The text remains valid until the next inet_ntoa call on that
thread or until the thread terminates. Inet_ntoa preserves errno.

Netinet/in.h also declares htonl, htons, ntohl, and ntohs.
PF_INET aliases AF_INET. SO_RCVTIMEO uses x86-64 Linux socket
option number 20 and the existing LP64 timeval layout.

[POSIX IPv4 address manipulation](https://pubs.opengroup.org/onlinepubs/9799919799/functions/inet_addr.html).
[Linux socket UAPI](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/tree/include/uapi/asm-generic/socket.h?h=v6.6).

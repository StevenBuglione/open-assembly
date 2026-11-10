# Configured resolver address families

When `getaddrinfo` receives AI_ADDRCONFIG, take an address
snapshot of the caller's current Linux network namespace.
IPv4 requires a configured non-loopback IPv4 address and IPv6
requires a configured non-loopback IPv6 address. IPv4 addresses
in 127/8, IPv6 ::1 and unspecified addresses do not count.
Tentative and duplicate-detection-failed addresses do not count.
The snapshot is per call. [RFC 3493, getaddrinfo](https://www.rfc-editor.org/rfc/rfc3493.html#section-6.1).

Apply the snapshot to numeric, local-file, synthetic and DNS
results. Do not issue DNS queries for an unavailable family.
A requested AF_INET6 result with AI_V4MAPPED can use a configured
IPv4 source family. Mapping happens after source-family
selection. AI_ALL combines native IPv6 and mapped IPv4 when
both source families are configured. An empty selection returns
EAI_NONAME. A failed or inconsistent kernel snapshot returns
EAI_AGAIN. Allocation failure returns EAI_MEMORY. The public
function preserves errno.

Use an unprivileged, nonblocking NETLINK_ROUTE RTM_GETADDR dump,
with a two-second monotonic deadline for the complete operation.
Read messages only from the kernel unicast endpoint and require
sequence number one on the fresh socket. Check the netlink
lengths, four-byte alignment, dump status and interruption flag
before using results. For each address, IFA_LOCAL takes
precedence over IFA_ADDRESS and IFA_FLAGS takes precedence over
the fixed header's flags byte. [Linux address UAPI](https://github.com/torvalds/linux/blob/master/include/uapi/linux/if_addr.h) ·
[Linux netlink UAPI](https://github.com/torvalds/linux/blob/master/include/uapi/linux/netlink.h).

The private decoder has the following test ABI.

```c
int __al_gai_addrconfig_parse(const unsigned char *bytes, size_t length,
                              unsigned int *mask);
```

It accepts one datagram of up to 32768 bytes and an initial
mask in the low two bits. Bit zero indicates IPv4 and bit one
IPv6. A valid data datagram ORs its families into the mask and
returns zero. A complete dump terminator returns one. Invalid,
truncated and interrupted messages return a negative result
and leave the mask unchanged. The decoder preserves errno
and performs no I/O. The private `int __al_gai_addrconfig(void)`
performs the complete snapshot and returns mask 0 through 3
or a negative EAI status. No DNS request is part of this probe.

In the pinned loopback-only namespace, the project returns EAI_NONAME
for numeric loopback under AI_ADDRCONFIG. The pinned glibc and musl
controls both returned ordinary numeric IPv4 and IPv6 loopback
results in that namespace. The mapped IPv4 control returned EAI_NONAME
from glibc and an IPv6 result from musl.

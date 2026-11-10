# IPv6 scope identifiers

A numeric IPv6 node accepted by `getaddrinfo` can include a
single percent delimiter and a nonempty scope identifier.
The address before the delimiter must be valid IPv6 text.
An all-decimal suffix represents an unsigned 32-bit scope ID,
including zero. Leading zeroes are accepted and overflow
returns EAI_NONAME. Decimal IDs apply to any numeric IPv6
address for Linux compatibility.

A nondecimal suffix can name a Linux interface for link-local
unicast and interface-local or link-local multicast addresses.
The resolver looks up the name in the caller's network namespace
using SIOCGIFINDEX. Names occupy one through 15 visible ASCII
bytes and exclude colon, slash, percent, and the names `.` and
`..`. Unknown names return EAI_NONAME. Other kernel failures
during forward lookup return EAI_AGAIN. IPv4 suffixes and
malformed scoped inputs return EAI_NONAME without DNS. A valid
scope ID becomes the returned sockaddr's `sin6_scope_id`.
AI_CANONNAME retains the caller's numeric spelling.

For numeric `getnameinfo` output, a nonzero scope ID is appended
after a percent. Link-local unicast and link-local multicast
prefer a usable interface name from SIOCGIFNAME. Other scopes
and failed name lookups use unsigned decimal. A zero scope has
no suffix. The public functions preserve errno and the existing
output publication rules. `inet_pton` and `inet_ntop` continue
to operate on the address bytes alone.

The pinned glibc and musl controls share this policy for link-local
unicast and link-local multicast. The pinned glibc control also
accepts interface-local multicast names on input, while the pinned
musl control rejects them. Interface-local multicast output uses
the decimal spelling.

[Scoped IPv6 addresses](https://www.rfc-editor.org/rfc/rfc4007.html#section-11) ·
[Entering IPv6 zone identifiers](https://www.rfc-editor.org/rfc/rfc9844.html) ·
[Linux socket ioctl numbers](https://github.com/torvalds/linux/blob/master/include/uapi/linux/sockios.h).

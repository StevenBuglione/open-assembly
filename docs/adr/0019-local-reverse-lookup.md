# Local and numeric socket-address lookup

Getnameinfo accepts IPv4 and IPv6 socket address records.
A nonnull output with a nonzero length requests its host or
service string. At least one output is required. Both buffers
are checked before either is written. An undersized buffer
returns EAI_OVERFLOW and leaves both outputs unchanged.
A short address record or unsupported family returns EAI_FAMILY.
Unknown flags return EAI_BADFLAGS. The function preserves errno.

Host lookup recognizes the IPv4 and IPv6 loopback addresses
as `localhost` and looks up other addresses in `/etc/hosts`.
The first matching canonical hostname is used. NI_NOFQDN
returns the part before the first dot in a local name.
NI_NUMERICHOST requests numeric output and bypasses name lookup.
Otherwise a missing name falls back to numeric output unless
NI_NAMEREQD requests EAI_NONAME. A numeric IPv6 scope ID is
appended after `%` when nonzero. DNS PTR queries and interface
names for scope IDs are separate capabilities.

Service lookup searches `/etc/services` for the first name
matching the numeric port and transport. TCP is the default.
NI_DGRAM selects UDP. An unknown service falls back to decimal
port text. NI_NUMERICSERV requests decimal text directly.

[Socket-address name lookup](https://www.rfc-editor.org/rfc/rfc3493.html#section-6.2).

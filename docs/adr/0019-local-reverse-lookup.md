# Socket-address name lookup

Getnameinfo accepts IPv4 and IPv6 socket address records.
A nonnull output with a nonzero length requests its host or
service string. At least one output is required. Both buffers
are checked before either is written. An undersized buffer
returns EAI_OVERFLOW and leaves both outputs unchanged.
A short address record or unsupported family returns EAI_FAMILY.
Unknown flags return EAI_BADFLAGS. The function preserves errno.

Host lookup recognizes the IPv4 and IPv6 loopback addresses
as `localhost` and looks up other addresses in `/etc/hosts`.
IPv4-mapped and IPv4-compatible IPv6 addresses use the embedded
IPv4 address for names. The IPv6 unspecified address skips name
lookup. The first matching canonical local hostname is used. NI_NOFQDN
returns the part before the first dot in a local name.
NI_NUMERICHOST requests numeric output and bypasses name lookup.
After local names, the resolver requests an IN PTR record using
in-addr.arpa for IPv4 or ip6.arpa for IPv6. The selected name is
returned in lowercase with no final root dot. An unusable or
missing name falls back to numeric output. With NI_NAMEREQD,
lookup failure returns its EAI status and preserves both output
buffers. Numeric output keeps the supplied address family and
appends a nonzero IPv6 scope ID after `%`. Interface names for
scope IDs remain a separate capability.

Service lookup searches `/etc/services` for the first name
matching the numeric port and transport. TCP is the default.
NI_DGRAM selects UDP. An unknown service falls back to decimal
port text. NI_NUMERICSERV requests decimal text directly.

[Socket-address name lookup](https://www.rfc-editor.org/rfc/rfc3493.html#section-6.2).

[IPv6 reverse lookup](https://www.rfc-editor.org/rfc/rfc3596.html#section-2.5).

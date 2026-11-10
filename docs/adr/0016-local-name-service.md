# Local node and service lookup

The initial netdb slice supplies getaddrinfo, freeaddrinfo and
gai_strerror for IPv4 and IPv6 using numeric inputs and local
name databases. A subsequent slice adds reverse lookup and DNS.
[Protocol-independent address lookup](https://www.rfc-editor.org/rfc/rfc3493.html#section-6.1).

Getaddrinfo accepts AF_UNSPEC, AF_INET and AF_INET6 and resolves
TCP and UDP socket types. A null service selects port zero. A
numeric service has one or more decimal digits with value at
most 65535. A named service is matched case-sensitively against
its name or aliases in `/etc/services`, separately for TCP and
UDP. Numeric-only flags bypass their respective name databases.

A null node selects both supported families or the requested
family, with unspecified addresses for AI_PASSIVE and loopback
otherwise. IPv6 precedes IPv4 for these synthetic results.
`localhost`, with optional case variation and trailing dot,
selects loopback independently of AI_PASSIVE. Other local names
are matched case-insensitively, with a trailing dot ignored,
against names and aliases in `/etc/hosts` in file order. This
slice reads a maximum of 32 matching address records and skips
physical lines longer than 4095 bytes. Missing files or absent
matches yield the corresponding EAI error. AI_ADDRCONFIG applies
the [configured family snapshot](0038-address-configuration.md).
IPv6 zone identifiers remain separate.

AI_V4MAPPED applies when AF_INET6 is requested. It makes
matching IPv4 addresses available as mapped IPv6 addresses if
there are no IPv6 matches, or alongside them with AI_ALL.
AI_ALL alone has no effect. With AI_CANONNAME, the first record
owns a copy of the numeric input text, the synthetic name
`localhost`, or the canonical name from the first matching
local-file record. TCP precedes UDP within each address when
both transports are requested and available.

Each result owns its address and optional canonical name. It
can be freed with any suffix or detached sublist. Publication
occurs after all result allocations succeed. On failure the
result is null. Getaddrinfo, freeaddrinfo and gai_strerror
preserve errno. Gai_strerror returns an immutable static string
for each supported EAI code and for unknown values.

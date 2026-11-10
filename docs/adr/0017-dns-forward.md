# Bounded DNS

The resolver tries a numeric address, synthetic localhost and
local hosts data before DNS. AI_NUMERICHOST bypasses DNS.
Forward queries use class IN and type A or AAAA. Host text
accepts ASCII letters, digits, hyphens and underscores in labels
from one through 63 bytes, separated by dots. A final root dot
is permitted. A single `.` represents the root. Names must fit
the 255-byte wire limit. See the [resolver search policy](0039-resolver-search.md)
for suffix and ndots processing. IDNA, address sorting and DNSSEC
validation remain separate resolver capabilities.

The private DNS wire interfaces support direct bounded tests.
`__al_dns_build(name, qtype, id, output, capacity)` returns the
query byte count, or zero without writing the output. A query
requests recursion and contains one lowercase question. Types
are 1 for A, 12 for PTR and 28 for AAAA. The ID is a 16-bit value.

`__al_dns_parse(response, response_size, query, query_size,
answer)` consumes the original query from the builder and a
response of at most 65535 bytes. An answer buffer occupies 1032
bytes. A successful result has a 32-bit address count at offset
0 and the host-order query type at offset 4. The canonical owner
at offset 8 is lowercase DNS wire text, including its root
terminator. Up to 16 distinct addresses begin at offset 264,
with a 16-byte stride. IPv4 addresses occupy the first four
bytes and have zero padding. PTR returns count one and puts its
first target in the same 256-byte region as a lowercase wire
name with a root terminator. The remaining bytes are scratch.

The parser returns zero for an address or PTR result. It returns one
for matching truncated responses and two for responses with an
unrelated transaction or question. Negative results are EAI
codes. It validates the echoed question, answer lengths and
bounded backwards compression pointers. It follows up to eight
CNAME links within the answer section, accepting only records
whose owner matches the selected name. NXDOMAIN and no matching
answer return EAI_NONAME. SERVFAIL returns EAI_AGAIN. Malformed
matching messages and other response codes return EAI_FAIL.
The answer count is zero on every failure. The wire helpers
perform no allocation or I/O and preserve errno.

[DNS wire protocol](https://www.rfc-editor.org/rfc/rfc1035.html).

The transport selects the first valid IPv4 or IPv6 nameserver
in `/etc/resolv.conf`, with a loopback IPv4 default if none is
present. It queries port 53 and uses a new connected socket
and a random 16-bit transaction ID for each family. The socket
filters response peers, and the parser rejects unmatched IDs
and questions. AF_UNSPEC tries AAAA then A. An AF_INET6 request
with AI_V4MAPPED falls back to A if AAAA finds no address, or
also tries A when AI_ALL is set.

The private `__al_dns_query(server, server_length, name,
qtype, answer)` takes a numeric sockaddr and uses its supplied
port. Its return is zero or a negative EAI code. It preserves
errno. A connected UDP query and a truncation-triggered TCP
retry each have an absolute two-second monotonic deadline.
The TCP reply uses two-byte DNS framing and handles short
reads or writes. A transport error or timeout yields EAI_AGAIN.
[DNS over TCP](https://www.rfc-editor.org/rfc/rfc7766.html).
[DNS response matching](https://www.rfc-editor.org/rfc/rfc5452.html#section-9.1).

Forward lookup accepts AI_PASSIVE, AI_CANONNAME, AI_NUMERICHOST,
AI_NUMERICSERV, AI_V4MAPPED, AI_ALL and AI_ADDRCONFIG. AI_ALL applies
only with AI_V4MAPPED for AF_INET6. AI_ADDRCONFIG uses the Linux
[address configuration snapshot](0038-address-configuration.md).
The configuration parser uses one nameserver and applies search,
domain and ndots directives to forward lookup. Attempts, rotation
and timeout overrides remain separate.
Numeric IPv6 zone suffixes and interface names remain separate.

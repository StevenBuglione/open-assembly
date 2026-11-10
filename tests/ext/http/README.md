# Independent HTTP verification

The public package applies the bounded loopback request grammar from
[ADR 0014](../../../docs/adr/0014-loopback-http.md). The token
predicate uses [RFC 9110 Section 5.6.2](https://www.rfc-editor.org/rfc/rfc9110.html#section-5.6.2).
The unit case checks all 256 bytes against the ASCII token set.
The SysV case also checks exact unsigned returns with two different
patterns in the unspecified upper argument bits. The shared ABI
state probe runs natively and under QEMU because its nondefault
x87 control value exceeds Memcheck emulation.

The terminator and parser cases cover incomplete spans, the first
of repeated terminators, an exact 8192-byte request and a terminator
beyond the parser cap. The guard case puts the entire valid request
in read-only pages next to inaccessible pages. The byte sweeps
check each of 256 octets in the method, target, header name, header
value, Host name, port, Content-Length and version contexts. The
parser model reuses the existing independent loopback grammar
without changing its source or observations.

Fixed 64-byte inputs select template heads, raw data, octet changes,
truncations, suffixes and near-capacity heads. Each 16-byte result
contains the exact returned value and preserved errno. Guard and
semantic cases run natively, under QEMU and under Memcheck.

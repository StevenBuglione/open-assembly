# Numeric Internet address codecs

`inet_pton` and `inet_ntop` support AF_INET and AF_INET6. The
binary representation consists of four or sixteen network-order
bytes. Invalid text returns zero from inet_pton, preserving
errno and the destination. An unsupported family returns minus
one from inet_pton and null from inet_ntop, with EAFNOSUPPORT.
Inet_ntop returns null with ENOSPC if the complete result and
terminating null do not fit. It preserves the destination on
both failures. Successful conversions preserve errno.

IPv4 input uses four decimal components from 0 to 255. A
multi-digit component begins with a nonzero digit. IPv6 input
supports eight one-to-four-digit hexadecimal words, a single
`::` that stands for one or more zero words, and the standard
optional four-octet dotted-decimal suffix. A zone identifier
or surrounding whitespace is invalid. [IPv6 address text](https://www.rfc-editor.org/rfc/rfc4291.html#section-2.2).
[IPv4 decimal grammar](https://www.rfc-editor.org/rfc/rfc3986.html#section-3.2.2).

Output uses minimal decimal IPv4 components and lowercase
hexadecimal IPv6 words. IPv6 compresses the longest run of two
or more zero words, with the first run winning ties. IPv4-mapped
addresses use `::ffff:` followed by dotted decimal. Other IPv6
addresses use hexadecimal throughout. [IPv6 canonical text](https://www.rfc-editor.org/rfc/rfc5952.html#section-4).

The caller supplies a readable input and writable destination
with the specified size. The codecs do not read configuration
files, use network sockets or allocate memory. Name and service
lookup policy follows in a separate resolver slice.

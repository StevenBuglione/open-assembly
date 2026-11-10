# Numeric address and byte-order verification

Run `./tools/container make phase10-inet`. Each 16-bit byte-order
operation covers all 65,536 input patterns. Each 32-bit operation
uses 8,192 seeded samples. The IPv4 and IPv6 codecs run directed
grammar cases and 4,096 independent reference samples per operation,
split evenly between low and high guard edges. The fixture checks
end delimiters, exact output capacity and successful errno preservation.

The shared glibc and musl comparisons require matching successful
bytes and malformed-input status. Pinned musl partially writes the
destination for malformed IPv4 text such as `1.2.3`. The candidate
must preserve the entire destination. The project's hexadecimal
rendering of nonmapped IPv4-compatible addresses has a separate
directed check. IPv4-mapped addresses retain the dotted-decimal suffix.

[IPv6 address syntax](https://www.rfc-editor.org/rfc/rfc4291.html#section-2.2) ·
[Canonical IPv6 output](https://www.rfc-editor.org/rfc/rfc5952.html#section-4)

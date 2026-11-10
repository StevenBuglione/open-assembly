# Independent DNS wire and loopback checks

Run `./tools/container make phase10-dns`. The gate records input and artifact
hashes, checks reproducibility in two isolated runtime builds, and runs the
same candidate binaries under Linux, QEMU user mode and strict Memcheck.

The wire oracle encodes messages with Python `struct` using the DNS header,
question, label, compression and record formats. It treats `.` as an
explicit root name and tests the empty string separately. It compares ASCII
labels without regard to case and requires the documented lowercase expanded
answer name. Guard pages and canaries check both ends of each packet buffer,
read-only inputs, and writes outside the published answer extent. Directed
cases cover malformed compression, RCODEs, IDs, duplicate addresses, CNAME
links and truncation. A fixed seed supplies 2,048 additional packets.

A Python peer binds IPv4 loopback on an ephemeral port and checks the actual
UDP and TCP exchanges. It sends responses with unrelated addresses or IDs,
fragments the TCP length and response body, and measures the deadline against
silence and unrelated replies. These are direct tests of the private DNS ABI.
The scope excludes machine resolver configuration and external DNS services.
Three independent linker controls replace each private entry with its typed
zero-return stub and verify the exact observable rejection.

[RFC 1034, DNS concepts and names](https://www.rfc-editor.org/rfc/rfc1034.html#section-3.1)
[RFC 1035, DNS wire formats](https://www.rfc-editor.org/rfc/rfc1035.html#section-4.1)
[RFC 5452, response matching](https://www.rfc-editor.org/rfc/rfc5452.html#section-9.1)
[RFC 7766, DNS over TCP](https://www.rfc-editor.org/rfc/rfc7766.html)


The same gate verifies PTR wire records at both guard edges and runs
public `getnameinfo` against an independent loopback peer. Reverse
question names come from the IPv4 and IPv6 reverse namespace rules.
The peer controls case, compression, unrelated transactions, truncation
with TCP retry, and explicit NXDOMAIN, SERVFAIL and malformed replies.
A fixture hosts file and nameserver hook make local priority, numeric
bypass and required-name failure deterministic. The numeric stub case
needs neither hook and checks that the zero-return control failed to
write output.

[IPv4 reverse DNS](https://www.rfc-editor.org/rfc/rfc1035.html#section-3.5) ·
[IPv6 reverse DNS](https://www.rfc-editor.org/rfc/rfc3596.html#section-2.5) ·
[Public name lookup](https://www.rfc-editor.org/rfc/rfc3493.html#section-6.2)

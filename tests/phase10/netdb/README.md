# Independent local and numeric name service checks

Run `./tools/container make phase10-netdb`. The suite checks numeric parsing,
IPv4-mapped addresses, service port boundaries, result ordering and ownership,
numeric reverse lookup, buffer capacity, and unchanged errno. It compares the
portable subset with pinned glibc and musl without comparing human-readable
error wording. Project-specific semantics are labeled in the manifest.

Each local-file case writes its own readable hosts and services inputs in an
isolated working directory. An armed test-only `fopen` wrapper redirects only
the two documented database paths. The cases exercise aliases, case and final
dot handling, named TCP and UDP ports, the 32-address bound, and the exclusion
of an overlong physical line. Numeric reverse lookup must bypass both files.
Another fixture tracks ownership of real allocations and fails each allocation
in a numeric lookup in turn. It checks complete cleanup and null result
publication on failure and can free detached sublists independently.

The runtime and fixture links are reproduced independently. Native, QEMU and
strict Memcheck run each semantic case, and four generated linker controls
replace the public entry points individually. The DNS wire and real loopback
transport use the separate `phase10-dns` target.

[RFC 3493, protocol-independent address lookup](https://www.rfc-editor.org/rfc/rfc3493.html#section-6)

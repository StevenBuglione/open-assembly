# Local calendar and TZif fixtures

The fixture checks project `localtime_r` and `mktime` against calendar fields
derived from UTC civil arithmetic and independently specified offsets. It uses
fixed timestamps and launches each case with an explicit environment. The
candidate must preserve `errno` on success. The host binaries compare return
values and civil fields on cases with a common contract. On overflow the
candidate must set `EOVERFLOW` and preserve the caller's complete record.

The manifest embeds complete Appendix B byte sequences. The fixture checks v1
leap metadata with POSIX leap-free time, a v2 transition before the signed
32-bit range, a truncated v2 zone, a v3 footer with a 26-hour transition
time, and a truncated v4 zone with an expiration record and future DST.
Malformed copies independently corrupt the signature, version, second header
length, count, transition order, type index, abbreviation index and DST
flag. The fallback cases also cover an absent file, a directory, and a file
one byte larger than the accepted 1 MiB. [RFC 9636 Appendix B](https://www.rfc-editor.org/rfc/rfc9636.html#appendix-B)

| Fixture | Bytes | SHA-256 |
| --- | ---: | --- |
| `b1.tzif` | 272 | `975254bc5475b335074a0581f9b3b10ac2f10b28044795873b768f97b57831bc` |
| `b2.tzif` | 329 | `7f03d1bf5264e7ab023a2ef9b997ddfc8cb6936692407c770762b9c549523f33` |
| `b3.tzif` | 235 | `ae6aea2663b3ebe65aa7708d418affee1cd34e3896019f09e10c11fd7e3464ec` |
| `b4.tzif` | 152 | `cfb2b78ba9b5cdb88baa25abdcf389cd4448c9dc679c721bef4c354487b22381` |
| `b5.tzif` | 174 | `0ba7ecff9f80bdabd3aa0a07216a08bcccff5bbe0e4efc97cb6c145967b26ff0` |
| `new-york.tzif` | 3,552 | `e9ed07d7bee0c76a9d442d091ef1f01668fee7c4f26014c0a868b19fe6c18a95` |

The New York file comes from the Nix `tzdata-2026e` output and is passed by
absolute path. This makes the historical and 2040 checks independent of the
installed zone database. The explicit POSIX rules cover the leap-day
difference between Julian `Jn` and zero-based day `n`, and the repeated
and skipped civil times on the 2024 US transition dates.
[IANA time zone archive](https://data.iana.org/time-zones/releases/tzdata2026e.tar.gz)

Pinned glibc recognizes the RFC leap seconds, calls the empty-TZ zone
`Universal`, and keeps the original TZ state across a subsequent
`setenv` followed by `localtime_r`. Pinned musl omits certain truncated
zone designations and uses a different pre-coverage result for the v3 and
v4 files. The manifest reports these cases separately from the shared
host checks. The project explicitly specifies an earlier fold, forward gap,
and unchanged output on overflow. The two stub cases fail when their
directly called conversion is replaced with a zero-return function.

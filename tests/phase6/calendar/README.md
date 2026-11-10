# Independent UTC calendar fixtures

The civil vectors derive Gregorian dates from leap rules and the Unix
epoch. The generator cross-checks years in Python's date range against
`datetime.date`. Directed values cover pre-epoch boundaries, leap and
non-leap centuries, negative civil years, both sides of signed 32-bit
timestamps, and the exact limits of the public tm_year field. The
candidate checks UTC abbreviation, zero offset, static gmtime reuse,
independent gmtime_r storage and unchanged output after overflow.

Hosted checks use an explicit UTC0 zone and accept the UTC or GMT
abbreviation. Pinned glibc can leave ENOENT during initial timezone
lookup despite a successful UTC conversion, so that result is accepted
in its hosted case only. Pinned musl returns -1 for the positive full
65-bit difference between the time64 extrema. The two full-span rows
remain required for the project and glibc.

The difftime fixture uses exact binary64 encodings for adjacent
timestamps, full-width signed differences, and halfway values at 2^53.
The directed case selects each SSE rounding mode and checks that the
current x87 and SSE controls survive. The generated difftime control
returns zero in XMM0. Each public entry has a generated stub rejection.

[Phase 6 UTC calendar contract](../../../docs/adr/0007-linux-files-process-signal-time.md) ·
[POSIX gmtime and gmtime_r](https://pubs.opengroup.org/onlinepubs/9799919799/functions/gmtime.html)

# Independent C-locale time formatting

Directed cases check C17 directives and the permitted E/O fallback
forms with an explicit C locale. The fixture also checks midnight,
noon, leap-second spelling, empty output, exact-fit and one-short
capacity, and preserved errno.

The cycle fixture checks all 146,097 dates from 2000-01-01 through
2399-12-31. Its oracle advances an independently anchored Gregorian
weekday, chooses the ISO week-year by the week's Thursday, and builds
the expected digits itself. The observed output includes both
conventional week numbers, the ISO week and year, and the date and
ordinal fields. This covers one full Gregorian cycle.

Separate project cases check signed extended years, unsupported
formats, supplied zone metadata and offset bounds. Hosted coverage
includes numeric offsets. The pinned musl scope excludes the custom
abbreviation case. The guard fixture places the output and a zone
string beside inaccessible pages and checks a size-zero call pointing
at a protected destination. Its native, QEMU and Memcheck runs all
use the project archive.

The typed zero-return control rejects the named function through
the first exact nonempty directive row.

[C17 time formatting](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

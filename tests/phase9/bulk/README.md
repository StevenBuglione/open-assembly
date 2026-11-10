# Independent multibyte string conversions

The fixtures check all seven public v2 additions through the pinned
`make phase9-bulk` gate. A fixed Unicode sequence has known one-, three-
and four-byte UTF-8 encodings and a trailing ASCII character. Directed
capacity changes verify exact counts, the first unconverted source
pointer, full-character byte boundaries, and NUL storage when space
permits. The one-shot calls restart independently, and the legacy calls
check their stateless reset and null-character conventions.

Count-only restartable conversions ignore the output limit. The fixture
copies a partially decoded state and checks that both successful and
failing count-only calls preserve it and the source pointer. Separate
writing errors leave completed output intact and report the failing
character. The protected input and output checks use both mapping edges
and zero output capacity.

Project-specific recovery and private guard cases have explicit host
scope. Every added entry has its own typed zero-return rejection.

[Multibyte contract](../../../docs/adr/0012-c-utf8-multibyte.md) ·
[C17 multibyte conversions](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

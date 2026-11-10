# Independent wide classification oracle

Run `./tools/container make phase9-wctype`. The fixture reads the pinned
Unicode 16.0.0 UnicodeData, DerivedCoreProperties, and PropList text
directly. It computes class bits and simple case maps from the
published locale contract. The test oracle uses its own parser and
does not consume any generated classification tables.

For C.UTF-8 the fixture covers every code point from U+0000 through
U+10FFFF and checks selected out-of-range inputs and WEOF separately.
The C locale covers all ASCII and directed non-ASCII values. Both direct
classification and lookup by a descriptor are tested. Simple mappings,
invalid descriptor behavior, and errno preservation have their own
checks. The gate records raw data and stream digests, and all 18 public
symbols have typed zero-return controls.

The pinned glibc and musl builds check the C-locale shared domain. Their
full Unicode runs report differences against the same raw Unicode 16
reference because host Unicode versions and locale classification
policies may differ. Those runs still require the correct record count
and consistent descriptor dispatch and errno behavior.

[Locale contract](../../../docs/adr/0012-c-utf8-multibyte.md) ·
[Unicode 16.0.0](https://www.unicode.org/versions/Unicode16.0.0/) ·
[Unicode Character Database](https://www.unicode.org/reports/tr44/tr44-34.html)

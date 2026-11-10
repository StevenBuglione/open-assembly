# Wide formatted output

The six wide printf forms use the same integer and floating
conversion engines and SysV variadic argument layout as the
byte family. Width, precision, return values and %n count
wide characters in the wide family. Format literals retain
their wchar_t values. ASCII number text, padding and prefixes
widen without consulting the locale.

For %c, the low byte of the promoted int must be a complete
single-byte character in the current locale. %lc writes the
wide character. %s converts a multibyte string using the
current LC_CTYPE and an initial conversion state. %ls uses
wide input directly. String precision limits output in wide
characters and no conversion is attempted past that limit.
An encoding error reports EILSEQ.

A stream format requires wide orientation and uses the
stream's captured output encoding under its recursive lock.
A byte-oriented stream returns a negative result without
writing. An unoriented stream becomes wide-oriented.

The bounded string forms reserve one wide unit for the null.
A successful result gives the number of wide units before it.
Insufficient capacity, including zero capacity, returns a
negative result. A nonzero buffer retains the prefix that fits
and terminates it with a wide null. Count overflow reports EOVERFLOW.

[C17 wide formatted I/O, section 7.29.2](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf).

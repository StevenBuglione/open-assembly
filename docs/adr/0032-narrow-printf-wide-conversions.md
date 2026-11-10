# Wide arguments in byte formatted output

The byte printf family accepts `%lc` and `%ls`. Both convert
wide arguments using the current LC_CTYPE encoding and an
initial conversion state. `%lc` converts one wint_t value,
including a single null byte for the null wide character.
`%ls` encodes a wchar_t array up to its terminating null.

Precision limits the number of `%ls` bytes before field padding.
A character that would cross this limit contributes no bytes.
Field width, `%n`, and the return value count encoded bytes.
An invalid scalar or a character outside the selected encoding
sets EILSEQ and produces a negative result. The existing sink
rules apply to every conversion, including snprintf truncation,
string termination, and stream byte orientation.

[C17 fprintf, section 7.21.6.1](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf#page=244).

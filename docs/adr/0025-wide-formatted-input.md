# Wide formatted input

The six wide scanf forms read a wide format and consume wide
characters from a wide-oriented stream or a wide string.
The return counts assignments. Field widths and %n count wide
characters. Whitespace follows iswspace in the active LC_CTYPE.
Numeric subjects use the existing ASCII integer and exact
floating conversion engines, including their input boundaries.

The c, s and bracket conversions write wchar_t with the l
modifier. Without l they produce multibyte text in the active
LC_CTYPE with an initial conversion state. Strings and sets
terminate their destinations, and c requires its entire width
without appending a null. A suppressed conversion consumes the
input without writing a destination. Bracket sets support
negation, an initial right bracket and ascending ranges.

The stream form retains the stream's captured decoding rules
and locks the stream through the operation. One nonmatching
lookahead wide character is kept for the next input operation.
Its original byte extent and prior conversion state contribute
to the logical byte position and fgetpos. One caller ungetwc
remains available ahead of this lookahead.
A byte-oriented stream returns EOF without consuming input.
Invalid multibyte output reports EILSEQ. EOF before any
conversion completes returns EOF, and a matching failure
returns the number of preceding assignments.

[C17 wide formatted I/O, section 7.29.2](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf).

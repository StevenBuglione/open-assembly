# Bounded JSON

The package reads an immutable byte span and uses caller-owned
scratch and output arrays. It accepts one JSON value with optional
surrounding JSON whitespace (space, tab, LF and CR). Object names may
repeat and stay in source order. Number tokens preserve their original
decimal spelling and are never converted to machine numbers. Strings
require Unicode scalar values in UTF-8 or escapes. A high surrogate
escape requires an immediately following low surrogate escape.
Unpaired surrogates, unescaped control bytes, malformed UTF-8,
an initial BOM and trailing non-whitespace are syntax errors.
An escaped zero is allowed. The input needs no terminating byte.

[JSON, RFC 8259](https://www.rfc-editor.org/rfc/rfc8259.html).
[UTF-8, RFC 3629](https://www.rfc-editor.org/rfc/rfc3629.html).

## Lexical functions

`json_scan_string` and `json_scan_number` start at the supplied byte
offset and return the exclusive end of the lexeme. They accept no
leading whitespace. A number requires an integer part, digits after
a decimal point or exponent marker, and no extra leading zero.
The scanners do not consume the byte after a complete lexeme.

`json_lex` starts at an offset, skips JSON whitespace, and writes
three size_t words (kind, start, exclusive end). It returns zero
on success and leaves the record unchanged on failure. At input end
it reports kind 0 with both offsets equal to the input length.
Punctuation and scalar kinds have these values.

| Kind | Value |
| --- | ---: |
| End | 0 |
| String | 1 |
| Number | 2 |
| True | 3 |
| False | 4 |
| Null | 5 |
| Open brace | 6 |
| Close brace | 7 |
| Open bracket | 8 |
| Close bracket | 9 |
| Colon | 10 |
| Comma | 11 |

The lexer can return a complete prefix of a syntactically invalid
document. The parser checks relationships between lexical tokens.

## Document parser

`json_parse` takes scratch space of 3 + 2 × frame_capacity size_t
words. Each open array or object needs one frame. A scalar root
can use zero frames with the three required scratch words. The
workspace can change on any call.

The token array has four size_t words per token (kind, start,
exclusive end, parent index). The root parent is SIZE_MAX.
The parser emits a preorder token for each value, array, object,
and object key. Strings include their surrounding quotes.
Array and object tokens include both delimiters and all enclosed
bytes. Object keys are string tokens with the object as parent.
The successful return value is the token count. The parser
validates before writing any tokens and leaves unused records
unchanged. A null token array is valid with zero capacity.

The input, scratch and output ranges must be disjoint and remain
valid throughout the call. The same mutable arrays require caller
synchronization. All functions preserve errno. They return
-EINVAL for invalid required pointers or offsets beyond the end,
-EOVERFLOW for length greater than LONG_MAX or a wrapping extent,
-EILSEQ for invalid syntax, and -ENOSPC when a valid prefix exceeds
the frame limit or a valid document exceeds token capacity.
A null input is valid only with zero length.

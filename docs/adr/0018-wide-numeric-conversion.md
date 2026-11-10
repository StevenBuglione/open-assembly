# Wide numeric conversion

The wide integer family covers wcstol, wcstoll, wcstoul,
wcstoull, wcstoimax and wcstoumax. The floating family covers
wcstof, wcstod and wcstold. Each accepts native signed 32-bit
wchar_t input. Leading white space is classified by iswspace
in the active LC_CTYPE. Numeric digits and letters use the
ASCII grammar in both C and C.UTF-8. The radix character is
`.` and integer conversion has no binary prefix.

A nonnull end pointer receives the first unconsumed wide
character, or the original pointer if nothing converts. The
integer functions share the LP64 cutoff and overflow policy
of the narrow integer parser. An unsupported base or empty
subject sets EINVAL. An out-of-range subject consumes the
full digit run, saturates to the result limit and sets ERANGE.

The floating functions share the exact decimal and hexadecimal
rounding engine used by the narrow functions. Infinity and NaN
matching is ASCII case-insensitive. No conversion returns
positive zero and preserves errno. A valid floating result has
the same errno, exception flags and exact bit pattern as the
corresponding narrow subject in the current rounding mode.

The shared integer parser reserves private flag bit 2 for
four-byte input. The floating dispatcher uses bit 2 of its
private target selector for the same purpose. The float lexer
receives the input stride explicitly. Wide whitespace is
consumed before entering the shared parsers, and neither
path needs a temporary copy of the numeric subject.
[C17 wide numeric conversion, sections 7.8.2.4 and 7.29.4.1](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf).

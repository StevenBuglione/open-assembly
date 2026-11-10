# Independent wide modifiers in byte stdio

Run `./tools/container make phase9-narrow-wide`. All fifteen inherited
printf/scanf entry points in this slice are called directly, including
va_list forms and vasprintf. Common cases run against pinned glibc and musl.
Native, QEMU and strict Memcheck exercise the candidate, and every public
entry point has a generated-stub rejection.

Output cases check UTF-8 argument conversion, byte widths and counts, padded
wide strings without partial encoded characters at the precision boundary,
an embedded null from `%lc`, bounded byte truncation, encoding errors, and a
guard page immediately after a precision-limited nonterminated wide array.

Input cases test the ordinary conversion behavior with both hosts and
separately assert C17 byte-wise width and scanset selection. Project rows
test a field boundary inside an encoded scalar, matching a multi-byte set,
suppression with malformed input, complete-width `%lc`, untouched
destinations, and the next unread byte following an encoding failure.
Hosts can count decoded wide characters in cases where the project uses
the C17 byte rule. Those cases use the WG14 oracle directly.

[C17 7.21.6.1 and 7.21.6.2](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf#page=244)
[WG14 rationale MSE.10.1 on scanf byte selection](https://www.open-std.org/jtc1/sc22/wg14/www/C99RationaleV5.10.pdf#page=217)

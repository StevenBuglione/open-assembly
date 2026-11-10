# Wide calendar formatting

Wcsftime shares the existing C-locale calendar field renderer.
The format and output are arrays of native signed 32-bit
wchar_t. Literals are preserved, including non-ASCII wide
characters. Conversion fields, compound formats, and the E
and O fallbacks match strftime in the project's C and C.UTF-8
locales. Calendar text and valid timezone designations widen
from ASCII. A non-ASCII byte in a supplied timezone designation
causes wide formatting to fail. [Timezone designation syntax](https://www.rfc-editor.org/rfc/rfc9636.html).

The capacity counts wide characters and includes the terminal
null. Success returns the count without the null. Zero capacity
returns zero without accessing the destination. A format error
or an output that exceeds the capacity returns zero. Partial
output may already be present within the provided array.
Wcsftime preserves errno and allocates no storage.
[C17 wide calendar formatting, section 7.29.5.1](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf).

The private calendar renderer accepts a mode in r8d. Bit 0
selects wide output and bit 1 selects a wide format. Recursive
compound formats remain ASCII while inheriting the destination
width. The numeric field formatter receives the destination
stride explicitly.

# Locale codeset and XSI pi constant

The C and C.UTF-8 locale variants expose the name of the
active LC_CTYPE encoding through nl_langinfo(CODESET). The
strict C encoding is named ANSI_X3.4-1968 and the Unicode
encoding UTF-8. Results point to immutable static strings.
Unsupported item values return an empty string. Calls
preserve errno and allocate no storage.

The generated math declaration exposes the XSI double
constant M_PI. Its binary64 representation is
0x400921fb54442d18.

These declarations let the unchanged wide I/O integration
fixtures select their UTF-8 input and construct math vectors.
Other langinfo items and per-locale objects remain separate.
[POSIX locale information](https://pubs.opengroup.org/onlinepubs/9799919799/functions/nl_langinfo.html).
[POSIX math declarations](https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/math.h.html).

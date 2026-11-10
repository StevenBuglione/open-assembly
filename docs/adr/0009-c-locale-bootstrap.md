# C locale foundation

The process begins in the C locale. The initial locale surface
supports the C locale under the names C and POSIX. Queries and
successful selections return the canonical name C. An unsupported
selection fails atomically. The UTF-8 locale and its wide-character
interfaces belong to the later locale milestone.

An empty selection checks a nonempty LC_ALL, then the specific
category, then LANG. An unset or empty environment falls back to
C. LC_ALL without an overriding environment variable checks every
category. The entire selection succeeds only when all selected
categories resolve to a supported name. The C-only implementation
uses no mutable locale object.

The LP64 lconv object uses ten pointers followed by fourteen char
members, with two bytes of tail padding. Its decimal point is a
period, its other strings are empty, and its unavailable numeric
fields use the signed-char maximum of 127. The record initializes once under the runtime lock hooks. Callers
shall treat the record and its strings as read-only. The function signatures match the C17
declarations and use the same category integers as the Linux
glibc and musl headers. [C17 locale clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf).

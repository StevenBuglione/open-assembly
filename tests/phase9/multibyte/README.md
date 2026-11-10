# Independent C and C.UTF-8 conversion checks

The locale fixture checks the initial C selection, aliases and canonical
names, independent categories, environment precedence and restoration
of a mixed LC_ALL selection. It verifies that a failed selection leaves
all categories and errno intact. Both locales retain the C numeric
and monetary localeconv record.

The scalar fixture independently encodes every Unicode scalar value
using the UTF-8 bit layout in RFC 3629. UTF-16, UTF-32 and wide-character
pairs each check all 1,112,064 scalar values, including noncharacters
and the final scalar. Each run checks decoded values, output bytes,
terminator behavior, preserved errno and restored initial state.

Directed cases cover copied and split states, current-call byte counts,
surrogate staging and draining, distinct default state slots, null
input and output, and rejection with state reset. The malformed corpus
covers overlong forms, encoded surrogates, invalid continuation bytes,
out-of-range scalars, and high bytes in the C locale. The protected
mapping places input and output at both page edges. A zero byte limit
and queued UTF-16 result also use a protected input pointer.

The two conversion translation units include wchar.h and stdint.h in
opposite orders. The strict pinned build caught conflicting WCHAR_MIN
and WCHAR_MAX macros in the first header freeze. The corrected freeze
uses the compiler's compatible definitions and retains both orders as
regression coverage.

Hosted tests cover the common cases. The project-specific C high-byte
btowc check is disabled on the host path because pinned musl accepts
that byte in its C locale. The hosted scalar sweep allows a larger
MB_CUR_MAX because pinned glibc advertises six bytes. The project
locale tests still require exactly four in C.UTF-8.

Every public entry has a dedicated typed zero-return rejection. The
default state checks in this tranche run in one thread. A worker-local
default-state check needs the integrated thread descriptor.

[Locale and state contract](../../../docs/adr/0012-c-utf8-multibyte.md) ·
[UTF-8, RFC 3629](https://www.rfc-editor.org/rfc/rfc3629.html) ·
[C17 multibyte conversions](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

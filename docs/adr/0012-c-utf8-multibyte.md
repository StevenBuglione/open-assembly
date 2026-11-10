# C and C.UTF-8 locales and multibyte state

The process starts in C. The accepted names are C, POSIX, C.UTF-8
and C.utf8. Queries return the canonical name C or C.UTF-8. The
six categories retain their names independently. An LC_ALL query
returns the common name when all categories agree, or a
semicolon-separated list of category assignments when they differ.
An LC_ALL string returned by the library can be passed back to
setlocale to restore the selection. Invalid selections return null
with the previous selection and errno intact.

An empty locale name resolves a nonempty LC_ALL first, then the
specific category variable and LANG. An absent or empty setting
falls back to C. The selection of multiple categories commits
only after every category resolves. This tranche changes the
multibyte encoding through LC_CTYPE. Both locales retain the
C numeric and monetary conventions. Their collation and wide
character classifications have separate contracts.

LC_CTYPE=C accepts single ASCII bytes and code points 0 through
127. LC_CTYPE=C.UTF-8 accepts shortest UTF-8 encodings of Unicode
scalar values, including noncharacters. It rejects overlong
forms, surrogate encodings, invalid continuation bytes and values
above U+10FFFF. MB_CUR_MAX is one or four respectively. A
conversion inspects only the supplied byte count and leaves
unrelated output bytes intact. [UTF-8 encoding constraints](https://www.rfc-editor.org/rfc/rfc3629).

The public mbstate_t is an eight-byte object aligned to four
bytes. Zero initialization describes the initial state. An
incomplete conversion stores its progress in the caller's
object. Conversion routines with a null state pointer use
distinct, initially zero state slots in each thread. State
objects may be copied by value. A program changes LC_CTYPE
between conversions in the initial state. The implementation
clears the affected state on EILSEQ. Successful and incomplete
conversions preserve errno.

The decoder reports the bytes consumed by the current call. A
complete null character writes zero and returns zero. An
incomplete input returns (size_t)-2 and writes no output. An
encoding error returns (size_t)-1, sets EILSEQ and writes no
output. A zero byte limit reads no bytes. A null input pointer
is equivalent to a null byte with a limit of one and an ignored
output pointer.

The UTF-16 decoder emits the first surrogate with the count of
bytes consumed, then emits its queued low surrogate with
(size_t)-3 and consumes no input. The encoder queues a leading
surrogate in C.UTF-8 and returns zero without writing. A valid
low surrogate completes the pair. An unpaired surrogate is an
encoding error. C rejects a leading surrogate immediately. A null destination is equivalent to encoding a
null code point into an internal buffer, which also detects
an unfinished surrogate pair. [C17 multibyte clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf).

The private thread descriptor reserves offsets 0x80 through
0xff for locale and multibyte state. Twelve independent
eight-byte state slots begin at 0x80. Startup and worker TLS
allocation provide at least 256 bytes beyond the thread pointer when
this extension is enabled. [Runtime TLS ABI](0002-runtime-abi.md).

Restartable string conversion advances the caller's source
pointer only when writing output. A count-only call ignores
the output limit and preserves the source pointer and state.
A conversion that reaches the terminating null stores it when
space permits, resets the state and sets the source pointer
to null. A byte-output limit never splits a multibyte character.
On error, a writing call leaves the source pointer at the first
unconverted character and preserves the completed output.
Count-only calls use separate private thread state copies.

The nonrestartable string conversions begin in the initial
state on every call. The legacy single-character conversions
return zero for a null source or destination reset, as both
encodings are stateless. An invalid or incomplete character
in a legacy call returns minus one and sets EILSEQ.

Wide string and memory routines operate on complete signed
32-bit wchar_t elements. Their comparison sign follows the
first unequal element. Both supported locales collate wide
strings in code-point order, and wcsxfrm uses an identity key.
A size query returns the key length. A writing call stores
the full key only when its terminator fits.

Wide classification in C follows the ASCII classes. In C.UTF-8,
Unicode 16.0.0 supplies Alphabetic, Uppercase, Lowercase,
White_Space and General_Category. Alphabetic includes the upper
and lower classes. Decimal and hexadecimal digits remain the
C language's ASCII sets. Blank includes horizontal tab and
space separators. Control uses the Unicode control category.
Print includes letters, marks, numbers, punctuation, symbols,
space separators and private-use characters. Graph excludes
white space, and punctuation includes graphical Unicode
punctuation and symbols outside the alphanumeric classes.
Case mapping uses one-to-one mappings between the corresponding
upper and lower classes. [Unicode 16.0.0 UCD](https://www.unicode.org/versions/Unicode16.0.0/).

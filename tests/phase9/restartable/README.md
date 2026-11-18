# Restartable multibyte verification

The original multibyte fixtures and zero stubs remain the baseline.
These additions use an independent UTF-8 scalar encoder and prefix
decoder. The model owns logical progress and imports no conversion,
classification, state, string, or memory helper. The replay separately
compiles model.c against candidate and both hosted headers and requires
no undefined symbols.
[UTF-8 encoding rules](https://www.rfc-editor.org/rfc/rfc3629.html)

Actual mbstate_t objects are opaque. They are zero-initialized or
copied by ordinary value assignment. The test passes their addresses
to public interfaces and observes result, output, errno, and mbsinit.
It never compares or reads their internal bytes or fields. The guards
belong to a test-owned container outside the state object. A copied
partial state is resumed independently after the original completes.
Two other partial states are interleaved with independent scalars.
[Project conversion contract](../../../docs/adr/0012-c-utf8-multibyte.md) ·
[WG14 restartable conversion clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

The shared cases use ASCII in C and Unicode scalars in C.UTF-8,
including noncharacters and U+10FFFF. They check current-call byte
counts, NUL, bytewise resume, a split and copied state, independent
states, pwc=NULL, default state separation, and defined initial
NULL input/output forms. Zero-length calls use protected input pages
with an initial or partial state. Every partial default state is
completed before changing locale. Encoder states stay initial because
both supported encodings are stateless; decoder-partial states are
never passed to the encoder.

Input chunks and output arrays are placed at either edge of readable
pages surrounded by inaccessible pages. Incomplete and NUL-reset calls
must retain ignored output. Encoders check all output bytes and extra
accessible sentinels. Source bytes, state-container canaries, and byte
or wide-output canaries are checked after every call.

Project-only contract cases verify strict rejection, unchanged output,
EILSEQ, state reset through mbsinit, and a subsequent successful call.
The hosted policy probe starts every call with a fresh explicit state
and never inspects it after an error. It retains exact return, output,
and errno without using the post-error state for a later call.

Pinned musl C uses surrogate escapes for high bytes and can encode
U+DF80 as byte 0x80. Pinned glibc C.UTF-8 accepts some non-Unicode
four- and five-byte inputs and can encode U+110000. Those observations
are outside the shared scalar packet domain and remain explicit.

Each input is two little-endian uint64 words. The first selects one
of fourteen scenarios using its low 62 bits, and input/output page
edges using its high bits. The second selects scalar values and locale.
The 64-byte output contains the last result, observed scalar or input
encoder value, packed output bytes, checked step count, observation
digest, errno, scenario, and flags. mbsinit results use only zero versus
nonzero. A digest class value of two means that the private default
state is unobserved; it is never read or classified through mbsinit(NULL).

ABI statuses 11–13 identify machine state, result or errno, and
output/state-container mismatches. Semantic statuses 21–25 identify
return result, output, errno, public state classification or container
guards, and source bytes/canaries. The 90s identify fixture setup,
model-generation invariants, or packet I/O and mapping cleanup errors.

The public mbrlen entry is called through a typed volatile function
pointer because pinned glibc otherwise inlines its header wrapper.
The hosted object must still contain a direct public mbrlen reference.
The initial inline-header snapshot and failed symbol audit are retained.

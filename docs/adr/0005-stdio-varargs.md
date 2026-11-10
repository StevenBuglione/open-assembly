# Phase 4 stdio and variadic contract

Phase 4 adds byte streams, integer formatting and scanning, and the first
assembly file utilities. It uses the startup environment and allocator from
Phase 3. The [C17 stdio clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)
define public semantics for the supported conversions. Floating-point
formats and wide stream orientation belong to later phases. Public file
and process APIs, remove, rename, tmpfile, and tmpnam belong to Phase 6.

## Byte streams

The generated test header declares an opaque FILE type, fpos_t, and the
three standard stream pointers. EOF is -1. The buffering constants are
_IOFBF = 0, _IOLBF = 1, _IONBF = 2, and BUFSIZ = 4096. SEEK_SET, SEEK_CUR,
and SEEK_END are 0, 1, and 2. Startup initializes stdin, stdout, and stderr
before calling main. A terminal uses line buffering on stdout. Other
stdout streams start fully buffered. Stderr starts unbuffered. Opened
streams start fully buffered.

Each stream owns a descriptor, buffer state, direction, one byte of
pushback, EOF and error indicators, and a registry link. The library
serializes ordinary operations with a recursive per-stream lock. Explicit
`flockfile` ownership and implicit I/O share that lock and use the calling
thread's TLS identity. Unlocked entry points bypass acquisition. The
registry has a separate lock. It may be acquired under a stream lock
during disassociation and rebinding. Code releases the registry lock
before waiting for a stream. A flush of all streams pins a pointer
snapshot under the registry lock, flushes each open output stream under
its own lock, and drops the pins. Allocation failure returns EOF.
Closing unlinks the stream before closing its descriptor, releases
the stream lock, and defers object disposal until the last pin drops.
Formatter and scanner scratch records each have their own lock, taken
after any stream lock. These operations may acquire the allocator lock.
Caller
buffers supplied to setvbuf stay caller-owned. No library path frees those
buffers. Future stream layouts can add wide orientation and conversion
state without changing the public pointer ABI.

- fopen accepts C17 r, w, a, optional b and +, and x for exclusive w
  modes. Text and binary are the same on Linux. Write mode truncates,
  append mode sets kernel O_APPEND, and read mode leaves existing data
  intact. Failed open or initialization releases resources. freopen
  closes the former association and uses the same stream object. A NULL
  pathname for changing modes is unsupported and fails with EINVAL.
- fread and fwrite count complete elements. A zero size or count touches
  no data and does no I/O. A partial last element can consume or produce
  bytes without increasing the element count. Multiplication overflow
  returns zero with EOVERFLOW and sets the stream error indicator.
- Reading that encounters end of file sets the EOF indicator. A failure
  sets the error indicator. clearerr clears both. The underlying byte I/O
  retries EINTR and accounts for short transfers. The I/O wrappers from
  Phase 1 retain their original single-syscall behavior.
- Output buffering flushes when full, on a newline in line-buffered mode,
  or immediately in unbuffered mode. fflush(stream) writes all pending
  output and retains any unwritten suffix on a transfer failure.
  fflush(NULL) visits all output streams and returns EOF if any fails.
  A seekable input stream discards unread buffering by restoring the
  logical descriptor position. An unseekable input stream can report
  ESPIPE when repositioning is necessary.
- Read and write state records which direction owns buffered bytes.
  A permitted switch after a successful flush or position call resets
  that direction. Automatic switches also synchronize the previous
  direction where possible. Existing buffered input is never silently
  discarded when a transition needs its logical position.
- fgetc and getc return an unsigned byte as int or EOF. fputc and putc
  write the low byte of their int argument. ungetc accepts one byte and
  clears EOF on success. EOF as an argument and a second pending byte
  fail without altering the pending byte. fgets retains the first
  newline, returns a terminated string when it succeeds, and returns
  NULL for a nonpositive size or end of file before a byte. A size of
  one returns an empty string.
- fseek and fsetpos reset buffering on success and clear EOF. ftell and
  fgetpos use the logical position, including unread input, pushback, and
  buffered output. rewind seeks to the start and clears both indicators.
  fpos_t reserves state for later wide stream support. It is opaque to
  applications except for passing a saved value back to fsetpos.
- setvbuf configures buffering before the first stream I/O. Use NULL to
  request library-managed storage. For a caller buffer, the length must
  be positive in buffered modes. setbuf selects full or unbuffered mode.
- fclose flushes and closes, even if a flush fails. Closing removes the
  stream from the registry and frees only library-owned storage. Input
  read-ahead is discarded without seeking on close, including for pipes.
  Normal exit runs registered callbacks before flushing all output.
  Immediate exit and fatal runtime paths still bypass callbacks and
  stdio. perror writes the current C-locale error message, with a
  nonempty prefix followed by a colon and space, then a newline.

## SysV AMD64 variadic ABI

A va_list is an array containing one 24-byte record. Its fields are
gp_offset and fp_offset at offsets 0 and 4, overflow_arg_area at offset 8,
and reg_save_area at offset 16. An integer or pointer argument uses one
eight-byte general-purpose slot while gp_offset is below 48. It then
uses eight-byte overflow slots on the caller's stack. Integer default
promotions apply to char and short. A variadic wrapper initializes its
offset from its fixed argument count and points overflow_arg_area to the
first stack argument. The standard GPR save slots occupy offsets 0
through 47. The eight vector argument slots start at offset 48 and have
a 16-byte stride. The caller supplies an upper bound on used vector
argument registers in al. Phase 4 has no format that fetches those
slots. Phase 5 will spill and use them and handle stack-aligned long
double.

The v forms take the same va_list representation that C compilers
produce. They may advance that list. Their callers use va_end and make a
copy before passing the same list to another consumer. A formatting
wrapper and its v counterpart use the same interpreter.

## Integer formatting

The supported family is printf, fprintf, sprintf, snprintf, vprintf,
vfprintf, vsprintf, and vsnprintf. It recognizes d, i, o, u, x, X, c, s,
p, n, and percent. Integer lengths are hh, h, l, ll, j, z, and t.
The flags are minus, plus, space, number sign, and zero. Width and
precision accept digits or a promoted int from an asterisk. Negative
width requests left adjustment, and negative precision omits precision.
The usual rules for zero precision and zero value apply. An alternate
octal form supplies one leading zero where needed. A hexadecimal prefix
is present in an alternate form only for a nonzero value. The project
pointer rendering uses lowercase 0x followed by hexadecimal digits,
including 0x0 for NULL. A percent n stores the count so far in the
requested type and writes no bytes.

On success the return is the full count excluding a final NUL.
snprintf writes at most size minus one bytes and terminates when size is
nonzero. Its destination may be NULL when size is zero. Truncation does
not change the returned full count. An unrepresentable count returns
a negative value with EOVERFLOW. Stream errors return a negative value.
Unsupported conversions report EINVAL. A format error can occur after
earlier output. A string conversion with precision can read exactly the
permitted bytes from a string without a terminator in that range.

## Integer scanning

The supported family is scanf, fscanf, sscanf, vscanf, vfscanf, and
vsscanf. It recognizes d, i, o, u, x, X, c, s, p, n, percent, and bracket
sets. Integer lengths are hh, h, l, ll, j, z, and t. Field width limits
input bytes. An asterisk suppresses an assignment. Numeric conversions
and s skip C-locale whitespace. c and bracket sets do not. Whitespace
in the format consumes zero or more input whitespace bytes. The scanner
consumes an optional sign, the radix prefix when applicable, and the
matching digit run. Numeric input items can end in a prefix that fails
to match, such as 0x without a hexadecimal digit. The following
nonmatching byte remains unread.

Percent c defaults to one byte and adds no NUL. Percent s and bracket
sets add a terminating NUL when assignment succeeds. Bracket sets allow
an initial caret, an initial closing bracket as a member, and byte
ranges with a hyphen. Percent n stores the number of bytes consumed so
far and does not increase the assignment count. The scanner returns the
number of assignments, or EOF if input failed before any conversion
completed. Unsupported conversions report EINVAL. Values outside the
destination's representable range are outside the C17 input contract.

## Assembly applications

cat copies bytes from named files or standard input to standard output.
A lone hyphen denotes standard input. wc counts bytes, newline
characters, and words separated by C-locale whitespace. Both return
nonzero on a transfer or open failure. wc accepts -l, -w and -c,
including combined options, and prints selected counts in line, word,
byte order with one space between fields. An explicit input name follows
the counts. Multiple operands also produce a total line. Both commands
accept -- before operands. Build them with `tools/container make apps`.
The binaries are placed in `build/runtime/apps/` by default.

The test suite can compare valid
integer formats and stream outcomes against an independent C model and
the pinned system libraries. It should compare project-specific pointer
and unsupported-format policies against the declared contract.

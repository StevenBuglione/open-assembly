# Loopback epoll HTTP acceptance application

`httpd [port]` listens on IPv4 `127.0.0.1`. The optional port is
one or more decimal digits with value at most 65535. The default
is zero so the kernel selects an available port. The program
writes `PORT <actual-port>\n` to standard output when ready. A
startup or event-loop failure exits with status 1. An invalid
command line exits with status 2. A supervisor terminates the
server with SIGTERM after the test.

The single-process event loop uses level-triggered epoll and
nonblocking descriptors. Up to 64 client slots hold 8192
request bytes each. At capacity newly accepted connections are
closed. A slot with five elapsed monotonic seconds of inactivity
is closed on a periodic sweep. Interrupted operations can be
retried. Short reads and writes carry their remaining bytes to
later readiness events. Sends use MSG_NOSIGNAL, so one peer reset
leaves other clients available.

## Parser entry point

The app-private SysV symbol `__al_http_parse` has signature
`unsigned __al_http_parse(const unsigned char *bytes, size_t length)`.
This bridge calls `http_parse` from the [HTTP extension](../../ext/http/README.md).
The gate links the same package objects for the app and its guard-page,
mutation and differential fuzz fixtures. The parser reads at most the supplied
span and 8192 bytes, performs no allocation or I/O and leaves
errno and the input intact. A zero-length span may have a null
pointer. Nonzero spans require readable input.

The low 16 result bits hold the status. Zero means more bytes
are needed. Bit 16 is set for a syntactically valid HEAD request
that selects status 200 or 404. All other bits are zero. The
first CRLF CRLF ends the header section. Bytes after it are
ignored because the application closes after one response.
An incomplete span shorter than 8192 bytes returns zero even
if its prefix is malformed. If no terminator fits within the
first 8192 bytes, the status is 431. A terminator ending at
byte 8192 fits.

A complete request uses this local origin-server grammar.

- The request line has a case-sensitive HTTP token, exactly
  one ASCII space, a nonempty origin target starting with `/`,
  exactly one ASCII space, and `HTTP/1.0` or `HTTP/1.1`.
  Target bytes are visible ASCII with `#` excluded. The target
  is compared as bytes, without percent decoding.
- Every field begins with a nonempty HTTP token followed
  immediately by `:`. Values permit HTAB and ASCII bytes
  0x20 through 0x7e. Field names are case-insensitive for
  Host, Content-Length and Transfer-Encoding. Each line
  ends with CRLF. Leading whitespace in field names and
  continuation lines are invalid.
- HTTP/1.1 requires exactly one Host field. HTTP/1.0 permits
  one or zero. After trimming ASCII SP and HTAB, the value
  has one or more ASCII letters, digits, dots or hyphens and
  optionally a colon followed by one to five digits forming a
  port from 0 through 65535.
- A single Content-Length of one or more zero digits is
  permitted after trimming SP and HTAB. Duplicate lengths,
  positive lengths and any Transfer-Encoding field are
  invalid. This application has no request body processing.

Malformed complete requests return 400. After syntax and
framing validation, GET and HEAD on `/` return 200, GET and
HEAD on another target return 404, and other method tokens
return 405. A partial request at EOF causes the server to close
that connection. The response has an HTTP/1.1 status line,
Connection: close and Content-Length. The 200 representation
is the 14 bytes `open-assembly\n`, with media type text/plain
and no body for HEAD. Error responses have zero length. The
405 response includes `Allow: GET, HEAD`.

The strict single-space and CRLF policy and message framing
rules are based on [HTTP/1.1](https://www.rfc-editor.org/rfc/rfc9112.html).
The authority and resource grammar limits are specific to this
loopback acceptance application.

# Bounded HTTP request heads

These operations read caller-owned byte spans and preserve errno.
They allocate no memory and perform no I/O. The bytes remain
readable for the duration of the call. An empty span may use a
null pointer.

`http_find_header_end` returns the exclusive offset of the first
complete CRLF CRLF, or zero if the supplied span has no terminator.
It accepts the whole caller span and has no fixed size limit.

`http_is_token_byte` returns one for an HTTP token character and
zero for any other unsigned byte. This predicate uses the ASCII
token grammar independently of locale. [HTTP Semantics, RFC 9110](https://www.rfc-editor.org/rfc/rfc9110.html#section-5.6.2).

`http_parse` applies the [loopback request grammar](../../docs/adr/0014-loopback-http.md)
to at most 8192 bytes. Its low 16 bits contain zero for an incomplete
request or the HTTP status (200, 400, 404, 405 or 431). Bit 16 marks
a valid HEAD request selecting 200 or 404. Bytes after the first
terminator do not affect the result.

The parser grammar describes an origin server that closes after
one response. It accepts HTTP/1.0 and HTTP/1.1, origin-form
targets, the documented Host syntax and an optional zero
Content-Length. Transfer-Encoding is a syntax error.

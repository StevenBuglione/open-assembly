# Wide stream orientation and basic I/O

A newly associated stream has no orientation. A byte I/O
operation establishes byte orientation and a wide I/O operation
establishes wide orientation. `fwide` queries or establishes
orientation under the stream lock. Its return is negative for
byte, positive for wide, and zero for unoriented. A successful
`freopen` clears orientation and the conversion state. Other
positioning and buffering calls keep the established orientation.

Wide orientation captures the active LC_CTYPE encoding for the
life of the association. Later locale changes leave that encoding
intact. The C encoding is strict ASCII and C.UTF-8 uses Unicode
scalar values. The stream has its own multibyte state and one
public wide pushback slot. The runtime consumes bytes through the same
buffering and descriptor paths as byte I/O. Wide I/O retains the
recursive per-stream lock for the operation, including multi-unit
string reads and writes.

A wrong-orientation I/O request returns its failure sentinel
without changing errno or stream indicators. Zero-sized fread
and fwrite leave orientation intact. Fgets and fgetws with
capacity one return an empty string and establish orientation
without reading. A wide encoding error returns WEOF, sets EILSEQ
and sets the stream error indicator. A partial encoded character
at EOF is an encoding error. EOF between characters sets EOF.
A descriptor read failure retains partial conversion state so
reading can resume when the failure clears.

Ungetwc stores one wide character and clears EOF. WEOF and a
second pending character fail without altering the slot. The
synthetic wide character occupies no external bytes and is read
before any scanner lookahead. A pending scanner lookahead retains
its original byte extent and prior conversion state. The extent
counts as unread in the logical position. Successful positioning
discards pushback and clears the current conversion state. Input
synchronization rewinds the logical unread bytes and retains the
state at that position. Fgetpos records the logical byte offset
and state, and fsetpos restores both under the stream lock.

The private FILE header grows from 128 to 176 bytes. Existing
lock, pin, depth and ownership fields at offsets 96 through 120
retain their positions. Orientation and captured encoding occupy
32-bit fields at 128 and 132. The eight-byte mbstate_t begins at
136, public wide pushback is at 144, and the internal scanner
lookahead is at 148. Eight scratch bytes begin at 152. The
lookahead byte extent and prior conversion state are at 160 and
168. The inline 4096-byte buffer begins at 176. Constructors
allocate 4272 bytes for this layout. Fpos_t stays 16 bytes.

[C17 stream orientation and wide I/O, sections 7.21.2 and 7.29.3](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf).

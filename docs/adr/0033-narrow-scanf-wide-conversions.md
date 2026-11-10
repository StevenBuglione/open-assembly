# Wide destinations in byte formatted input

The byte scanf family accepts `%lc`, `%ls` and `%l[`. The
scanner selects the field byte by byte. Width, `%n`, whitespace
and scansets keep the byte scanner's rules. One unmatched byte
remains unread. Each wide conversion decodes the selected
bytes in the active LC_CTYPE from an initial conversion state.

`%lc` requires the full byte width, with a default of one byte,
and writes no terminator. A short or malformed `%lc` leaves its
destination intact. `%ls` and `%l[` write a terminating wide
null after successful decoding. Suppressed conversions still
validate the encoding. An invalid sequence or a field boundary
within a sequence is an encoding input failure with EILSEQ.
An underlying read error retains its own errno.

[C17 fscanf, section 7.21.6.2 and footnote 292](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf#page=249).

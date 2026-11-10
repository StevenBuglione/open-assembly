# Core wide-element verification fixtures

The original wide manifest supplies directed C-locale cases and exact
generated zero-stub controls for the four functions. The supplemental
typed cases capture a full `size_t` or pointer result, or the sign of
the low 32-bit integer result. The `wmemchr` probe poisons the upper half
of the signed wchar_t argument register. The `wcslen` probe uses readable
padding after a string containing +1, -1, and WCHAR_MIN.

The directed guard cases place each input independently at either edge
of a mapped page with inaccessible pages on both sides. The adjacent
readable element is a canary. The timed cases use the same placement and
check every input element after the call. A zero bound uses a protected
address. Nonterminated `wcsncmp` inputs expose exactly the bounded
elements at the right edge. The `SIZE_MAX` cases use terminated arrays.
[WG14 wide comparison clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf#page=332)

The model compares full signed 32-bit wchar_t values and uses only the
comparison sign. The search compares the exact returned address with the
first matching element before emitting its offset. The fixtures use raw
arrays including high-bit values, equal low bytes with differing high
bytes, signed extrema, and zero. Memory searches cover matches after zero,
repeated matches, absence, and a match beyond the bound.
[Project wide-element contract](../../../docs/adr/0012-c-utf8-multibyte.md) ·
[WG14 wide search and length clauses](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf#page=336)

The packet input contains two little-endian uint64 words. The first
encodes the scenario and two edge choices. The output contains the
signed normalized result and unsigned scenario, input lengths, bound,
needle bits, object digest, and errno. A missing search result has
offset -1. ABI statuses 11–13 cover machine state, result or errno, and
input preservation. Guard and packet statuses 21–23 cover result,
errno, and input preservation. The 90s identify fixture setup or I/O.

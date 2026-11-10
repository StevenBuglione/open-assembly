# Private wide-span boundary

The internal SysV interface has this declaration.

```c
size_t __al_wide_span(const wchar_t *input, const wchar_t *set, uint32_t mode);
```

Both pointers identify readable NUL-terminated arrays of signed 32-bit
`wchar_t` elements. Mode zero counts the initial elements absent from the
set. Mode one counts the initial elements present in the set. The source
terminator is excluded from either result. Element membership compares all
32 bits. The function preserves both arrays, errno, and the ordinary SysV
callee-saved machine state.

Only modes zero and one belong to this private boundary. The complete
shipped source inventory has two direct callers. `wcsspn` sets EDX to one,
and `wcscspn` sets EDX to zero immediately before their helper calls.
`wcspbrk` reaches the zero-mode path by calling `wcscspn`. These public
interfaces have no user-controlled mode argument. Their reachable helper
domain therefore consists of those two modes. The proof must bind the
caller sources and actual archive members as well as the helper. A new
caller or a change to either mode assignment requires a new domain review.

The independently authored matching fixtures supply the expected behavior
through both public span operations. A separate helper proof can reuse
those expectations while replacing, tracing, and mutating the actual helper
member. It must observe the helper entry, cover both directions of every
raw conditional edge, reject an automatic helper zero stub at the named
typed-result status, and compare both packet selectors against independent
hosted observations for at least 60 seconds each. Public wrapper results
remain scoped until the source, object, archive, complete repeated runtime
map, and helper report identities are bound together.

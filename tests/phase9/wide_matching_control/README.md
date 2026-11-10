# Ordinary wide substring control

The first call has a genuine match after wchar_t values +1 and -1.
The haystack is {+1,-1,+1,-1,17,0,...}; the needle is
{+1,-1,17,0,...}. C17 requires the returned pointer to the second
+1 at offset two. Both arrays contain explicit readable elements
after their first NUL.
[WG14 wide substring clause](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

Subsequent calls test the first of multiple matches, suffixes,
an empty needle with readable trailing elements, an absent needle
that appears after the haystack's first NUL, a longer needle, and
an empty haystack. An independent bounded model reads full wchar_t
elements and stops at the first NUL. It calls no string helper.

Each call uses fully initialized automatic wchar_t arrays. The
fixture verifies exact returned pointer, errno preservation, and
every input and marker element. Status 21 identifies a wrong
pointer, 22 changed errno, and 23 changed input. The generated
zero-return stub must fail the first ordinary call with status 21.
The normal result is silent status zero.

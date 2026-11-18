# Proposed memmove signedness equivalence proof

This is a review proposal, not automatic permission to remove a mutant from
the applicable denominator. The raw campaign runs and retains every operator.
It does not inherit the older `production.py` equivalence labels.

The exact source is `src/x86_64-linux/string/memmove.asm`, SHA-256
`0d280e67a9e08a4acfc70222ce1b14e27e7225ccb0a38ed46936db51486ea54f`.
The two proposals are `comparison-signedness-30` (`jb` to `jl`, after
`cmp rdi, rsi`) and `comparison-signedness-36` (`jae` to `jge`, after
`cmp rcx, rdx`). Each is an independent one-instruction mutation.

The public domain supplies two contiguous, nonwrapping byte regions of the
same length n, readable source and writable destination, or n=0. This proof
does not execute a candidate with manufactured pointers or oversized objects.
Linux x86-64 supports 48- and 57-bit canonical virtual addresses. Each
canonical half is smaller than 2^63 bytes, and a nonempty accessible contiguous
region cannot cross the intervening noncanonical hole. Thus each region has
n<2^63. This includes the high-address legacy vsyscall page where readable;
the proof does not assume every user address has bit 63 clear. The
[Linux 6.6 virtual memory map](https://www.kernel.org/doc/html/v6.6/arch/x86/x86_64/mm.html)
describes both canonical layouts and the legacy mapping. The same canonical
constraints apply to the supported old-kernel matrix.

Let D=[d,d+n) and S=[s,s+n). For n=0 or d=s, unchanged early exits precede
either altered conditional; the return value is the original d.

For n>0 and d!=s, overlapping regions must lie in the same canonical half.
Signed and unsigned ordering of d and s then agree. Therefore the line-30
mutation makes the same direction decision for both overlap orders. If d<s,
the forward loop reads each source byte before its destination can overwrite
a later unread source byte. If d>s and the regions overlap, delta=d-s is
positive and delta<n<2^63. At line 36 both delta and n are nonnegative signed
64-bit numbers. Signed and unsigned comparison therefore agree and choose
the backward loop, which reads each source byte before an earlier
destination write can overwrite it. This covers all overlapping calls.

For disjoint D and S, both loops copy exactly the original n source bytes
to their matching destination bytes: writes never modify the source region.
Either changed comparison may choose a different loop, including when d and
s occupy different canonical halves or a subtraction has its high bit set.
That direction change is immaterial to the public result. Each loop accesses
only offsets 0 through n-1, and both terminate after n iterations. There is no
requirement to preserve the source/destination argument registers.

Both mutations leave `mov rax,rdi` before all movement unchanged. Neither
loop changes RAX, saved registers, RSP, DF, MXCSR control, x87 state, or errno.
Neither introduces imports or instructions beyond the changed conditional.
The temporary-copy result, exact returned destination, and ABI preservation
therefore agree for n=0, self moves, both overlap orders, and disjoint ranges
in either address order, including a readable high-address source mapping.

The argument depends on supported x86-64 canonical addressing and ordinary
public object validity. A target permitting a contiguous accessible region
of at least 2^63 bytes, tagged noncanonical addresses, or a different source
must invalidate this proposal and require another review.

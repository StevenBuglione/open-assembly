# Configured DNS nameserver failover

Use the first three distinct valid numeric nameservers in
`/etc/resolv.conf`, in file order. A configured IPv4 or IPv6
address uses port 53. Malformed addresses and duplicate
sockaddrs are skipped. If none is configured, use IPv4 loopback.
The forward and reverse paths each inspect up to 256 lines
accepted by the bounded configuration line reader.

For each absolute forward candidate and eligible family, or for
a reverse PTR query, try each selected server at most once
per configured round.
A matching answer or negative name result ends that sequence.
Try the next server after EAI_AGAIN or EAI_FAIL. Allocation
failure ends the sequence immediately. If the entire sequence
fails, prefer EAI_AGAIN if any attempt returned it, or EAI_FAIL
otherwise. This selection occurs before forward search-list
advancement or reverse numeric fallback.

Each server attempt has its own absolute UDP deadline and,
after a matching truncation reply, a separate TCP deadline.
[Resolver options](0042-resolver-options.md) set the deadline
budget, rounds and starting server. Resolver environment
overrides and scoped nameserver literals remain outside this
policy.

The private configuration reader retains its documented
argument sizes. Its former scratch region at search record
offset 1544 now begins with the 80-byte alternate server bank.
Nameserver-only mode writes the same bank to resolver context
offset 832. The bank has a 32-bit alternate count (zero through
two), two 32-bit sockaddr lengths, four bytes of padding and
two 32-byte sockaddr slots starting at offset 16. The primary
sockaddr and length stay separate. Unused bank bytes are
scratch. The wire builder also supports a null output pointer
to measure a valid query under the same capacity limit.

[Linux resolver configuration](https://man7.org/linux/man-pages/man5/resolv.conf.5.html) ·
[DNS over TCP](https://www.rfc-editor.org/rfc/rfc7766.html).

# Resolver search lists

Forward DNS uses the [configured nameservers](0041-resolver-failover.md)
from `/etc/resolv.conf` and port 53. The loopback IPv4 fallback
and transport deadlines are unchanged. The resolver reads up to
256 physical lines accepted by the 4095-byte line reader.

The last `search` or `domain` directive supplies the list.
Search uses the first six valid suffixes on its line. Domain
uses the first suffix and ignores following words. Invalid
suffixes and the root-only suffix are skipped. A directive
with no accepted suffix clears the list. An optional trailing
root dot is stripped from a suffix. Search suffixes use the
forward DNS ASCII label grammar.

The last valid decimal `ndots:n` option sets the threshold,
with default one and a maximum of 15. The parser ignores
malformed options. A name ending in a root dot is absolute
and never gets a search suffix. A name with at least ndots
dots tries the absolute spelling first, then its configured
suffixes. Other names try suffixes first, then their absolute
spelling. Candidates too long for DNS are skipped.

The resolver completes the eligible A and AAAA attempts for
each candidate before moving to the next candidate. Only
EAI_NONAME advances the list. A result, a transport timeout
or a fatal resolver error ends the search. AI_CANONNAME
reports the selected DNS owner. Numeric, local-file and
synthetic results keep precedence over DNS. AI_NUMERICHOST
and reverse PTR never use the search list.

Environment overrides, address sorting and DNSSEC remain separate
work. [Resolver options](0042-resolver-options.md) configure transport
timeouts, retry rounds and server rotation.
[Linux resolv.conf](https://man7.org/linux/man-pages/man5/resolv.conf.5.html) ·
[DNS names](https://www.rfc-editor.org/rfc/rfc1035.html#section-2.3.4).

The private configuration reader takes the shared resolver context
(5184 writable bytes), a 32-byte sockaddr buffer and either a null
search pointer or an 1816-byte writable search record. It returns
the sockaddr length, 16 for IPv4 or 28 for IPv6.

```c
unsigned int __al_dns_config(void *context, struct sockaddr *server,
                             void *search);
```

The first two native 32-bit words of a search record are suffix count
and ndots. Six 256-byte suffix records follow, each terminated by a
null when present. A final 272-byte region holds the alternate
server bank and scratch. Unused bytes have unspecified contents. A null search pointer
selects nameserver-only processing, which also backs reverse lookup.

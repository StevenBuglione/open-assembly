# Resolver timeout, retry and rotation options

The resolver reads timeout, attempts and rotate on `options`
lines for forward and reverse DNS. The existing file, line and
server caps apply. A numeric option requires a nonempty string
of decimal digits. The last valid instance wins. Invalid options
leave the previous setting intact.

- `timeout:n` sets the per-phase transport deadline in seconds.
  Clamp the value to 1 through 30. The default is two seconds.
  UDP and any matching truncation-triggered TCP retry each get
  their own absolute deadline.
- `attempts:n` sets the number of rounds over the configured
  servers for each question. Clamp the value to 1 through 5.
  The default is one round. A server is tried at most once per
  round. Matching answers, negative names and allocation failures
  keep their existing terminal behavior.
- `rotate` picks a starting index from a process-wide atomic
  counter for each question with multiple servers. Retry rounds
  begin at the same index and preserve the cyclic server order.
  A caller without this option starts at the first server.

There are at most 15 server attempts per question. The existing
per-candidate family and search limits remain in force. If every
attempt fails, retryable status takes precedence over fatal
status. The configured server bank keeps its first 80 bytes.
Three additional native 32-bit words at offsets 112, 116 and
120 store timeout seconds, attempt rounds and the rotation flag.

The existing private `__al_dns_query` keeps its two-second
transport ABI. `__al_dns_query_timeout` adds an unsigned sixth
argument in milliseconds, from 1 through 30000, with the same
result and errno behavior. An invalid budget clears the answer
count and returns EAI_AGAIN. Configuration overrides use this
entry when the timeout differs from the default.

The default budgets preserve the project's existing resolver
policy. Environment overrides, scoped nameserver literals,
DNSSEC validation, IDNA and address sorting remain outside
this configuration scope.

[Linux resolver configuration](https://man7.org/linux/man-pages/man5/resolv.conf.5.html).

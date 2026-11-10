# Threaded fork fixtures

The callback tests observe LIFO prepare and FIFO completion with separate
nonblocking pipes for the parent and child. They cover a registration made
during prepare, concurrent registration and the exact project capacity,
the callback-free _Fork, spawn and shell paths, and parent completion after
injected kernel failure. A positive fork child must have a different process
ID from the caller so a zero-return stub cannot satisfy the test.

The worker fixture forks inside a live one-time initialization while a
separate worker owns a mutex and a stream. Child checks use direct Linux
TID observation, TLS loads and _exit. The test compares the surviving
descriptor fields against the published ABI, including the canary, active
once frame, multibyte state and TSD value. Hosted probes check the portable
thread and process observations.

[POSIX fork](https://pubs.opengroup.org/onlinepubs/9799919799/functions/fork.html) ·
[Project ownership and callback rules](../../../docs/adr/0043-threaded-fork.md)

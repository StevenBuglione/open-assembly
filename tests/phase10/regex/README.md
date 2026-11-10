# Independent POSIX regex checks

Run `./tools/container make phase10-regex`. The independent cases cover
BRE backreferences, ERE captures, leftmost longest matching, line anchors,
empty repetition, suppressed captures, diagnostic truncation and one
targeted compilation allocation failure. Project policy cases also verify
compilation-locale capture and the distinction between Unicode character
length and reported byte offsets.

The independent finite model enumerates all 3,280 strings over a three-byte
alphabet through length seven for each of four grammars. Common cases run
against pinned glibc and musl. Each of the four API symbols has a direct
generated-stub rejection.

Eight unchanged pinned libc-test regression inputs each run on native
Linux, QEMU and Memcheck. The gate also checks the original upstream
compile-only API fixture and records all original source hashes.

[POSIX regex functions](https://pubs.opengroup.org/onlinepubs/9799919799/functions/regcomp.html)

# Independent pathname expansion checks

Run `./tools/container make phase10-glob`. Each case creates an isolated
directory tree. Common glibc and musl comparisons check relative and
absolute anchors, repeated separators, dotfiles, symbolic and dangling
links, marking directories, sorted append batches and reserved null
offsets. The project fixture separately checks exact slash spelling.

A missing directory invokes the callback, which runs a nested glob.
The fixture checks both abort routes and retention of previously appended
matches. A second fixture injects a read error after the first matching
directory entry and verifies the partial result remains owned.

The allocation observer first measures the requests in a successful append
and then injects ENOMEM at each one. It checks retained earlier matches,
a valid null-terminated result and complete cleanup through globfree.
Native Linux, QEMU and Memcheck run all candidate cases. Two generated
stubs independently establish direct glob and globfree coverage.

[POSIX pathname expansion](https://pubs.opengroup.org/onlinepubs/9799919799/functions/glob.html)

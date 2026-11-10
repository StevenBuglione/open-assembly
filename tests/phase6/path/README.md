# Independent PATH execution checks

The fixture creates isolated executables and a permission-denied file
using Linux modes. Its script arguments include whitespace and a leading
hyphen. It observes the resulting argument vector and child environment
through deterministic output from the pinned shell.

The cases cover explicit paths, runtime environment replacement, left
to right search, ENOENT and ENOTDIR continuation, remembered EACCES,
empty elements, an unset PATH, and the project pathname bound.
The ENOEXEC cases separate `execvp` shell fallback from the direct
`posix_spawnp` error. Spawn search reads the caller's PATH while the
child receives its explicit environment. Candidate checks also cover
the spawn return convention, unchanged PID output on failure and
preserved errno. Hosted runs compare the common behavior with the
project-specific errno check disabled for `posix_spawnp`.

Three directed cases have explicit host exclusions in the manifest.
The pinned glibc probe agrees on the shell fallback, while musl returns
ENOEXEC. Both hosts differ when every candidate exceeds the project
pathname bound. When a long component precedes a valid one, the pinned
musl probe agrees and the pinned glibc probe runs the current-directory
script. The native, QEMU and Memcheck candidate checks keep all three
expectations.

The three zero-return controls exercise the named entry directly with
an error that cannot return zero.

[Linux execve](https://man7.org/linux/man-pages/man2/execve.2.html) ·
[Austin Group Issue 1674](https://www.austingroupbugs.net/view.php?id=1674)

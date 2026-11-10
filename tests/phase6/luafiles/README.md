# Independent temporary-file fixtures

The ordinary probes compare glibc, musl and the candidate against Linux
file observations. They check removal of files, links and directories,
continued access through existing descriptors, and rename replacement
with separate retained inode identities and bytes. The mkstemp probe
checks exclusive names, owner-only permissions, read/write access, and
invalid templates. The project case also checks template restoration on
a failed name attempt.

The tmpfile probe locates its new descriptor through Linux fcntl, verifies
the anonymous inode, and exercises binary update mode and descriptor
release. Project-only assertions check close-on-exec and initial full
buffering.

The armed syscall wrapper first injects one interrupted randomness
request and one exclusive-name collision, then checks the successful
mkstemp result. A separate case injects an unsupported anonymous open,
observes the real named fallback, and checks its unlink, close-on-exec,
update stream, and eventual descriptor release. Both cases forward
unrelated operations. Four generated stubs reject through the ordinary
candidate cases.

[Linux unlink](https://man7.org/linux/man-pages/man2/unlink.2.html) ·
[Linux rename](https://man7.org/linux/man-pages/man2/rename.2.html) ·
[POSIX mkstemp](https://pubs.opengroup.org/onlinepubs/9799919799/functions/mkstemp.html)

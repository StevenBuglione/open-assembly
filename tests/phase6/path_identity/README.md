# Linux path function fixtures

The existing Phase 6 file and compatibility manifests retain the directed
oracles and generated stub controls for `getcwd`, `readlink`, `unlink` and
`rmdir`. This supplemental manifest adds typed return checks and shared timed
packet cases. The ABI trampoline captures a full pointer or signed `ssize_t`
for the first two and the low 32 bits of the `int` result for the others.
Each ABI case exercises a successful call and a deterministic kernel error.

The packet runner reads two little-endian 64-bit words per input and writes
eight little-endian 64-bit words per result. The first two result words are
signed result and errno. The other words hold the scenario, operation extent,
observed length, byte digest or retained file byte, side effects, and original
errno. The candidate and both hosted libraries use the same source. The fixture
checks the full absolute `getcwd` string against a raw Linux call before
emitting the normalized final component and relative extent. `readlink`
checks exact binary bytes and compares the surrounding canaries. The removal
cases use raw descriptor and directory lookups to verify entry identity,
retained data and inode link counts independently of the tested return.

The `readlink` count-zero case uses a separate raw Linux witness. The candidate
and pinned glibc return -1 with EINVAL, while pinned musl returns 0 with unchanged
errno. All preserve the caller canaries. The shared differential case therefore
uses positive counts. The zero-count fixture emits the unnormalized public
result and errno, raw Linux result and both canary words. [Linux readlink](https://man7.org/linux/man-pages/man2/readlink.2.html) · [POSIX readlink](https://pubs.opengroup.org/onlinepubs/9799919799/functions/readlink.html)

The `getcwd` wrapper observes one public call at a time. It supplies only a
controlled ENOMEM, bounded Linux unreachable pathname, or raw -4095. The
short owned-buffer case passes through to Linux and observes the owned release.
The separate native case installs a real seccomp filter and requires both
the raw -4095 and the public NULL, errno 4095, and unchanged bytes.
[Linux seccomp errno boundary selftest](https://github.com/torvalds/linux/blob/f91a3aa6bce480fe6e08df540129f4a923222419/tools/testing/selftests/seccomp/seccomp_bpf.c#L923) · [Linux getcwd](https://man7.org/linux/man-pages/man3/getcwd.3.html)

Expected semantic rejection statuses are 11–13 for typed ABI or cwd packets,
21–22 for readlink packets, 31–33 for removal packets, 41 for the zero-count
readlink result, and 21–29 for the scoped getcwd fault cases. Statuses in the
90s indicate setup, raw witness, transport or cleanup failures.

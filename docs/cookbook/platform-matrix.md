# Linux platform matrix

Run `./tools/container make phase11-seccomp` for the current native Linux
seccomp scope. The statically linked test requires `CAP_SYS_ADMIN` to be
absent, sets `PR_SET_NO_NEW_PRIVS`, and installs a real x86-64 BPF syscall
allowlist. A before-and-after `getppid` observation checks that the new
kernel filter is active. The test exercises allocator copy fallback after
`mremap` returns `ENOSYS` or `EPERM`, realtime fallback after a denied vDSO
lookup, and unchanged append file contents after `pwritev2` returns
`ENOSYS`. A second filter denying the raw clock verifies that `time`
actually uses the fallback. [Linux seccomp filter documentation](https://docs.kernel.org/userspace-api/seccomp_filter.html)

Run `./tools/container --old-kernel make phase11-old-kernel` to exercise
current native Linux and a separately booted Debian `4.19.0-27-amd64`
(4.19.316-1) guest. The optional project image uses pinned QEMU system
emulation in TCG mode. It needs neither KVM nor a network device. The test
creates a deterministic initramfs from its three static executables. It
checks assembly and C startup, worker TLS isolation, thread create/join,
clock and allocation behavior, and append-position semantics. Inside the
old guest it confirms actual `clone3` `ENOSYS`, existing `clone`-based thread
creation, and a fail-before-write outcome for unsupported `RWF_NOAPPEND`.

The same candidate binaries also run the independent directory iteration
and refill, signal delivery and suspension, spawn success and failure,
TCP loopback, poll and epoll, same-socket TCP readiness, and PTY terminal
attribute/session/error cases on both kernels. The guest PID 1 brings up
its private loopback interface and mounts its private devpts instance.
Every case runs in an isolated directory with the original arguments and
environment. Guest console markers require zero status and silent child
streams, matching the native expectations.
[QEMU direct Linux boot documentation](https://www.qemu.org/docs/master/system/linuxboot.html)

The [Debian package index](https://archive.debian.org/debian-security/dists/buster/updates/) binds the exact amd64 package
SHA-256 to a `Release` signed by Debian's buster and bullseye security keys.
The `nix/old-kernel.nix` derivation pins that package and verifies the
extracted `bzImage` hash before the gate boots it.
[Debian archive signing keys](https://ftp-master.debian.org/keys.html)

Reports are written to `build/evidence/phase11-seccomp.json` and
`build/evidence/phase11-old-kernel.json`. An unavailable filter, QEMU system
binary, or pinned kernel leaves the corresponding report incomplete and
returns a nonzero status. The reports cover the named platform probes and
do not supply per-function platform acceptance for other APIs.

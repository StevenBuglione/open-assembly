# open-assembly

An assembly-authored libc project targeting x86-64 Linux System V, ISO C17,
and a named POSIX subset. Phase 0 provides specifications, test fixtures,
and independent verification tools. Phase 1 provides a static startup
object and runtime archive with initial-thread TLS and errno, a private
Linux syscall boundary, basic I/O, exit callbacks, and stack-protector
failure handling.

With Nix and Docker available, run the milestone acceptance checks in the
pinned toolchain container.

```sh
./tools/container make -k phase0 phase1 phase2 phase3 phase4 phase5 phase6-files phase6-compat phase6-busybox phase6-process phase6-signal phase6-jump
```

Phase 2 covers the C-locale string and character functions, integer
conversion, `qsort`, and `bsearch`. Run `./tools/container make gate FUNC=strlen`
for one production candidate and `tools/queue status` for its current state.

Phase 3 adds the allocator family and environment APIs. Its freestanding
gate exercises allocator and environment models, ABI state, and injected
mapping failures against the shipped runtime.

Phase 4 adds byte streams, integer formatted I/O, and assembly utilities.
Use `./tools/container make apps` to build `cat` and `wc` in
`build/runtime/apps/`.

Phase 5 adds floating conversion, floating-point environment control, and
floating formatted I/O. Its gate uses pinned MPFR and independent vectors.

The Phase 6 file and directory slice adds filesystem and descriptor APIs.
Its compatibility slice runs six pinned BusyBox applets against the same
freestanding runtime archive. The initial process gate covers process IDs,
fork, execve, wait, and atomic pipe flags. Signal and non-local jump gates
exercise real handlers, saved masks, and register restoration. The next
scopes cover time64 clocks, Gregorian UTC, temporary files, and explicit
path spawning. The shell slice covers command execution and pipe streams.
The PATH slice exercises caller PATH search and child environments. Local
time remains separate Phase 6 work. [Phase 6 ABI](docs/adr/0007-linux-files-process-signal-time.md)

```sh
./tools/container make phase6-time phase6-calendar phase6-luafiles phase6-spawn phase6-shell phase6-path
```

The gates write evidence to `build/evidence/`. Use
`./tools/container make runtime` to build `build/runtime/crt1.o` and
`build/runtime/libopenasm.a`. The cookbook lists the checks and the remaining
per-function production requirements. [Verification cookbook](docs/cookbook/verification.md)

The project records its scope, runtime ABI, and current specifications in
the repository. [Project contract](AGENTS.md) ·
[Scope](docs/adr/0001-project-scope.md) ·
[Runtime ABI](docs/adr/0002-runtime-abi.md) · [API index](docs/api-index.md)

The roadmap lists the remaining milestones and their exit gates.
[Roadmap](docs/plan.md)

Licensed under the MIT License.

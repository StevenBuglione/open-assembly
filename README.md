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
./tools/container make phase0 phase1 phase2
```

Phase 2 covers the C-locale string and character functions, integer
conversion, `qsort`, and `bsearch`. Run `./tools/container make gate FUNC=strlen`
for one production candidate and `tools/queue status` for its current state.

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

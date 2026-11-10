# open-assembly

An assembly-authored libc project targeting x86-64 Linux System V, ISO C17,
and a named POSIX subset. Phase 0 provides specifications, test fixtures
and independent verification tools. The repository currently has zero
production libc implementations.

With Nix and Docker available, run the Phase 0 acceptance checks in the
pinned toolchain container.

```sh
./tools/container make phase0
```

The gate writes evidence to `build/evidence/`. The
[verification cookbook](docs/cookbook/verification.md) describes the checks,
individual commands and requirements still pending for production.
The [API index](docs/api-index.md) reflects the current specification
inventory.

Project constraints are recorded in [AGENTS.md](AGENTS.md) and
[the scope decision](docs/adr/0001-project-scope.md). See
[the roadmap](docs/plan.md) for subsequent milestones.

Licensed under the MIT License.

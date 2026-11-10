# open-assembly

An assembly-authored libc project targeting x86-64 Linux System V, ISO C17,
and a named POSIX subset. The project is at Phase 0, building its specification
and independent verification infrastructure.

The accepted roadmap is in [docs/plan.md](docs/plan.md). Project constraints
and the first milestone are recorded in [AGENTS.md](AGENTS.md) and
[the scope decision](docs/adr/0001-project-scope.md).

The development environment is pinned by `devenv.lock`. Use
`nix shell nixpkgs#devenv --command devenv shell` to enter it. Automated
validation uses the same packages in the toolchain container.

Licensed under the MIT License.

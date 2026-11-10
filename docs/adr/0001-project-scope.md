# Project scope and first milestone

The accepted target is x86-64 Linux System V with hand-written NASM,
static non-PIE ELF, and baseline SSE2. The long-term standard is ISO C17
plus an explicitly inventoried POSIX subset. This repository starts empty.

The zero-C boundary applies to shipped runtime, libraries, extensions, and
applications. C test harnesses and generated test-only headers are allowed.
Development tooling may use Python and shell. The project license is MIT.
These choices follow the supplied plan and were selected during setup.

The first implementation assignment covers Phase 0 only. Its exit requires
real tooling and harnesses, all seeded defects rejected for their intended
reason, a passing good fixture, and a deliberately wrong strlen rejected by
the semantic gate. Fixture assembly lives under tests/ and supplies no
production libc implementation.

The full inventory and verification pipeline may grow in later milestones.
Any incomplete standards inventory or unsupported verification must be
visible and must prevent evidence from claiming full conformance.

The pinned Nix package set in devenv.lock supplies both the developer shell
and the Docker toolchain image. Automated validation runs inside that image.
No machine-level configuration changes are needed.

Implementation uses separate GPT-6.1 sessions at xhigh reasoning. Test authors
receive only specifications and harness interfaces. The coordinator reviews
results, resolves ownership, runs acceptance checks, and integrates work.

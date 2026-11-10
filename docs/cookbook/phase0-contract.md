# Phase 0 integration contract

All commands run from the repository root. Python uses the standard library.
Tools return zero only on success and useful diagnostics on failure.

The spec/tooling agent owns spec/, include/asm/, tools/spec.py, tools/gen,
tools/queue, tools/provenance, tests/tooling/test_spec.py, docs/api-index.md,
and docs/cookbook/specifications.md. It establishes the strict TOML schema,
a clearly scoped inventory, deterministic generators, provenance checks,
and evidence-derived queue state. It owns no implementation assembly.

The checker/gate agent owns tools/lint, tools/lint.py, tools/gate,
tools/gate.py, tools/stubcheck, tools/mutate, tools/coverage, tools/elf-audit,
Makefile, .github/workflows/, tests/fixtures/, and docs/cookbook/verification.md.
It writes the positive and deliberately wrong test-only strlen fixtures,
the static checker and executable verification pipeline. No production code
under src/ is part of Phase 0.

The independent test agent owns tests/seeded-bugs/, tests/abi/, tests/unit/,
tests/fuzz/, tests/oracle/, tests/external/, tests/tooling/test_lint.py and
docs/cookbook/test-oracles.md. It may read specs, this contract, and tool CLI
help. It must not inspect tools/lint.py, tools/gate.py, or tests/fixtures/
implementations before test authorship is complete. It should write at least
30 independent seeds with distinct intended failure modes and positive
controls based on the public contract. It owns all expected values and
oracle declarations in its tests.

The agents must agree their exact CLI and manifest fields by messaging each
other before finalizing interfaces. The public entry point is `make phase0`.
`make gate FUNC=strlen` must run a real semantic demonstration and report
its fixture scope. It must not mark a production function verified.
`tools/lint PATH...` rejects invalid assembly, reports rule identifiers, and
returns nonzero on unknown or unanalyzable input. `tools/gen --check` detects
stale outputs. `tools/queue next` only selects satisfied dependencies, using
fresh content-bound successful evidence. No hand-written verified status.

Evidence is written under ignored build/evidence/ and uploaded by CI. It
must distinguish Phase 0 acceptance from future complete per-function gates.
Unimplemented coverage, mutation, or conformance checks are pending and
cannot silently count toward production verification.

A passing Phase 0 needs reproducible commands, positive controls, all seeded
bugs rejected for their intended rule, a generated stub rejected, and a
semantically wrong strlen rejected by tests. Runtime harnesses should exercise
callee-saved registers, RSP, DF, MXCSR control state, guard pages, and host
libc differential behavior. More advanced future campaigns remain visible.

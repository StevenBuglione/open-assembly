# Phase 0 verification

Run the milestone inside the pinned toolchain.

```sh
./tools/container make phase0
```

The milestone checks the generated spec outputs and provenance, runs the
independent checker corpus, and assembles and tests three `strlen` fixtures.
The corpus first assembles every file with NASM, then checks that each
negative's first diagnostic matches its manifest and that every positive
control passes. A generated-header control checks rejection of calls to
external functions with no modeled ABI signature. Separate fault controls
exercise the runtime ABI trampoline and the guard probes against
intentional ABI violations, under-reads, over-reads, and writes.

The good fixture must pass the ABI trampoline, fixed vectors, guard-page
probes, glibc differential tests, and a 60-second differential fuzz run.
The guard-page probes also run under Valgrind Memcheck. The ABI trampoline
runs natively because the pinned Valgrind reports different x87 and MXCSR
control state for that probe.
The stub generated from the function spec and the off-by-one fixture must
pass lint and the ABI trampoline, then fail all four behavioral probes
with named oracle mismatches. Their fuzz probes run the fixed minimum
number of cases. The gate also applies five mutations to the good fixture,
covering branch inversion, signedness, and one-byte changes. It assembles
and links every mutant and requires at least 90% to be killed by the
behavioral probes. An unexpected build error, crash, timeout, or oracle
transport failure fails the gate.

The gate compiles both C objects with `-ffreestanding -fno-builtin`. It uses
`nm` to check for an undefined candidate symbol in the C and ABI harness
objects and a definition of that symbol in the final executable. The
original fixture exports `strlen`; the gate renames the symbol on a copy
of the object to keep calls inside statically linked glibc independent of
the candidate. The oracle runs in a separate static executable, built
from a C object with its own unresolved `strlen` reference. ELF auditing
checks the relevant assembly objects for an empty non-executable stack
note and compiler producer metadata. It checks the test executables for
static non-PIE layout, a non-executable stack and resolved symbols.

## Individual checks

```sh
./tools/container tools/lint --function strlen tests/fixtures/strlen.good.asm
./tools/container tools/stubcheck strlen
./tools/container tools/gate strlen --fixture wrong
./tools/container tools/mutate strlen
./tools/container make gate FUNC=strlen
```

The wrong-fixture command exits 1 on the semantic rejection. Inspect its
evidence for the named oracle failures and the passing ABI probe.
`tools/stubcheck` exits 0 when the good control passes and the generated
stub fails its behavioral probes. `make gate FUNC=strlen` runs the entire
fixture demonstration, including the timed fuzz run and bounded mutation.
It reports fixture scope in its evidence.

## Static checker scope

`tools/lint PATH...` accepts a constrained NASM subset with direct calls,
analyzable branch targets and finite abstract state at each join. External
calls require modeled ABI signatures. It
checks callee-saved registers, stack offsets and alignment, direction
flag, narrow integer arguments, variadic `al`, x87 depth and control word,
MXCSR control, syscall placement and clobbers, SSE2 baseline and the GNU
stack note. Private syscall paths must explicitly establish `r10`. At
calls the checker verifies that a variadic count in the ABI range was
set. Runtime tests remain responsible for the function's semantics and
the actual values supplied to callees.

Unknown instructions and directives, preprocessor expansions, indirect
or cross-function jumps, escapes of the tracked frame address, and stack
accesses the checker cannot resolve fail closed. The Phase 0 subset
supports fixed stack frames and requires explicit executable sections.
Fixture-only ABI annotations are restricted to the independent checker
corpus. Public assembly gets its narrow-argument and variadic metadata
from specs and requires a matching generated comment header.

## Evidence and production requirements

Read `build/evidence/phase0.json` for milestone acceptance. The reports
`build/evidence/checker-corpus.json` and `build/evidence/runtime-probes.json`
contain the individual static checker and runtime fault controls.
Per-function fixture evidence is `build/evidence/strlen.json`. The report
records input, tool, and artifact hashes, commands, exit statuses and test
output. Time-bounded fuzzing uses the reported seed and runs at least the
same fixed prefix. Elapsed execution speed determines the total number
of cases after that prefix.

Production verification remains pending for source-mapped branch
coverage, AFL++ or libFuzzer campaigns, musl differential testing,
external conformance suites, full per-function mutation, and the platform
matrix. `tools/coverage strlen` and `tools/gate --production strlen`
exit nonzero while those checks are unavailable. Phase 0 supplies
test fixtures only.

On pull requests, CI compares the protected oracle and external test paths
with the base commit. New files are allowed. Edits, deletions, moves and
type changes to existing files fail the check.

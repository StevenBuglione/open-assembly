# Verification

## Phase 3 allocator and environment acceptance

```sh
./tools/container make phase3
```

The Phase 3 gate links freestanding fixtures against the shipped startup
and runtime archive and compares their artifacts across two builds. The
allocator model checks 6,144 seeded operations, including aligned and
zero-size requests, reuse, resize, and preservation on failure. Slab churn
exercises capacity and reclamation. The environment model checks 4,096
seeded lookup and mutation operations, borrowed strings, aliasing, and
preservation of startup vectors.

Separate test binaries wrap the private syscall boundary to inject
mapping failures and observe matching maps and releases. The normal
fixtures run against the unwrapped runtime. The gate runs the allocator
and environment cases natively, under QEMU, and under Valgrind. The
CPU-state trampoline runs natively. Memcheck sees slab mappings as
addressable, so the independent live-object model checks the boundaries
and contents of the allocations within each slab.

The gate requires an independent rejection of each of the ten public
function stubs. It records its result in `build/evidence/phase3.json`.
[Allocator and environment oracles](../../tests/phase3/README.md)

## Phase 2 function gates

```sh
./tools/container make gate FUNC=strlen
./tools/container tools/coverage strlen
./tools/container tools/stubcheck strlen
./tools/container tools/mutate strlen
./tools/container make phase2
```

The production gate uses the shipped assembly source and the independent
manifest under `tests/phase2/`. It renames the candidate and its linked
assembly dependencies in copies of the objects so the hosted test process
can still call glibc or musl independently. The numeric differentials use
the host thread-local errno accessor. Phase 1 tests the runtime's own TLS
and errno accessor on the freestanding link.

Each local gate checks the static ABI model, executable symbols, native ABI,
fixed vectors, guarded access where applicable, and glibc and musl
differentials. It runs the fixed fuzz prefix and a 60-second libFuzzer
campaign. LibFuzzer instruments the C harness. A QEMU plugin measures
the actual assembly branches and maps both outcomes of each conditional
jump to its NASM source line. Valgrind runs the guard test or, for scalar
functions, the unit test.

The semantic probes must reject a generated zero-return stub. Mutation
applies branch inversions, signedness changes, one-unit comparison changes,
and return offsets. An attributed oracle failure counts as a kill. A
build failure, unexpected signal, or timeout fails the campaign. Reviewed
equivalent mutations are listed separately with their exact source hash
and proof. The kill threshold is 90 percent of applicable mutants.

The pinned upstream libc-test snapshot supplies functional cases that
exercise selected candidates. The gate compiles each unchanged test
against the renamed candidate symbol and records the test and license
hashes. [Pinned libc-test source](https://repo.or.cz/libc-test.git/commit/63e36e934e8f2bedf645303a90b64098e2af6c8f)

The batch runs independent functions concurrently and checks public
dependencies first. It combines the nine numeric wrappers' coverage and
mutation tests into a separate result for the shared integer scanner.
A wrapper with no branches still needs fresh scanner evidence.

Production reports use `build/evidence/<function>.production.json`.
The queue checks the current source, tests, tooling, and pinned inputs
before using a pass. Run `python3 tools/phase2.py --only coverage` in
the pinned toolchain for a batch of candidate-only branch checks.
The later nightly and release platform matrices are separate.

## Phase 1 runtime acceptance

```sh
./tools/container make runtime
./tools/container make phase1
```

The runtime build produces `build/runtime/crt1.o` and
`build/runtime/libopenasm.a`. Link the startup object, then the application
objects, then the archive. The Phase 1 gate uses `ld` directly with
`-static -no-pie --gc-sections -e _start` and checks the symbols resolved by
the link. Each C test is compiled with `-ffreestanding -fno-builtin`. Its
required assembly references must appear as strong undefined symbols before
linking and resolve to the runtime in the executable.

The gate builds in two isolated directories and compares hashes of the startup
object, archive, archive members, test objects, and executables. Each archive
member must match its standalone object. The ELF audit checks each assembly
object for the GNU stack note, executable section flags, and compiler
producer metadata. Every linked executable must be static non-PIE, with a
non-executable stack, no writable executable load segment, and no unresolved
symbols.

The assembly and compiler-built hello worlds run natively, with QEMU user-mode
emulation, and under Valgrind Memcheck. The independent runtime manifest
also checks the startup vectors, TLS image, stack guard, syscall register
mapping, errno and I/O, interrupted reads, exit and callback order, and fatal
paths. It names the oracle and records the expected exit status and byte
output for each case. The exact-environment startup cases run natively and
under QEMU. Memcheck injects an `LD_PRELOAD` entry, which a separate startup
case checks alongside the TLS assertions. The two stack-failure cases run
natively because QEMU and Memcheck add their own fatal-signal diagnostics.

One generated stub per public Phase 1 function replaces calls to that
function through the static linker. Each selected independent probe must
report its expected rejection. A link error or an unexpected crash fails
the gate. The full report is `build/evidence/phase1.json`, with source and
tool hashes, expected and observed results, and reasons for backend skips.

## Phase 0 fixture verification

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

### Individual fixture checks

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
accesses the checker cannot resolve fail closed. Public assembly gets its
narrow-argument, variadic, and non-returning metadata from specs and requires
a matching generated comment header. Fixture-only annotations are restricted
to the independent checker corpus.

The runtime model distinguishes Linux process entry from a System V call.
The startup code can read the initial argument count and derive the initial
argument-vector address. The private syscall wrapper can read its seventh
argument from the caller's stack. The signal restorer is constrained to
Linux `rt_sigreturn` and a trap fallback. The modeled indirect call in
`exit` requires a pointer loaded from the registered-callback table.
The `errno` accessor may read the thread control block pointer through
`fs:0`. Literal data and zero-initialized storage use explicit non-executable
sections. Data exports must have a modeled runtime owner.

## Evidence and production requirements

Read `build/evidence/phase0.json` for milestone acceptance. The reports
`build/evidence/checker-corpus.json` and `build/evidence/runtime-probes.json`
contain the individual static checker and runtime fault controls.
Per-function fixture evidence is `build/evidence/strlen.json`. The report
records input, tool, and artifact hashes, commands, exit statuses and test
output. Time-bounded fuzzing uses the reported seed and runs at least the
same fixed prefix. Elapsed execution speed determines the total number
of cases after that prefix.

Phase 0 supplies test fixtures. Its evidence cannot verify production
functions. Run the separate production gate for functions with an
independent Phase 2 manifest.

On pull requests, CI compares the protected oracle and external test paths
with the base commit. New files are allowed. Edits, deletions, moves and
type changes to existing files fail the check.

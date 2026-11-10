# Verification

## Phase 6 files, directories, and BusyBox slice

```sh
./tools/container make phase6-files phase6-compat phase6-busybox
```

The file and compatibility gates build and audit two isolated runtime archives.
They run freestanding tests natively, under QEMU, and under Memcheck, and run
shared assertions against pinned glibc and musl. Every API in these two scopes
has an exact generated-stub rejection. Fault probes cover malformed directory
records, pipe descriptor exhaustion, allocated formatting failure, and unlocked
stream lock ownership. The manifests record backend-specific omissions.

`./tools/container make phase6-fcntl` checks typed variadic descriptor
control, 64-bit process and OFD locks, and successful negative process
group owners. It also exercises the reserved -1 result using the
container's PID namespace and requires the exact bad-fd stub rejection.
Evidence is written to `build/evidence/phase6-fcntl.json`.
[Descriptor control fixtures](../../tests/phase6/fcntl/README.md)

The BusyBox gate extracts the pinned 1.37.0 source with networking disabled.
It builds the six selected upstream applets with freestanding, no-builtin
flags, then uses the actual Kbuild link objects and the Open Assembly startup
object and archive. It audits the resulting static executable, attributes its
required symbols through the linker map, and compares two candidate links.
The applets exercise file bytes, counts, directory contents, descriptor and
mode changes, and an error diagnostic under native Linux, QEMU, Memcheck,
and the hosted musl control. Directory comparison preserves duplicate counts
and allows filesystem order. The upstream Memcheck run checks memory accesses
and initialized reads. [Phase 6 ABI](../adr/0007-linux-files-process-signal-time.md)

`./tools/container make phase6-process` checks initial process and wait APIs
against the same freestanding runtime. It exercises raw process IDs, child
status, fork, and self-exec with explicit argv, environment, and descriptor
inheritance. Its manifest describes backend transitions during exec and
includes exact generated-stub rejection for each scoped API.

The signal and jump suites run with `make phase6-signal phase6-jump`. They
exercise Linux mask and disposition round trips, signal-handler dispatch, the
kernel restorer, saved-mask semantics, and the non-local jump register state.
Their manifests record exact stub outcomes and measured host or backend
differences.

`./tools/container make phase6-zone` checks local civil conversion,
TZif versions 1 through 4, malformed and missing zone files, transition
folds and gaps, and overflow without partially publishing a result.
The inputs include the exact RFC 9636 examples and a pinned IANA zone.
The report records the shared host comparisons and exact stub outcomes.
[Zone fixtures](../../tests/phase6/zone/README.md)

The next scoped targets are `phase6-time`, `phase6-calendar`,
`phase6-luafiles`, `phase6-spawn`, `phase6-shell`, and `phase6-path`.
They cover real and injected clock
results, UTC boundaries and rounding, exclusive temporary file operations,
spawn attributes and ordered descriptor actions, shell and pipe-stream
lifecycle, and PATH search with exec and spawn. Each records separate
backend, host, and stub observations. Local time and per-function
production checks have separate requirements.

The `phase6-strftime` gate checks C-locale directives and modifiers,
exact buffer limits, and the ISO week-year across a full 400-year cycle.
Its manifest records the host comparison scope for custom zone names.

`./tools/container make phase6-sqlite` runs three pinned SQLite 3.53.3
workloads: speedtest1, the threadtest3 shared-cache readers, and the
single-worker threadtest5 control. The gate checks reproducible archive-only
links and compares results under native Linux, QEMU, Memcheck, glibc and musl.
[SQLite workload details](../../tests/external/sqlite/README.md)

## Phase 8 thread lifecycle

`./tools/container make phase8-sync phase8-c11` checks the independently
authored synchronization and C11 fixtures. The reports bind the same
freestanding archive to native, QEMU, and Memcheck runs, hosted comparison
cases, and exact per-symbol stub rejections. The C11 fault fixture wraps
only the runtime syscall boundary for selected mmap, nanosleep, and
scheduler-yield operations. Cancellation, process-shared and robust
mutexes, and full detector stress remain separate scopes.
[POSIX synchronization fixtures](../../tests/phase8/sync/README.md) ·
[C11 thread fixtures](../../tests/phase8/c11/README.md)

`./tools/container make phase8-lifecycle` runs the six initial pthread
APIs against archive-only links. The suite measures compiler TLS and
errno isolation, guarded stacks, lifecycle claims, detached cleanup,
initial-thread exit, and allocator and stream stress. Glibc and musl
comparisons, backend observations, and generated stub controls are
recorded separately. `phase8-openposix` compiles six selected cases
unmodified from the pinned LTP release and runs the resulting archive-only
programs on the same backends. `phase8-detectors` calibrates Helgrind
and DRD on the real private futex lock with test-only annotations,
a deliberate unprotected race, and a Helgrind lock-order control.
Full detector stress and broader POSIX coverage remain separate.
[Thread lifecycle contract](../adr/0010-thread-lifecycle-locks.md)

## Phase 4 streams and utilities

```sh
./tools/container make apps
./tools/container make phase4
```

The freestanding gate checks byte streams, integer formatted input and
output, varargs across the register and stack boundary, and stream flushing
at exit. The fault cases inject short transfers, `EINTR`, and I/O errors at
the private syscall boundary. Selected cases run against pinned glibc and
musl, and the pinned libc-test regressions exercise the shipped stdio
symbols.

The utility cases use the static binaries from `make apps` after checking
their reproducibility and matching them to the separately audited test
links. `cat` is checked byte for byte. The `wc` cases compare line, word, and
byte counts against fixed inputs and check file and error handling.

The gate requires an independent rejection of the generated stub for each
Phase 4 public function. It writes `build/evidence/phase4.json`.
[Stdio and utility oracles](../../tests/phase4/README.md)

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
the host thread-local errno accessor. Their gate also requires fresh
per-function evidence for Open Assembly's accessor from a freestanding link.

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

### Runtime errno accessor

```sh
./tools/container make gate FUNC=__errno_location
```

The per-function gate calls the actual accessor from freestanding programs
linked with the runtime archive. The independent context fixture installs
two synthetic FS bases and checks that each returns its own writable errno
cell, that a write to one leaves the other intact, and that the original
thread state is restored. Its native ABI probe checks the saved CPU state.
A separate glibc program checks the common pointer and value contract.

QEMU confirms execution of the candidate instructions. There are no
conditional edges in the accessor. The oracle rejects the generated stub,
both one-byte TCB offset changes, and omission of the TCB self pointer.
This accessor has no argument-driven control flow, so the independent
context model covers its varying state. The upstream libc-test snapshot
has no case for this runtime-specific ABI entry.

The report is `build/evidence/__errno_location.production.json`. The
queue uses this scope for the accessor. The rest of Phase 1 and the
allocator and environment remain covered by their milestone gates.

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

Full per-function production gates append local attempt records.
Three attributable candidate failures suspend a function and require
its investigation note. Harness failures and existing fixture reports
do not count. [Local production attempts](production-attempts.md)

Run `./tools/container make verify-math-wrappers` for `exp2f`, `log2f`,
`exp2`, and `log2`. The wrapper reports bind reproducible archive and
probe bytes, direct scalar SysV state checks, MPFR-directed cases,
QEMU entry and conditional-edge coverage, typed stub and mutation
controls, and at least 60 seconds of seeded MPFR packets per function.
The hosted glibc and musl observations use the same named shared-domain
cases. The reports keep the separate shared math engine coverage and
mutation proof pending. The full `make gate FUNC=...` requires that
proof before it can qualify a function.

Run `./tools/container make verify-allocator-wrappers` to check the
six public allocator entries. The scoped reports include independent
SysV, allocation and release observations, source-mapped QEMU coverage,
typed stubs, mutation, and at least 60 seconds of shared glibc and musl
packets per entry. Mutation substitutes only the fixture's direct calls
so startup uses the archive allocator. Reports retain the exact raw
mutation results and the reviewed equivalent alignment boundaries. The
shared heap engine and its dependent routines remain pending for full
per-function production verification.

Run `./tools/container make verify-stream-indicators` for the scoped
`feof`, `ferror`, `clearerr`, and `fileno` checks. The independent
fixtures use public `fopen` and standard streams, covering indicators,
buffered data and position, and recursive ownership. Reports bind
the scalar SysV checks, native/QEMU/Memcheck observations, typed stub
and mutation controls, and at least 60 seconds of glibc and musl
packet comparisons per entry. The raw `fileno` trace keeps both
conditional outcomes and the observed count. The gate separately
records the descriptorless outcome as unreachable in the reviewed
public domain while its source fingerprint matches. Changed domain
inputs return the outcome to pending. [Descriptor domain review](fileno-descriptor-domain.md)
Full per-function production verification also requires separate
proof for the shared ownership helpers.

Run `./tools/container make production-open production-paths` for `open`,
`openat`, `readlink`, `unlink`, and `rmdir`. Run `./tools/container make
production-wait production-exec` for `waitpid`, `wait`, `execve`, and
`execv`. Each child report binds its source and compiled object and
includes at least 60 seconds of shared candidate, glibc, and musl packets.
The `wait` and `execv` proofs also bind the fresh report for their
public dependency and the same reproducible runtime archive.

The adjacent `verify-getcwd-wrapper` and `verify-execvp-wrapper` targets
run the public checks and independent allocation-failure cases. Their
reports retain pending allocator or search-engine dependencies.

## Nightly and tagged verification

```sh
./tools/verify-tier nightly
./tools/verify-tier release --tag v1.0.0
```

The nightly entry point runs the available matrix, including Phase 2
production mutation and 300-second libFuzzer observations, the eight
scalar arithmetic production gates with the same libFuzzer floor, the
Linux descriptor, process identity, pipe, pathname, wait, and exec gates
with timed glibc and musl packet comparisons, exact binary32 rounding
groups, selected transcendental shards, the
pinned application and upstream suites, and independent address-family
selection. The isolated memcpy, allocator, and warmed vDSO time benchmarks
measure the named workloads against musl. The extension smoke control
runs in a separate clone.
Its unimplemented, scoped, and production-required reports are archived
with the main evidence. The separate shipped extension check runs declared
packages in dependency order and validates each fresh per-function production
report. A missing independent plan or unmet package dependency keeps that
scope pending. The host wrapper first starts the separate
QEMU-system image for the pinned old-kernel boot check. The tier validates
that report against the current inputs. It requires all 13 paired native
and guest case results and their exact guest manifest. The nine installed
seccomp filter observations have a separate exact scope. The musl authorship scan
checks the relocated-copy and distinct NASM controls and archives its
hash-linked review queue. Entries in that queue are similarity signals
for human review.

The release tier additionally validates the checked-out tag and compares
two independently built and audited sets of runtime, PIE startup and
application artifacts. Its JSON evidence includes fresh per-function
coverage, mutation summaries, the outstanding inventory, and the declared
deviations. Both workflows upload evidence even when verification fails.

Both tiers replay the scoped allocator wrapper and stream indicator batches.
Each batch validates every fresh child report and its timed packet comparisons
against the current inputs. The reports retain the pending shared heap and
stream ownership dependencies.

The binary32 campaign check independently audits checkpoint files under
`build/phase7-campaign` by default. Use `--campaign-root build/...` for a
different current ledger directory. Keep each exported ledger at its
recorded checkout-relative path. The check binds the current complete
Phase 7 source snapshot, candidate archive and probe, oracle artifacts,
and checkpoint-set digest. It counts only complete contiguous coverage
of all 2^32 encodings with no failed observations for an operation and
rounding mode. Fixed-second-operand campaigns count as binary axes.
The report lists missing unary modes and remaining binary axes. Earlier
source snapshots are recorded separately as historical. The source gate
binds the complete Phase 7 input snapshot, so an unrelated changed input
also prevents current credit for an older ledger.

The nightly and release workflows currently call the tier without staging
external ledgers. That leaves the campaign check pending unless the exact
current ledgers are available at the default path. A run that stages them
at a different recorded path can supply it explicitly.

```sh
./tools/verify-tier nightly --campaign-root build/current-campaigns
./tools/verify-tier release --tag v1.0.0 --campaign-root build/current-campaigns
```

Every listed gate must produce a fresh passing report with matching input
hashes. Use repeated `--only` selections for focused diagnosis. Such a run
exits nonzero with a partial report. A tier with any failure or unmet
requirement exits nonzero and cannot qualify a release. The platform
section records the actual native kernel and seccomp mode separately
from the scoped platform gate results.

This plan builds a real libc: ISO C17 plus the POSIX subset applications need, written entirely in hand-authored assembly, with a pipeline that keeps accepting new modules. It reverses three points of my last plan: a true libc needs `errno`, `printf`, variadics, floats and 32-bit `int` returns, so the "skip those" rules now apply only to the extension layer.

I haven't seen your current repo, so the restructure is a target layout plus a migration rule.

## Confirm before Codex starts

1. **Where "zero C" stops.** I assumed: no C in anything shipped (library, runtime, applications). C exists only as test code under `tests/`, and as generated headers so those tests can call the library. Without this, the best oracles (glibc, musl, their test suites, real C programs) are unusable.
2. **Scale.** C17 has roughly 500 library functions by my count, nearly half in `math.h` and `complex.h`. With POSIX, my estimate is 200,000–400,000 lines of assembly and thousands of agent sessions. Treat that as a guess; Phase 3 is the checkpoint for measuring the real rate.

## 1. Locked decisions

These are cheap now and mean rewriting hundreds of files if changed later.

| Area | Decision |
|---|---|
| Target | x86-64 Linux, System V ABI, NASM, static non-PIE ELF, baseline SSE2 only |
| Standard | ISO C17 hosted library; a named POSIX subset; C23 additions later as a package |
| `errno` | Thread-local from day one, reached through `__errno_location` |
| Thread block | glibc-compatible layout: `fs:0` self pointer, `fs:0x28` stack canary seeded from `AT_RANDOM` |
| Locks | Every stdio and malloc entry calls lock hooks from day one; they are no-ops until the first thread exists |
| Kernel boundary | One private syscall layer translates kernel structs and negative returns; public functions never issue `syscall` directly |
| Linking | One public function per file and section, linked with `--gc-sections` |
| Namespaces | Standard names for libc, `__al_*` for internals, package prefixes for extensions |
| Open behaviour | Follow musl where the standard leaves a choice; record every divergence in `spec/deviations.toml` |
| Licence | Permissive (MIT or similar); no translating glibc source; algorithms only from an allowlist (musl, fdlibm, Ryu, CORE-MATH, ARM optimized-routines), recorded per file |
| Authorship | No compiler output committed, enforced in CI (see section 5) |

## 2. Three layers

1. **Runtime:** `_start`, auxv parsing, TLS setup, the syscall layer, signal-return trampoline, panic and crash reporter.
2. **libc:** exact C semantics and ABI, so existing C tests and programs can exercise it.
3. **Extension packages (`ext/`):** the assembly-first API from my earlier plan (negative-errno returns, arenas, length-carrying strings, vector, map, JSON, HTTP). Applications may call either layer.

## 3. Repository layout

```text
AGENTS.md                 rules Codex reads every session
spec/
  functions/<header>/<name>.toml   one file per function
  types/                  struct layouts, constants, syscall numbers
  deviations.toml         implementation-defined choices
  inventory.toml          every C17/POSIX item: function, macro, type
src/x86_64-linux/
  rt/  internal/  string/  stdlib/  stdio/  math/  thread/  posix/ ...
ext/<package>/            same spec/test pipeline as libc
apps/                     pure-assembly applications
include/asm/              generated .inc (shipped)
build/include/c/          generated .h (tests only, never committed)
tests/
  external/               pinned third-party suites   [protected]
  oracle/                 vectors and reference models [protected]
  unit/  fuzz/  abi/  apps/  seeded-bugs/
tools/                    gen, lint, queue, stubcheck, mutate, coverage, provenance
docs/adr/  docs/cookbook/  docs/blocked/
.github/workflows/
```

**Migration rule:** move existing code to `legacy/`. Nothing re-enters `src/` except through the full gate.

## 4. The spec is the source of truth

Each function has one spec file. Generators produce the `.inc` files, the test headers, the API index, and the comment header of the `.asm` file; the linter fails if they disagree.

```toml
name       = "strtol"
header     = "stdlib.h"
prototype  = "long strtol(const char *restrict s, char **restrict end, int base)"
standard   = ["C17 7.22.1.4"]        # cite sections, never paste text
deps       = ["isspace"]
errno      = ["ERANGE", "EINVAL"]
mt_safe    = true
as_safe    = false
oracles    = ["diff:glibc", "diff:musl", "suite:libc-test/strtol"]
provenance = "original"
```

Status (`todo`, `implemented`, `verified`, `blocked`) is computed by CI from evidence. The agent never writes it.

## 5. Verification

Codex writes both code and tests, so correctness has to come from somewhere else.

| Layer | Mechanism | Catches |
|---|---|---|
| Static checker | The rules from my last plan, plus the rules in the next table | ABI bugs before running |
| ABI trampoline | Calls each function with sentinel values in callee-saved registers; checks them, `rsp`, DF and MXCSR on return | Violations the checker can't prove |
| Guard pages | Test buffers end at a `PROT_NONE` page | One-byte over-reads in `strlen`-style code |
| Differential tests | Same inputs to glibc, musl and ours; compare return value, buffers, `errno` | Semantic errors |
| External suites | musl libc-test, Open POSIX Test Suite and LTP subsets, gnulib tests | Conformance gaps |
| Numeric oracles | MPFR for libm, with every 32-bit `float` input tested exhaustively; Paxson and Gay vectors and `parse-number-fxx-test-data` for conversions | Rounding errors |
| Fuzzing | AFL++ or libFuzzer on the differential harness | Parser and formatter edge cases |
| Fault injection | Forced short reads/writes, `EINTR`, allocation failure | Error paths that never fire naturally |
| Real programs | Lua, zlib, SQLite and busybox built against the library | Integration failures |
| Memory and threads | Valgrind memcheck, Helgrind, DRD | Heap misuse and races; compiler sanitizers can't see assembly |

The checker rules added for the libc layer:

| Rule | Bug it catches |
|---|---|
| Narrow arguments are sign- or zero-extended before use | Garbage in the upper bits of `int` and `char` arguments |
| `al` is set before every variadic call | Corrupted floating-point varargs |
| `rcx` and `r11` are treated as clobbered by `syscall`, and argument 4 goes in `r10` | Wrong syscall arguments |
| DF is clear at every call and return | Silent corruption after a backward `rep` |
| The x87 stack is empty at calls | x87 stack overflow |
| Every file has a `.note.GNU-stack` section | An executable stack |
| Unanalyzable control flow is reported as a failure | Unchecked code being counted as checked |

**Rules that stop self-grading** (all CI-enforced):

1. Every expected value names its oracle; CI rejects tests without one.
2. `tests/external/` and `tests/oracle/` are protected paths. The implementing agent can add tests but cannot delete them or reduce assertion counts.
3. Each new test must first fail against an auto-generated stub.
4. Mutation testing flips branch conditions, signedness and ±1 constants in the assembly; at least 90% of mutants must be killed per function.
5. Branch coverage comes from DynamoRIO `drcov` or a QEMU plugin mapped to source lines.
6. Tests for a function are written by a separate session that sees the spec but not the implementation.
7. C tests build with `-ffreestanding -fno-builtin`, and CI confirms with `nm` that the test actually calls our symbol; otherwise the compiler folds `strlen("abc")` and the test proves nothing.
8. Lint waivers and skipped tests each need a reason and are counted on the dashboard.

**Enforcing hand-authorship:**

- CI fails on any `.c` file under `src/` or `ext/`.
- CI fails on compiler producer strings in objects.
- CI fails on code hidden in data blobs.
- The mandatory spec-generated headers and register maps make raw `gcc -S` output fail the linter.
- A nightly scan compares each function against compiler output for the musl equivalent and flags near-matches for review.

## 6. The per-function loop

1. `tools/queue next` returns a function whose dependencies are all verified.
2. Complete the spec.
3. The test session writes oracle-backed tests; `tools/stubcheck` proves they fail.
4. Implement a simple scalar version first.
5. `make gate FUNC=name` runs assemble, lint, ABI trampoline, unit and differential tests, 60 seconds of fuzzing, coverage and mutation.
6. Open a pull request with the generated evidence bundle.
7. After three failed gate runs, write `docs/blocked/name.md` and take the next item, so one hard function cannot stall the queue.

One file per function and one spec per function mean parallel sessions rarely conflict. Changes to `src/x86_64-linux/internal/` or the shared macros require a full regression run and human approval.

## 7. CI tiers

Codex's sandbox may lack network, ptrace or KVM, so the local gate uses only unprivileged tools.

| Tier | Runs | Contents |
|---|---|---|
| Local gate | Every agent iteration | Everything in step 5 above, for touched functions |
| Pull request | Every PR | Full build, checker on all objects, provenance, ELF audit (no interpreter, no executable stack, no undefined symbols), layout asserts against kernel headers, libc-test subset, Valgrind |
| Nightly | Scheduled | Full mutation, long fuzzing, external suites, MPFR campaigns, real programs, QEMU, old and current kernels, seccomp-restricted containers, benchmarks against musl |
| Release | Tagged | Reproducible build, full matrix, published coverage and deviation report |

The toolchain is pinned in one container image used by both Codex and CI.

## 8. Roadmap

Each phase ends when its gate passes, not when its functions exist.

| Phase | Contents | Exit gate |
|---|---|---|
| 0 | Spec schema, inventory, generators, checker, harnesses, CI, `AGENTS.md` | A corpus of about 30 seeded-bug files is all rejected; a deliberately wrong `strlen` fails the gate |
| 1 | Runtime, TLS, `errno`, syscall layer, `exit`/`atexit`, `__stack_chk_fail` | Assembly and compiler-built hello worlds run under Valgrind and QEMU |
| 2 | `string.h`, `ctype.h`, integer conversion, `qsort`, `bsearch` | Differential and libc-test subsets pass |
| 3 | `malloc` family (size classes over `mmap`), environment | Allocator fuzzing passes; **go/no-go checkpoint on cost and first-pass rate** |
| 4 | Variadic support, stdio, integer `printf`/`scanf` | libc-test stdio subset; first assembly utilities (`cat`, `wc`) |
| 5 | Bignum module, `strtod`, float `printf`/`scanf`, `fenv.h` | Published conversion vectors and differential fuzzing pass |
| 6 | Files, directories, processes, `posix_spawn`, signals, `setjmp`, `time.h` | Busybox applet subset runs |
| 7 | `math.h` for `double` and `float`, then `long double`, then `complex.h` | MPFR report within per-function ulp targets; Lua test suite passes |
| 8 | pthreads, C11 threads, atomics helpers, live locks | Helgrind and DRD stress, POSIX thread subset |
| 9 | `wchar.h`, `uchar.h`, UTF-8, `C` and `C.UTF-8` locales | Differential and libc-test pass |
| 10 | Sockets, `poll`/`epoll`, resolver, regex, glob, termios | SQLite tests pass; an assembly epoll HTTP server survives fuzzing |
| 11 | CPU-dispatched fast paths, allocator v2, static-PIE, vDSO | Benchmarks within a set margin of musl |

Start a numerics design track during Phase 2. Float conversion and libm are the highest-risk work and should not become an unestimated tail.

<details>
<summary>Known hard spots to write design notes for first</summary>

- **Variadics:** `va_list` is a 24-byte struct with a register save area; `long double` arguments always come from the stack.
- **Float conversion:** Eisel–Lemire fast path with an exact bignum fallback for parsing; Ryu or a musl-style big-decimal method for printing; 80-bit `long double` needs its own path.
- **Signals:** `rt_sigaction` needs `SA_RESTORER` and a trampoline; the kernel signal set is 8 bytes, the public one is larger.
- **Threads:** the `clone` child path cannot return normally; a detached thread must unmap its own stack and exit without touching it; cancellation shapes the syscall layer.
- **stdio:** specify the stream state machine (read/write switching, pushback, flush at exit) before coding.
- **`qsort`:** must stay in bounds even with an inconsistent comparator.
- **New syscalls:** `statx`, `clone3` and similar can fail under seccomp, so each needs a fallback.
- **`fork` with threads:** locks and allocator state need explicit reset.
- **Time zones:** static linking still depends on TZif files at runtime.

</details>

## 9. Extending indefinitely

- A package is a directory under `ext/` with the same spec, tests, gate and evidence. `tools/new-package` and `tools/new-function` scaffold it.
- Extension APIs have no glibc to diff against. Each package must therefore ship an executable reference model in Python or name an independent oracle (for example, JSONTestSuite and Python's `json` for a JSON package).
- Packages declare dependencies and a stability level. Stable packages freeze struct layouts, since static linking has no symbol versioning.
- The generated API index, one line per function, is what an application-writing agent loads, never library source.
- The spec, tests and oracles are architecture-neutral. A second architecture is a new `src/<arch>/` tree run through the same gates.

## 10. Deferred or out of scope

| Item | Status |
|---|---|
| Dynamic linking, `dlopen`, NSS modules | Out of scope; a separate project |
| Annex K, decimal floating point, glibc-only extensions | Out of scope |
| Locales beyond `C` and `C.UTF-8`, wide `iconv` coverage | Deferred until an application needs them |
| Correctly rounded libm | Deferred; initial target about 1 ulp |
| CET shadow stacks | Deferred as a dedicated phase, because `longjmp` and signal return must change |
| Unwind tables | Deferred; NASM cannot emit them, so non-leaf functions keep `rbp` frames for backtraces |

<details>
<summary><code>AGENTS.md</code> skeleton</summary>

```markdown
# Non-negotiable rules (CI enforces each)
1. Shipped code is hand-written NASM only. Never commit compiler output.
2. Every public function has a spec file; the .asm header is generated from it.
3. Never edit tests/external/ or tests/oracle/. Never reduce assertion counts.
4. Expected values must name an oracle.
5. A new test must fail against the stub before the implementation lands.
6. No code from glibc or any GPL/LGPL source. Record algorithm sources in the spec.
7. Public functions follow System V exactly. Never issue `syscall` outside internal/.
8. Three failed gate runs: write docs/blocked/<name>.md, then take the next item.
9. Changes to internal/ or shared macros need full regression and human approval.

# Loop
tools/queue next -> complete spec -> tests (separate session) -> tools/stubcheck
-> implement -> make gate FUNC=<name> -> open PR with evidence

# Quick reference
- Entry: rsp = 8 mod 16. Every call: rsp = 0 mod 16.
- Extend narrow arguments yourself; upper bits are garbage.
- Variadic calls: set al to the number of vector registers used.
- syscall: args rdi rsi rdx r10 r8 r9; clobbers rcx, r11; error if rax in [-4095, -1].
- Writing al or ax does not clear the rest of rax.
- Leave DF clear; preserve MXCSR and the x87 control word.
```

</details>

## First three tasks for Codex

1. Build Phase 0 only, and stop when the seeded-bug corpus is fully rejected.
2. Build Phase 1, and stop when both hello worlds pass the ELF audit.
3. Open the queue for Phase 2, about 120 pure functions, and use it to tune the mutation threshold and the three-attempt limit before any stateful subsystem starts.
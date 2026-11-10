# Phase 0 test oracles

The test author used the function specification and the repository's ABI and
Phase 0 contracts. The checker, gate, and candidate fixture sources were
separate assignments. The assertions apply to test fixtures for
`strlen`, whose C17 contract counts the bytes preceding the first zero.

| Test | Oracle | Coverage |
| --- | --- | --- |
| Static checker corpus | The x86-64 Linux System V ABI and repository policy | `tests/seeded-bugs/manifest.toml` identifies the expected rule for each defect. Each source assembles with NASM. A seed must fail with the intended diagnostic first. Positive controls must pass the same checker. A separate public CLI case uses the generated header and checks rejection of a call without a known signature. |
| Unit | `reference:byte-count` | Protected literal vectors give the exact length for empty strings, embedded zeros, control bytes, high-bit bytes, and selected length boundaries. |
| ABI | `abi:sysv-amd64` | An assembly trampoline passes the input with aligned RSP and clear DF. It checks RSP, RBX, RBP, R12–R15, DF, MXCSR control bits, the x87 control word, and an empty x87 stack after the call. |
| Guard pages | `reference:page-protection` and `reference:byte-count` | Valid strings start just after an inaccessible page or end just before one. The data page is read-only during each call. A returned count mismatch or a protection fault during the call fails the test. |
| Differential | `diff:glibc` and `reference:byte-count` | A separate glibc executable computes the length from the same input bytes. A directed sweep covers 64 offsets, boundary lengths, and all 256 byte values. The test also checks glibc against the constructed first-zero position. |
| Fuzz | `diff:glibc` and `reference:byte-count` | A reproducible generator varies byte values, alignment, length, and first-zero position. Each run exercises at least 2,048 inputs from seed `0x41534d30`. The requested duration can extend that sequence. |

Run the entire milestone through `./tools/container make phase0`. To run the
checker corpus on its own, use the following command.

```sh
./tools/container python3 tests/tooling/test_lint.py --json build/evidence/seeded.json
```

The runtime harness uses the pinned glibc toolchain. The candidate assembly
is assembled under its public symbol, then renamed at the object level to
`__al_test_strlen` for the test link. This isolates host C runtime calls
from the fixture. The C and assembly harness objects have real undefined
references to `__al_test_strlen`, which resolve to the candidate object.
The separately linked oracle object has a real undefined reference to host
`strlen`. All C test objects use `-ffreestanding -fno-builtin`.

With the linked checks and glibc oracle from the gate, run
`checks unit`, `checks abi`, `checks guard`,
`checks differential /path/to/glibc-oracle`, or
`checks fuzz /path/to/glibc-oracle [SECONDS]`.
A duration of zero runs the fixed fuzz prefix. Successful checks print
`PASS` and exit 0. Oracle mismatches or ABI failures print `FAIL` and exit
1. Harness or oracle-process errors print `ERROR` and exit 2.
ABI mode assesses the calling convention independently of the returned
length, so the wrong fixture and generated stub can pass ABI while the
semantic tests reject them.

Run ABI mode natively. The passing fixture returned zero with
`/path/to/checks abi`. Running
`valgrind --quiet --error-exitcode=99 /path/to/checks abi` in the pinned image
returned one and reported MXCSR and x87 control differences (`0x300`).

The probe controls inject corruption of all eleven ABI checks, reads across
each protected boundary, and a write to the read-only page. They assert the
expected diagnostics and failure status. Run them with the pinned toolchain.

```sh
./tools/container python3 tests/tooling/test_probes.py --json build/evidence/probes.json
```

Guard pages detect accesses that cross a protected boundary and writes to
the read-only page. Reads beyond the first zero within the mapped page are
outside the resolution of these probes. The deterministic fuzz run covers
the declared input generator. Separate musl and third-party suite runs,
coverage instrumentation, and longer feedback-guided fuzz campaigns are
later milestones.

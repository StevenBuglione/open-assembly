"""Verify selected runtime functions using independent manifest cases."""

import argparse
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from functools import partial
from hashlib import sha256
from itertools import chain
import json
import os
from pathlib import Path
import random
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time

from branch_coverage import verify_coverage
from gate import (BUILD, COMPILE_FLAGS, EVIDENCE, LINK_FLAGS, CandidateFailure, GateError, checked,
                  finish_function_gate, identify_tools, nm_symbols, verify_setup, write_evidence)
from phase1 import NASM, build_case, build_runtime, load_manifest as load_phase1_manifest
from phase4 import Probe, load_probes, observation, parse_probe
from phase6 import (ABI_FIXTURES, COMPAT as COMPAT_PUBLIC, COMPAT_FAULT_WRAPPERS, PATH_EXEC,
                    PROCESS as PROCESS_PUBLIC, PUBLIC as FILE_PUBLIC, SUITE as FILE_SUITE, run_cases, run_stubs)
from production import CANDIDATE_ROOT, applicable_variants, phase2_inputs, result_type, source_paths
from spec import ROOT, load_project, regular_file, sha256_file, snapshot_inputs


@dataclass(frozen=True)
class Plan:
    suite: Path
    public: frozenset
    assembly: tuple
    abi: str
    trace: str
    mutations: tuple
    fuzz: str
    record_sizes: tuple
    contracts: tuple
    fault_wrappers: tuple = ()
    phase1_cases: tuple = ()
    private_engine: str = ""
    semantic_mutants: tuple = ()
    supplement: Path | None = None
    wrapper_suffix: str = "allocator-wrapper"
    private_helpers: tuple = ()
    abi_result: bool = False
    required_production: tuple = ()


FCNTL = Path("tests/phase6/fcntl")
IO = Path("tests/phase6/io")
IO_PHASE1_CASES = {"read": ("io-read", "eintr"), "write": ("io-write", "hello-asm"),
                   "close": ("io-close",)}
IO_PHASE1_FAILURES = {"read": (21, 22, 23, 24, 26, 28), "write": (32, 33, 34, 38),
                      "close": (41, 42, 43, 44)}
IO_POSITIONAL = frozenset({"pread", "pwrite"})
IO_FUNCTIONS = frozenset(IO_PHASE1_CASES) | IO_POSITIONAL
IO_MUTATIONS = {name: ((f"io-{name}", codes),) for name, codes in IO_PHASE1_FAILURES.items()}
IO_MUTATIONS.update(pread=(("io-pread", (11, 12, 13, 14)),),
                    pwrite=(("io-pwrite", (11, 12, 13, 14, 15)),
                            ("io-pwrite-coverage", (*range(11, 19), 21, 22, 23, 24))))
FILE_MUTATION_FAILURES = {"lseek": (62, 63, 65, 67), "dup": (72, 73, 74), "dup2": (82, 83, 84, 85)}
PROCESS_IDENTITY = Path("tests/phase6/process_identity")
PROCESS_IDENTITY_FAILURES = {"getpid": (11,), "getppid": (21,)}
GETPID_SYSCALL = "    mov edi, 39                  ; __NR_getpid\n"
GETPPID_SYSCALL = "    mov edi, 110                 ; __NR_getppid\n"
PROCESS_IDENTITY_MUTANTS = {
    "getpid": (("swap-process-identity-syscall", GETPID_SYSCALL, GETPPID_SYSCALL),),
    "getppid": (("swap-process-identity-syscall", GETPPID_SYSCALL, GETPID_SYSCALL),),
}
PROCESS_IDENTITY_RECORD = (16, 72)
PROCESS_NORMALIZED_BYTES = 64
PIPE_IDENTITY = Path("tests/phase6/pipe_identity")
PIPE_RECORD = (16, 64)
NULL_PIPE_OUTPUT = ("null-pipe-output", "    mov rsi, rdi", "    xor esi, esi")
DROP_PIPE2_FLAGS = ("drop-pipe2-flags", "    movsxd rdx, esi\n", "    xor edx, edx\n")
OPEN_IDENTITY = Path("tests/phase6/open_identity")
OPEN_FAILURES = {"open": tuple(range(12, 23)), "openat": tuple(range(33, 41))}
OPEN_SEMANTIC_MUTANTS = {
    "open": (("discard-open-mode", "    mov r8d, edx", "    xor r8d, r8d"),),
    "openat": (("discard-openat-mode", "    mov r8d, ecx", "    xor r8d, r8d"),
               ("ignore-openat-dirfd", "    mov rsi, rdi", "    mov rsi, -100")),
}
PATH_IDENTITY = Path("tests/phase6/path_identity")
PATH_MUTATIONS = {
    "getcwd": (("path-getcwd-fault", tuple(range(21, 29))), ("compat-getcwd", (31, 32, 33, 34))),
    "readlink": (("compat-readlink", (61, 62, 63)),),
    "unlink": (("file-unlink", (132, 133, 134)),),
    "rmdir": (("file-rmdir", (123, 125, 126)),),
}
UNLINK_SYSCALL = "    mov edi, 87                    ; __NR_unlink\n"
RMDIR_SYSCALL = "    mov edi, 84                    ; __NR_rmdir\n"
PATH_SEMANTIC_MUTANTS = {
    "readlink": (("drop-readlink-capacity", "    mov rcx, rdx", "    xor ecx, ecx"),),
    "unlink": (("swap-unlink-for-rmdir", UNLINK_SYSCALL, RMDIR_SYSCALL),),
    "rmdir": (("swap-rmdir-for-unlink", RMDIR_SYSCALL, UNLINK_SYSCALL),),
}
PATH_FAULT_WRAPPERS = (*COMPAT_FAULT_WRAPPERS.items(), (FILE_SUITE / "fault.c", ("__al_syscall",)),
                       (PATH_IDENTITY / "getcwd_fault.c", ("malloc", "free", "__al_syscall")))
WAIT_STATUS = Path("tests/phase6/wait_status")
WAIT_MUTATIONS = {
    "waitpid": (("process-waitpid", (51, 52, 54, 56, 57)),),
    "wait": (("process-wait", (62, 64, 65)), ("process-wait-two-children", (21, 22, 23))),
}
WAIT_SEMANTIC_MUTANTS = {
    "waitpid": (("drop-waitpid-status", "    mov rdx, rsi\n", "    xor edx, edx\n"),
                ("replace-waitpid-options", "    movsxd rcx, edx\n", "    mov ecx, 0x02000000\n")),
    "wait": (("drop-wait-status", "    mov rsi, rdi\n", "    xor esi, esi\n"),
             ("restrict-wait-to-own-group", "    mov edi, -1\n", "    xor edi, edi\n")),
}
EXEC_IDENTITY = Path("tests/phase6/exec_identity")
EXEC_MUTATIONS = {
    "execve": (("process-exec-failure", (82, 84, 85)),),
    "execv": (("path-execv-missing", (41, 42)),),
    "execvp": (("path-execvp-denied", (53, 54)), ("path-execvp-fallback", (61, 62))),
}
EXEC_SEMANTIC_MUTANTS = {
    "execve": (("hide-returned-execve-error", "    mov rdi, rax\n", "    xor edi, edi\n"),),
    "execv": (("discard-execv-path", "    call execve\n", "    xor edi, edi\n    call execve\n"),),
    "execvp": (("omit-execvp-shell-fallback", "    mov r9d, 1                    ; execvp interprets ENOEXEC via the shell\n",
                "    xor r9d, r9d\n"),),
}
EXECVP_FAULT = ((EXEC_IDENTITY / "allocation_fault.c", ("malloc", "free")),)
EXECVP_HELPERS = ("__al_exec_path_env", "__al_heap", "getenv", "malloc", "free")
FILE_CONTRACTS = (Path("docs/adr/0007-linux-files-process-signal-time.md"),
                  Path("docs/cookbook/linux-file-verification.md"))
ALLOCATOR = Path("tests/allocator-production")
ALLOCATOR_NAMES = {name: name.replace("_", "-") for name in
                   ("malloc", "calloc", "free", "realloc", "aligned_alloc", "posix_memalign")}
ALLOCATOR_FUNCTIONS = frozenset(ALLOCATOR_NAMES)
ALLOCATOR_CONTRACTS = (Path("docs/adr/0004-allocator-environment.md"),
                       Path("docs/adr/0036-direct-allocation-remap.md"))
ALLOCATOR_MUTATIONS = {
    "malloc": (("heap-malloc-fault", (31, 32)), ("heap-malloc-unit", tuple(range(11, 18)))),
    "calloc": (("heap-calloc-fault", (31, 32)), ("heap-calloc-unit", tuple(range(11, 18)))),
    "free": (("heap-free-release", (31, 32)), ("heap-free-unit", tuple(range(11, 16)))),
    "realloc": (("heap-realloc-fault", (31, 32, 33)), ("heap-realloc-unit", tuple(range(11, 20)))),
    "aligned_alloc": (("heap-aligned-alloc-fault", (31, 32, 33)), ("heap-aligned-alloc-unit", tuple(range(11, 19)))),
    "posix_memalign": (("heap-posix-memalign-fault", (31, 32, 33)), ("heap-posix-memalign-unit", tuple(range(11, 19)))),
}
ALLOCATOR_SEMANTIC_MUTANTS = {
    "calloc": (("omit-calloc-zeroing", "    mov ecx, 3                    ; allocate and zero\n",
                "    xor ecx, ecx\n"),),
    "free": (("drop-free-pointer", "    call __al_heap\n", "    xor edi, edi\n    call __al_heap\n"),
             ("wrong-free-operation", "    mov ecx, 1                    ; free\n", "    xor ecx, ecx\n")),
    "realloc": (("discard-old-allocation", "    call __al_heap\n", "    xor edi, edi\n    call __al_heap\n"),),
    "posix_memalign": (("omit-aligned-output-store", "    mov [rdi], rax\n", "    nop\n"),),
}
STREAM_INDICATORS = Path("tests/stream-indicators")
STREAM_FAILURES = {"feof": (11, 18), "ferror": (11, 19), "clearerr": (11, 16), "fileno": (11, 17)}
STREAM_CONTRACTS = (Path("docs/adr/0005-stdio-varargs.md"), Path("docs/adr/0021-wide-stream-orientation.md"))
STREAM_SEMANTIC_MUTANTS = {
    "feof": (("read-error-indicator", "    and r12d, 16\n", "    and r12d, 32\n"),),
    "ferror": (("read-eof-indicator", "    and r12d, 32\n", "    and r12d, 16\n"),),
    "clearerr": (("leave-eof-indicator", "    and qword [rbx + 8], -49\n", "    and qword [rbx + 8], -33\n"),
                 ("leave-error-indicator", "    and qword [rbx + 8], -49\n", "    and qword [rbx + 8], -17\n")),
}
STREAM_WRAPPER_SUFFIX = "stream-indicator-wrapper"
FILENO_DESCRIPTORLESS = {
    "line": 38, "instruction": "js", "branch": "taken",
    "source_sha256": "9d00db5d671a11f5f9b76c66df59e749a33b388123b6aa5f4a3114267d41a923",
}
FILENO_REVIEW = Path("docs/cookbook/fileno-descriptor-domain.md")
FILENO_DOMAIN_CONTRACTS = (
    Path("docs/adr/0002-runtime-abi.md"), Path("docs/adr/0010-thread-lifecycle-locks.md"),
    Path("docs/adr/0028-static-pie.md"), Path("docs/adr/0043-threaded-fork.md"), FILENO_REVIEW,
)
FILENO_DOMAIN_FIXED_INPUTS = (
    "Makefile", "tools/gen", "tools/phase1.py", "tools/spec.py",
    *(str(path) for path in (*STREAM_CONTRACTS, *FILENO_DOMAIN_CONTRACTS)),
)
FILENO_DOMAIN_SHA256 = "2826cbb0a797195dfde1165cb2585fba70471254138976105e4d19f3eaa2c3f7"
PLANS = {
    **{name: Plan(FILE_SUITE, frozenset(FILE_PUBLIC), ABI_FIXTURES,
                  "file-abi", f"file-{name}", ((f"file-{name}", codes),),
                  f"file-{name}-fuzz", (16, 24), FILE_CONTRACTS,
                  ((FILE_SUITE / "fault.c", ("__al_syscall",)),))
       for name, codes in FILE_MUTATION_FAILURES.items()},
    **{name: Plan(IO, IO_POSITIONAL, (Path("tests/phase2/abi.asm"),),
                  f"io-{name}-abi", "io-pwrite-coverage" if name == "pwrite" else f"io-{name}",
                  mutations, f"io-{name}-fuzz", (16, 24), FILE_CONTRACTS,
                  ((IO / "pwrite_fault.c", ("__al_syscall",)),), IO_PHASE1_CASES.get(name, ()))
       for name, mutations in IO_MUTATIONS.items()},
    **{name: Plan(ALLOCATOR, ALLOCATOR_FUNCTIONS, (Path("tests/phase2/abi.asm"),),
                  f"heap-{label}-abi", "heap-free-release" if name == "free" else f"heap-{label}-unit",
                  ALLOCATOR_MUTATIONS[name], f"heap-{label}-fuzz", (32, 64), ALLOCATOR_CONTRACTS,
                  ((ALLOCATOR / "fault.c", ("__al_syscall",)),), private_engine="__al_heap",
                  semantic_mutants=ALLOCATOR_SEMANTIC_MUTANTS.get(name, ()))
       for name, label in ALLOCATOR_NAMES.items()},
    **{name: Plan(FILE_SUITE / "process", frozenset(PROCESS_PUBLIC), (Path("tests/phase2/abi.asm"),),
                  f"identity-{name}-abi", f"process-{name}", ((f"process-{name}", codes),),
                  f"identity-{name}-fuzz", PROCESS_IDENTITY_RECORD, FILE_CONTRACTS[:1],
                  semantic_mutants=PROCESS_IDENTITY_MUTANTS[name], supplement=PROCESS_IDENTITY, abi_result=True)
       for name, codes in PROCESS_IDENTITY_FAILURES.items()},
    **{name: Plan(STREAM_INDICATORS, frozenset(STREAM_FAILURES), (Path("tests/phase2/abi.asm"),),
                  f"stream-{name}-abi", f"stream-{name}-unit", ((f"stream-{name}-unit", tuple(range(first, last + 1))),),
                  f"stream-{name}-fuzz", (16, 64),
                  STREAM_CONTRACTS + (FILENO_DOMAIN_CONTRACTS if name == "fileno" else ()),
                  private_engine="__al_stream_lock",
                  semantic_mutants=STREAM_SEMANTIC_MUTANTS.get(name, ()), wrapper_suffix=STREAM_WRAPPER_SUFFIX,
                  private_helpers=("__al_stream_unlock", "__al_stdio_errno") if name == "fileno" else ("__al_stream_unlock",))
       for name, (first, last) in STREAM_FAILURES.items()},
    "pipe": Plan(FILE_SUITE, frozenset(FILE_PUBLIC), ABI_FIXTURES, "file-abi", "file-pipe",
                 (("file-pipe", (92, 93, 94)),), "pipe-fuzz", PIPE_RECORD, FILE_CONTRACTS,
                 ((FILE_SUITE / "fault.c", ("__al_syscall",)),),
                 semantic_mutants=(NULL_PIPE_OUTPUT,), supplement=PIPE_IDENTITY),
    "pipe2": Plan(FILE_SUITE / "process", frozenset(PROCESS_PUBLIC), (Path("tests/phase2/abi.asm"),),
                  "pipe2-typed-abi", "process-pipe2", (("process-pipe2", (41, 42, 43, 44)),),
                  "pipe2-fuzz", PIPE_RECORD, FILE_CONTRACTS[:1],
                  semantic_mutants=(NULL_PIPE_OUTPUT, DROP_PIPE2_FLAGS), supplement=PIPE_IDENTITY, abi_result=True),
    **{name: Plan(FILE_SUITE, frozenset(FILE_PUBLIC), ABI_FIXTURES,
                  f"{name}-variadic-abi", "file-open" if name == "open" else "openat-variadic-abi",
                  ((f"file-{name}", codes), (f"{name}-variadic-abi", tuple(range(11, 17)))),
                  f"{name}-fuzz", (16, 64), FILE_CONTRACTS,
                  ((FILE_SUITE / "fault.c", ("__al_syscall",)),),
                  semantic_mutants=OPEN_SEMANTIC_MUTANTS[name], supplement=OPEN_IDENTITY, abi_result=True)
       for name, codes in OPEN_FAILURES.items()},
    **{name: Plan(FILE_SUITE / "compat" if name in COMPAT_PUBLIC else FILE_SUITE,
                  frozenset(COMPAT_PUBLIC if name in COMPAT_PUBLIC else FILE_PUBLIC), ABI_FIXTURES,
                  f"path-{name}-abi", mutations[0][0], mutations, f"path-{name}-fuzz", (16, 64),
                  FILE_CONTRACTS, PATH_FAULT_WRAPPERS, private_engine="__al_heap" if name == "getcwd" else "",
                  semantic_mutants=PATH_SEMANTIC_MUTANTS.get(name, ()), supplement=PATH_IDENTITY,
                  wrapper_suffix="getcwd-wrapper", private_helpers=("malloc", "free") if name == "getcwd" else (),
                  abi_result=True)
       for name, mutations in PATH_MUTATIONS.items()},
    **{name: Plan(FILE_SUITE / "process", frozenset(PROCESS_PUBLIC), (Path("tests/phase2/abi.asm"),),
                  f"process-{name}-typed-abi", f"process-{name}", mutations, f"process-{name}-fuzz", (16, 64),
                  FILE_CONTRACTS[:1], semantic_mutants=WAIT_SEMANTIC_MUTANTS[name], supplement=WAIT_STATUS,
                  abi_result=True, required_production=("waitpid",) if name == "wait" else ())
       for name, mutations in WAIT_MUTATIONS.items()},
    **{name: Plan(FILE_SUITE / ("process" if name == "execve" else "path"),
                  frozenset(PROCESS_PUBLIC if name == "execve" else PATH_EXEC), (Path("tests/phase2/abi.asm"),),
                  f"process-{name}-typed-abi", "process-execvp-allocation-fault" if name == "execvp" else mutations[0][0],
                  mutations, f"process-{name}-fuzz", (16, 64), FILE_CONTRACTS[:1], EXECVP_FAULT,
                  private_engine="__al_exec_search" if name == "execvp" else "",
                  semantic_mutants=EXEC_SEMANTIC_MUTANTS[name], supplement=EXEC_IDENTITY,
                  wrapper_suffix="execvp-wrapper", private_helpers=EXECVP_HELPERS if name == "execvp" else (),
                  abi_result=True, required_production=("execve",) if name == "execv" else ())
       for name, mutations in EXEC_MUTATIONS.items()},
    "fcntl": Plan(
        FCNTL, frozenset({"fcntl"}), (Path("tests/phase2/abi.asm"), FCNTL / "variadic.asm"),
        "fcntl-abi", "fcntl-dispatch",
        (("fcntl-dispatch", tuple(range(10, 59))), ("fcntl-abi", (11, 12)),
         ("fcntl-descriptor", (12, 13, 14, 15, 16)), ("fcntl-pipe-size", (22,)),
         ("fcntl-owner", (62, 63, 64, 65, 66)), ("fcntl-unknown", (51, 52, 53))),
        "fcntl-fuzz", (4, 12), (Path("docs/adr/0007-linux-files-process-signal-time.md"),),
    ),
}
REQUIRED_CHECKS = {
    "generated_outputs", "candidate_build", "runtime_build", "native_oracles", "abi",
    "branch_coverage", "generated_stub", "production_mutation", "differential_fuzz",
}
FUZZ_SECONDS = 60
FUZZ_SEED = 0x5C7D3AA1


def manifest_inputs(function):
    inputs = phase2_inputs()
    inputs.update(snapshot_inputs(ROOT, PLANS[function].contracts))
    return dict(sorted(inputs.items()))


def manifest_dependency_bindings(names):
    bindings = {}
    for name in names:
        relative = EVIDENCE / f"{name}.production.json"
        raw = regular_file(ROOT, relative, "manifest production dependency").read_bytes()
        record = json.loads(raw)
        inputs = manifest_inputs(name)
        if (type(record) is not dict or type(record.get("schema_version")) is not int
                or record["schema_version"] != 1 or record.get("function") != name
                or record.get("scope") != "production-runtime-manifest-function"
                or record.get("outcome") != "pass" or record.get("production_verified") is not True
                or record.get("inputs") != inputs):
            raise ValueError(f"{name}: no exact passing manifest production dependency report")
        checks = record.get("checks")
        if (type(checks) is not dict or not REQUIRED_CHECKS <= checks.keys()
                or any(type(item) is not dict or item.get("outcome") != "pass" for item in checks.values())):
            raise ValueError(f"{name}: incomplete manifest production dependency checks")
        source, = (path for path in inputs if Path(path).is_relative_to(CANDIDATE_ROOT)
                   and Path(path).name == f"{name}.asm")
        candidate = checks["candidate_build"]
        builds = checks["runtime_build"].get("artifacts")
        first = builds.get("first") if type(builds) is dict else None
        archive = first.get("libopenasm.a") if type(first) is dict else None
        object_hash = candidate.get("object_sha256")
        if (candidate.get("source") != source or candidate.get("source_sha256") != inputs[source]
                or any(type(value) is not str or re.fullmatch(r"[0-9a-f]{64}", value) is None
                       for value in (archive, object_hash)) or first != builds.get("second")):
            raise ValueError(f"{name}: manifest production dependency does not bind the source and archive")
        bindings[name] = {"evidence": relative.as_posix(), "evidence_sha256": sha256(raw).hexdigest(),
                          "archive_sha256": archive}
    return {"outcome": "pass", "functions": bindings}


def phase1_probe(case):
    return Probe(case, b"", case.stdout.encode(), case.stderr.encode(), {}, (),
                 "Phase 1 fixture links the Open Assembly runtime directly.")


def load_plan_probes(function, plan, *, required_cases=None):
    parse = partial(parse_probe, suite=plan.suite, programs=(), asm_fixtures=plan.assembly,
                    fault_wrappers=dict(plan.fault_wrappers), allow_fixture_files=True)
    probes, controls = load_probes(plan.suite / "manifest.toml", plan.public, parse)
    selected = {probe.case.name: probe for probe in probes if function in probe.case.requires}
    if plan.supplement is not None and (required_cases is None or required_cases - selected.keys()):
        supplemental, _ = load_probes(plan.supplement / "manifest.toml", plan.public,
                                       partial(parse, suite=plan.supplement), supplement=True)
        additional = {probe.case.name: probe for probe in supplemental if function in probe.case.requires}
        if selected.keys() & additional.keys():
            raise GateError(f"{function}: overlapping original and supplemental cases")
        selected.update(additional)
    if plan.phase1_cases:
        cases, stubs = load_phase1_manifest()
        phase1 = {case.name: phase1_probe(case) for case in cases if function in case.requires}
        case, rejection = stubs[function]
        names = set(plan.phase1_cases)
        if names & selected.keys() or not names <= phase1.keys() or case.name not in names:
            raise GateError(f"{function}: incomplete or overlapping Phase 1 cases")
        selected.update({name: phase1[name] for name in plan.phase1_cases})
        status, stdout, stderr = rejection
        controls[function] = selected[case.name], (status, stdout.encode(), stderr.encode())
    return selected, controls


def candidate_object(path, source, name, original, log, *, debug=False):
    command = (*NASM, "-g", "-F", "dwarf") if debug else NASM
    checked(log, [*command, "-o", path, source])
    checked(log, ["tools/elf-audit", "--assembly-object", path])
    if nm_symbols(log, path, ["-g", "--defined-only"]) != {name: "T"}:
        raise GateError(f"{source}: candidate must define only {name}")
    if nm_symbols(log, path, ["-g", "-u"]) != nm_symbols(log, original, ["-g", "-u"]):
        raise GateError(f"{source}: candidate references differ from the archived object")
    return path


def debug_candidate(name, source, original, directory, log):
    debug = candidate_object(directory / f"{name}.debug.o", source, name, original, log, debug=True)
    text = [checked(log, ["objdump", "-dr", "-j", f".text.{name}", path])
            .partition("Disassembly of section ")[2] for path in (debug, original)]
    if not text[0] or text[0] != text[1]:
        raise GateError("traced candidate differs from the archived function")
    return debug


def trace_function(name, source, original, probe, directory, runtime, record, *, require_complete=True):
    if probe.files or probe.input_bytes or "qemu" not in probe.case.backends:
        raise GateError(f"{probe.case.name}: trace case requires an argument-only QEMU probe")
    directory.mkdir()
    log = record["commands"]
    debug = debug_candidate(name, source, original, directory, log)
    binary, artifacts = build_case(probe.case, directory / "linked", runtime, log,
                                  candidate=(name, debug), link_wraps=probe.wraps)
    record.update(debug_object_sha256=sha256_file(debug), linked_artifacts=artifacts,
                  link_wraps=probe.wraps)
    verify_coverage(record, directory, binary, name, source, [probe.case.args], exact_case=probe.case,
                    require_complete=require_complete, require_entry=True)


def descriptor_domain(inputs):
    # Review the complete source universe, including new paths outside stdio.
    # The gate captures this input map before and after building and running.
    domain = {path: digest for path, digest in inputs.items()
              if path.startswith(("src/", "spec/", "include/asm/", "build/include/c/"))
              or path in FILENO_DOMAIN_FIXED_INPUTS}
    serialized = json.dumps(domain, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return sha256(serialized).hexdigest(), len(domain)


def bind_descriptorless_scope(source, trace, inputs):
    proof = FILENO_DESCRIPTORLESS
    missing = [(edge["line"], edge["instruction"], edge["branch"]) for edge in trace["edges"] if not edge["covered"]]
    if (trace.get("outcome") != "partial" or trace.get("covered") != 1 or trace.get("total") != 2
            or missing != [(proof["line"], proof["instruction"], proof["branch"])]
            or sha256_file(source) != proof["source_sha256"]):
        raise GateError("fileno trace does not match the documented descriptor-backed stream scope")
    fingerprint, count = descriptor_domain(inputs)
    domain = {
        **proof, "outcome": "pending", "review": str(FILENO_REVIEW),
        "review_sha256": inputs[str(FILENO_REVIEW)],
        "domain_sha256": fingerprint, "reviewed_domain_sha256": FILENO_DOMAIN_SHA256,
        "domain_input_count": count,
    }
    if fingerprint == FILENO_DOMAIN_SHA256:
        domain.update(outcome="unreachable_in_reviewed_public_domain",
                      applicable_covered=1, applicable_total=1)
    else:
        domain["reason"] = "The FILE constructor and lifetime source domain changed and requires fresh review."
    trace["descriptorless"] = domain


def expected(probe):
    return probe.case.status, probe.stdout, probe.stderr


def execute_native(probe, binary, directory):
    directory.mkdir()
    for name, contents in probe.files.items():
        (directory / name).write_bytes(contents)
    command = [binary.resolve(), *probe.case.args]
    return observation(command, directory, probe.input_bytes, probe.case.env)


def semantic_variants(source, replacements):
    original = source.read_text(encoding="utf-8")
    for operator, before, after in replacements:
        if original.count(before) != 1:
            raise GateError(f"{source}: {operator} requires one exact source instruction")
        yield operator, original.replace(before, after, 1)


def mutate_function(name, spec, source, original, probes, plan, directory, runtime, record, *,
                    run_equivalent=False, semantic_mutants=(), isolate_candidate=False):
    directory.mkdir()
    returns_value = result_type(spec) != "void" and not spec.abi.noreturn
    variants = applicable_variants(name, source, record, returns_value=returns_value, run_equivalent=run_equivalent)
    for operator, contents in chain(variants, semantic_variants(source, semantic_mutants)):
        work = directory / operator
        work.mkdir()
        mutant = work / f"{name}.asm"
        mutant.write_text(contents, encoding="utf-8")
        item = {"operator": operator, "source_sha256": sha256_file(mutant), "commands": [],
                "probes": [], "killed": False}
        record["operators"].append(item)
        obj = candidate_object(work / f"{name}.o", mutant, name, original, item["commands"])
        item["object_sha256"] = sha256_file(obj)
        for case_name, rejection_codes in plan.mutations:
            probe = probes[case_name]
            binary, artifacts = build_case(probe.case, work / case_name, runtime, item["commands"],
                                          candidate=(name, obj), link_wraps=probe.wraps,
                                          isolate_candidate=isolate_candidate)
            observed, log = execute_native(probe, binary, work / f"{case_name}-inputs")
            item["probes"].append({"case": case_name, "binary_sha256": artifacts[binary.name], **log})
            if observed == expected(probe):
                continue
            if observed[0] not in rejection_codes or observed[1:] != (b"", b""):
                raise GateError(f"{operator}: {case_name} unclassified result {observed!r}")
            item["killed"] = True
            break
    total = len(record["operators"])
    killed = sum(item["killed"] for item in record["operators"])
    if run_equivalent:
        record.update(raw_total=total, raw_killed=killed)
        equivalent = {item["operator"] for item in record["equivalent"]}
        for item in record["operators"]:
            if item["killed"] and item["operator"] in equivalent:
                raise GateError(f"{name}: mutation equivalence contradicted by {item['operator']}")
        total -= len(equivalent)
    record.update(total=total, killed=killed, threshold_percent=90)
    if not total or 100 * killed < 90 * total:
        raise GateError(f"{name}: mutation killed {killed}/{total}, below 90%")
    record["outcome"] = "pass"
    print(f"PASS {name} mutation {killed}/{total} killed", flush=True)


def fuzz_observation(command, probe, payload, work, output_size):
    result = subprocess.run([*command, *probe.case.args], input=payload, cwd=work, env=probe.case.env,
                            capture_output=True, timeout=15)
    if result.returncode or result.stderr or len(result.stdout) != output_size:
        raise GateError(f"{command[-1]}: bad differential packet result "
                        f"({result.returncode}, {len(result.stdout)}, {result.stderr[:256]!r})")
    return result.stdout


def timed_fuzz(name, probe, plan, directory, runtime, record):
    if probe.files or probe.wraps or probe.host_skip is not None or len(probe.case.sources) != 1:
        raise GateError(f"{probe.case.name}: timed fuzz requires a shared direct C packet fixture")
    directory.mkdir()
    log = record["commands"]
    candidate, artifacts = build_case(probe.case, directory / "target", runtime, log)
    binaries = {"candidate": candidate}
    for compiler, label in (("gcc", "glibc"), ("musl-gcc", "musl")):
        obj, binary = directory / f"{label}.o", directory / label
        checked(log, [compiler, *COMPILE_FLAGS, "-DOA_PHASE6_HOST", "-c", probe.case.sources[0], "-o", obj])
        checked(log, ["tools/elf-audit", "--test-object", obj])
        if nm_symbols(log, obj, ["-g", "-u"]).get(name) != "U":
            raise GateError(f"{label} differential fixture lacks its direct {name} reference")
        checked(log, [compiler, *LINK_FLAGS, "-o", binary, obj])
        checked(log, ["tools/elf-audit", binary])
        artifacts.update({path.name: sha256_file(path) for path in (obj, binary)})
        binaries[label] = binary
    record["artifacts"] = artifacts
    commands = {label: [str(binary.resolve())] for label, binary in binaries.items()}
    timed_packets(name, probe, plan.record_sizes, directory, commands, record,
                  process_identity=name in PROCESS_IDENTITY_FAILURES)


def normalize_process_packets(raw, identities):
    identities["digest"].update(raw)
    normalized = bytearray(raw)
    for start in range(0, len(raw), PROCESS_IDENTITY_RECORD[1]):
        role = struct.unpack_from("<Q", raw, start)[0]
        offset = start + PROCESS_NORMALIZED_BYTES
        pid, ppid = struct.unpack_from("<II", raw, offset)
        identities["roles"].add(role)
        identities["pids"].add(pid)
        identities["ppids"].add(ppid)
        normalized[offset:offset + 8] = b"\0" * 8
    return bytes(normalized)


def timed_packets(name, probe, record_sizes, directory, commands, record, *, process_identity=False):
    if "candidate" not in commands or len(commands) < 2:
        raise GateError("timed differential requires a candidate and independent oracle")
    record.update(seed=FUZZ_SEED, runs=list(commands))
    seed_size, result_size = record_sizes
    rng = random.Random(FUZZ_SEED)
    start = time.monotonic()
    count = 0
    digests = {label: sha256() for label in ["input", *commands]}
    identities = {label: {"pids": set(), "ppids": set(), "roles": set(), "digest": sha256()}
                  for label in commands} if process_identity else {}
    while time.monotonic() - start < FUZZ_SECONDS:
        payload = rng.randbytes(seed_size * 512)
        digests["input"].update(payload)
        results = {label: fuzz_observation(command, probe, payload, directory, result_size * 512)
                   for label, command in commands.items()}
        for label, observed in identities.items():
            results[label] = normalize_process_packets(results[label], observed)
        if len(set(results.values())) != 1:
            for i in range(512):
                row = {label: data[i * result_size:(i + 1) * result_size].hex()
                       for label, data in results.items()}
                if len(set(row.values())) != 1:
                    stimulus = payload[i * seed_size:(i + 1) * seed_size].hex()
                    oracle_values = {value for label, value in row.items() if label != "candidate"}
                    error = CandidateFailure if len(oracle_values) == 1 else GateError
                    raise error(f"timed differential seed {FUZZ_SEED:#x}, row {count + i}, "
                                f"input {stimulus}: {row}")
        for label, result in results.items():
            digests[label].update(result)
        count += 512
    if count == 0:
        raise GateError("timed differential produced no records")
    if identities:
        record["process_identity"] = {}
        for label, observed in identities.items():
            roles = observed["roles"]
            pids, ppids = len(observed["pids"]), len(observed["ppids"])
            record["process_identity"][label] = {"roles": sorted(roles), "distinct_pids": pids,
                                                   "distinct_ppids": ppids,
                                                   "raw_output_sha256": observed["digest"].hexdigest()}
            if roles != {0, 1, 2} or min(pids, ppids) < 2:
                raise GateError(f"{name}: {label} did not observe varied live process identities")
        record["normalized_prefix_bytes"] = PROCESS_NORMALIZED_BYTES
    record.update(outcome="pass", records=count, elapsed_s=round(time.monotonic() - start, 6),
                  sha256={label: digest.hexdigest() for label, digest in digests.items()})
    print(f"PASS {name} timed differential {count} records", flush=True)


def pending_dependency(plan):
    result = {"outcome": "pending", "engine": plan.private_engine}
    if plan.private_helpers:
        result["helpers"] = list(plan.private_helpers)
    return result


def runtime_manifest_production(function, only=None, *, attempt=None, wrapper_only=False):
    plan = PLANS.get(function)
    wrapper_suffix = plan.wrapper_suffix if plan and wrapper_only else None
    scope = f"{wrapper_suffix}-verification" if wrapper_suffix else f"production-runtime-manifest-{only or 'function'}"
    evidence = {"schema_version": 1, "scope": scope, "function": function, "outcome": "fail",
                "production_verified": False, "checks": {}}
    checks = evidence["checks"]
    snapshot = partial(manifest_inputs, function)
    try:
        if only not in (None, "coverage", "mutation", "stub", "fuzz"):
            raise GateError(f"unsupported manifest production check {only}")
        if plan is None:
            raise GateError(f"{function}: no runtime manifest production plan")
        if wrapper_only and (not plan.private_engine or only is not None or attempt is not None):
            raise GateError("scoped wrapper verification requires a private-engine plan and no production attempt")
        if plan.private_engine:
            checks["dependency_closure"] = pending_dependency(plan)
            if only is None and not wrapper_only:
                raise GateError(f"{function}: shared implementation {plan.private_engine} needs separate production proof")
        evidence["toolchain"] = identify_tools("ar", "make", "objdump", "qemu-x86_64", "musl-gcc")
        evidence["inputs"] = verify_setup(checks, False, snapshot=snapshot)
        project = load_project()
        spec = project.functions[function]
        source = source_paths()[function]
        dependencies = None
        if only is None and plan.required_production:
            if not set(plan.required_production) <= set(spec.deps):
                raise GateError(f"{function}: undeclared required production dependency")
            dependencies = checks["production_dependencies"] = manifest_dependency_bindings(plan.required_production)
        required_cases = {"coverage": {plan.trace}, "mutation": {case for case, _ in plan.mutations},
                          "stub": set(), "fuzz": {plan.fuzz}}
        selected = {plan.abi}.union(*required_cases.values()) if only is None else required_cases[only]
        probes, controls = load_plan_probes(function, plan, required_cases=selected if only is not None else None)
        if not selected <= probes.keys() or function not in controls:
            raise GateError(f"{function}: incomplete function coverage in the runtime manifest")
        runners = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
                   "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                "--leak-check=full", "--errors-for-leak-kinds=all"]}
        workspace = BUILD / "production"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix=f"{function}-") as temp:
            directory = Path(temp).resolve().relative_to(ROOT)
            build = checks["runtime_build"] = {"outcome": "fail", "commands": []}
            runtime = build_runtime(directory / "runtime", build["commands"])
            build["artifacts"] = {"first": runtime[3]}
            if only is None:
                second = build_runtime(directory / "repeated-runtime", build["commands"])
                build["artifacts"]["second"] = second[3]
                if runtime[3] != second[3]:
                    raise GateError(f"{function}: repeated runtime artifacts differ")
                if dependencies is not None and any(item["archive_sha256"] != runtime[3]["libopenasm.a"]
                                                    for item in dependencies["functions"].values()):
                    raise GateError(f"{function}: runtime archive differs from its production dependency")
            build["outcome"] = "pass"
            original = directory / "runtime/obj" / source.relative_to("src/x86_64-linux").with_suffix(".o")
            candidate = checks["candidate_build"] = {"outcome": "fail", "commands": []}
            checked(candidate["commands"], ["tools/lint", source])
            candidate.update(outcome="pass", source=str(source), source_sha256=sha256_file(source),
                             object_sha256=sha256_file(original))

            if only is None:
                for check, cases in (("native_oracles", [probe for key, probe in probes.items() if key != plan.abi]),
                                     ("abi", [probes[plan.abi]])):
                    target = directory / check
                    target.mkdir()
                    record = checks[check] = {"outcome": "fail", "cases": {}}
                    run_cases(cases, target, runtime, second, runners, record["cases"],
                              host_macro="OA_PHASE6_HOST", classify_native=True)
                    if check == "abi" and plan.abi_result:
                        probe = probes[plan.abi].case
                        objects = [target / plan.abi / "first" / f"test-{index}.o"
                                   for index, path in enumerate(probe.sources) if path.suffix == ".c"]
                        log = record["cases"][plan.abi]["commands"]
                        if not any(nm_symbols(log, obj, ["-g", "-u"]).get("phase2_abi_probe_result") == "U"
                                   for obj in objects):
                            raise GateError(f"{function}: ABI fixture lacks the typed result trampoline")
                    record["outcome"] = "pass"
            if only in (None, "coverage"):
                trace = checks["branch_coverage"] = {"outcome": "fail", "commands": [], "runs": []}
                scoped_fileno = function == "fileno" and wrapper_only
                trace_function(function, source, original, probes[plan.trace], directory / "coverage", runtime, trace,
                               require_complete=not scoped_fileno)
                if scoped_fileno:
                    bind_descriptorless_scope(source, trace, evidence["inputs"])
            if only in (None, "stub"):
                stub = checks["generated_stub"] = {"outcome": "fail", "symbols": {}}
                run_stubs({function: controls[function]}, project, directory, runtime, stub)
            if only in (None, "mutation"):
                mutation = checks["production_mutation"] = {"outcome": "fail", "operators": []}
                mutate_function(function, spec, source, original, probes, plan,
                                directory / "mutation", runtime, mutation, run_equivalent=bool(plan.private_engine),
                                semantic_mutants=plan.semantic_mutants, isolate_candidate=bool(plan.private_engine))
            if only in (None, "fuzz"):
                fuzz = checks["differential_fuzz"] = {"outcome": "fail", "commands": []}
                timed_fuzz(function, probes[plan.fuzz], plan, directory / "fuzz", runtime, fuzz)
        if evidence["inputs"] != snapshot():
            raise GateError("runtime manifest verification inputs changed during the run")
        if dependencies is not None and dependencies != manifest_dependency_bindings(plan.required_production):
            raise GateError(f"{function}: production dependency evidence changed during verification")
        required = REQUIRED_CHECKS - {"branch_coverage"} if function == "fileno" and wrapper_only else REQUIRED_CHECKS
        if only is None and (not required <= checks.keys()
                             or any(checks[name]["outcome"] != "pass" for name in required)):
            raise GateError("runtime manifest production evidence is missing a passing required check")
        evidence.update(outcome="pass", production_verified=only is None and not wrapper_only)
    except (GateError, KeyError, OSError, ValueError, subprocess.SubprocessError) as error:
        evidence["error"] = str(error)
        evidence["failure_class"] = "semantic" if isinstance(error, CandidateFailure) else "harness"
        print(f"gate: {error}", file=sys.stderr)
    return finish_function_gate(function, wrapper_suffix or only, evidence, attempt, snapshot)


def wrapper_batch(functions, available, suffix, label):
    scope = f"{suffix}-verification"

    def child(name):
        item = {"outcome": "fail"}
        try:
            status = runtime_manifest_production(name, wrapper_only=True)
            path = EVIDENCE / f"{name}.{suffix}.json"
            record = json.loads(path.read_text(encoding="utf-8"))
            item.update(evidence=str(path), evidence_sha256=sha256_file(path))
            dependency = pending_dependency(PLANS[name])
            if (status == 0 and record.get("outcome") == "pass" and record.get("scope") == scope
                    and record.get("function") == name and record.get("production_verified") is False
                    and record.get("checks", {}).get("dependency_closure") == dependency
                    and record.get("inputs") == manifest_inputs(name)):
                item["outcome"] = "pass"
            else:
                item["error"] = record.get("error", "missing fresh scoped wrapper evidence")
        except (GateError, OSError, ValueError) as error:
            item["error"] = str(error)
        return name, item

    with ThreadPoolExecutor(max_workers=len(functions)) as pool:
        results = dict(pool.map(child, functions))
    passed = sum(item["outcome"] == "pass" for item in results.values())
    success = passed == len(functions)
    evidence = {"schema_version": 1, "scope": f"{scope}-batch",
                "outcome": "pass" if success else "fail", "production_verified": False,
                "functions": results, "passed": passed, "total": len(functions),
                "full_scope": set(functions) == available}
    report = write_evidence(f"{suffix}s", evidence)
    print(f"{label} wrapper checks {passed}/{len(functions)}. Evidence at {report}", flush=True)
    return 0 if success else 1


if __name__ == "__main__":
    os.chdir(ROOT)
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--allocator-wrappers", action="store_true")
    modes.add_argument("--stream-indicators", action="store_true")
    modes.add_argument("--getcwd-wrapper", action="store_true")
    modes.add_argument("--execvp-wrapper", action="store_true")
    parser.add_argument("functions", nargs="*")
    args = parser.parse_args()
    if args.getcwd_wrapper or args.execvp_wrapper:
        name = "getcwd" if args.getcwd_wrapper else "execvp"
        if args.functions:
            parser.error(f"the {name} wrapper check takes no function names")
        raise SystemExit(runtime_manifest_production(name, wrapper_only=True))
    if args.allocator_wrappers:
        available, suffix, label = ALLOCATOR_FUNCTIONS, "allocator-wrapper", "Allocator"
    else:
        available, suffix, label = STREAM_FAILURES.keys(), STREAM_WRAPPER_SUFFIX, "Stream indicator"
    if len(set(args.functions)) != len(args.functions) or set(args.functions) - available:
        parser.error("select unique wrapper names from the chosen batch")
    raise SystemExit(wrapper_batch(args.functions or sorted(available), available, suffix, label))

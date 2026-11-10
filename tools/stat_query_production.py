"""Verify the private Linux stat record translator against its independent contract."""

from hashlib import sha256
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace

from failure_journal import hash_json
from gate import BUILD, COMPILE_FLAGS, EVIDENCE, LINK_FLAGS, GateError, checked, identify_tools, nm_symbols, verify_setup, write_evidence
from phase1 import NASM, PIE_STARTUP_SRC, RUNTIME_SRC, STARTUP_SRC, build_case, build_runtime
from phase4 import execute_probe, load_probes, parse_probe
from phase6 import run_cases
from production import phase2_inputs, source_paths
from runtime_gate import ERRNO, REQUIRED_CHECKS as ERRNO_CHECKS, SOURCE as ERRNO_SOURCE
from runtime_manifest_gate import (FUZZ_SECONDS, REQUIRED_CHECKS, Plan, mutate_function, read_manifest_json,
                                   timed_packets, trace_function)
from spec import ROOT, regular_file, sha256_file, snapshot_inputs

HELPER = "__al_stat_query"
SOURCE = Path("src/x86_64-linux/internal/__al_stat_query.asm")
SUITE = Path("tests/phase6/stat_query")
CONTRACT = Path("docs/adr/0007-linux-files-process-signal-time.md")
SPEC = SimpleNamespace(name=HELPER, prototype=f"long {HELPER}(int, long, const char *, long, struct stat *)",
                       abi=SimpleNamespace(noreturn=False))
PACKET_CASES = ("stat-query-fstat-packets", "stat-query-fstatat-packets")
PLAN = Plan(SUITE, frozenset({HELPER}), (Path("tests/phase2/abi.asm"),),
            "stat-query-typed-abi", "stat-query-unit", (("stat-query-unit", tuple(range(11, 18))),),
            PACKET_CASES[0], (16, 64), (CONTRACT,), ((SUITE / "query.c", ("__al_syscall",)),))
STUB_REJECTION = 14
PADDING_MUTANT = ("retain-raw-stat-padding", "    mov dword [rdx + 36], 0       ; public padding\n", "    nop\n")


def stat_query_inputs():
    inputs = phase2_inputs()
    inputs.update(snapshot_inputs(ROOT, PLAN.contracts))
    return dict(sorted(inputs.items()))


def is_sha256(value):
    return type(value) is str and re.fullmatch(r"[0-9a-f]{64}", value) is not None


def check_helper_trace_and_mutation(checks):
    trace, mutation = checks["branch_coverage"], checks["production_mutation"]
    entry = trace.get("entry")
    if (type(trace.get("total")) is not int or trace["total"] < 1 or trace.get("covered") != trace["total"]
            or type(entry) is not dict or entry.get("observed") is not True):
        raise ValueError("stat query proof lacks full executed branch evidence")
    killed, total = mutation.get("killed"), mutation.get("total")
    operators = mutation.get("operators")
    if (type(killed) is not int or type(total) is not int or not 0 < killed <= total or 100 * killed < 90 * total
            or mutation.get("equivalent") != [] or type(operators) is not list or len(operators) != total
            or any(type(item) is not dict or type(item.get("killed")) is not bool for item in operators)
            or sum(item["killed"] for item in operators) != killed):
        raise ValueError("stat query proof lacks passing raw mutation evidence")


def check_helper_packets(checks):
    selectors = checks["differential_fuzz"].get("selectors")
    if type(selectors) is not dict or selectors.keys() != set(PACKET_CASES):
        raise ValueError("stat query proof lacks both exact raw packet cases")
    for name, case in selectors.items():
        if type(case) is not dict or case.get("outcome") != "pass":
            raise ValueError(f"{name}: stat query packet case did not pass")
        seconds, records, hashes = case.get("elapsed_s"), case.get("records"), case.get("sha256")
        if (type(seconds) not in (int, float) or seconds < FUZZ_SECONDS
                or (type(seconds) is float and not math.isfinite(seconds))
                or type(records) is not int or records < 512 or records % 512
                or case.get("runs") != ["candidate", "raw-linux"]
                or type(hashes) is not dict or hashes.keys() != {"candidate", "raw-linux", "input"}
                or not all(is_sha256(value) for value in hashes.values()) or hashes["candidate"] != hashes["raw-linux"]):
            raise ValueError(f"{name}: stat query proof lacks timed independent raw Linux packets")


def stat_runtime_artifacts(inputs):
    objects = {str(Path("obj") / source.relative_to(RUNTIME_SRC).with_suffix(".o"))
               for source in map(Path, inputs) if source.is_relative_to(RUNTIME_SRC) and source.suffix == ".asm"
               and source not in {STARTUP_SRC, PIE_STARTUP_SRC}}
    return {"crt1.o", "libopenasm.a", *objects}


def stat_dependency_bindings():
    bindings = {}
    runtime_digests = set()
    for name, source, scope, snapshot, required in (
            (HELPER, SOURCE, "production-private-dependency", stat_query_inputs, REQUIRED_CHECKS),
            (ERRNO, ERRNO_SOURCE, "production-runtime-function", phase2_inputs, ERRNO_CHECKS)):
        relative = EVIDENCE / f"{name}.production.json"
        raw = regular_file(ROOT, relative, "stat production dependency").read_bytes()
        record = read_manifest_json(raw)
        inputs = snapshot()
        if (type(record) is not dict or type(record.get("schema_version")) is not int
                or record["schema_version"] != 1 or record.get("function") != name or record.get("scope") != scope
                or record.get("outcome") != "pass" or (name == ERRNO and record.get("production_verified") is not True)
                or record.get("inputs") != inputs):
            raise ValueError(f"{name}: no exact passing stat dependency report for the current inputs")
        checks = record.get("checks")
        if (type(checks) is not dict or not required <= checks.keys()
                or any(type(item) is not dict or item.get("outcome") != "pass" for item in checks.values())):
            raise ValueError(f"{name}: incomplete stat dependency checks")
        artifacts = checks["runtime_build"].get("artifacts")
        if name == HELPER:
            check_helper_trace_and_mutation(checks)
            check_helper_packets(checks)
            if type(artifacts) is not dict or artifacts.keys() != {"first", "second"} or artifacts["first"] != artifacts["second"]:
                raise ValueError(f"{name}: missing reproducible stat helper runtime builds")
            artifacts = artifacts["first"]
        if (type(artifacts) is not dict or artifacts.keys() != stat_runtime_artifacts(inputs)
                or not all(is_sha256(value) for value in artifacts.values())):
            raise ValueError(f"{name}: incomplete stat dependency runtime artifact map")
        runtime_digests.add(hash_json(artifacts))
        candidate = checks["candidate_build"]
        source_hash = inputs.get(source.as_posix())
        object_path = Path("obj") / source.relative_to("src/x86_64-linux").with_suffix(".o")
        object_hash = candidate.get("object_sha256")
        if (type(artifacts) is not dict or candidate.get("source") != source.as_posix()
                or candidate.get("source_sha256") != source_hash or not is_sha256(source_hash)
                or not is_sha256(artifacts.get("libopenasm.a")) or not is_sha256(object_hash)
                or artifacts.get(object_path.as_posix()) != object_hash
                or (name == HELPER and record.get("source_sha256") != source_hash)):
            raise ValueError(f"{name}: stat dependency does not bind the source, object and archive")
        bindings[name] = {"evidence": relative.as_posix(), "evidence_sha256": sha256(raw).hexdigest(),
                          "inputs_sha256": hash_json(inputs), "source_sha256": source_hash,
                          "object": object_path.as_posix(), "object_sha256": object_hash,
                          "archive_sha256": artifacts["libopenasm.a"]}
    if len(runtime_digests) != 1 or len({item["archive_sha256"] for item in bindings.values()}) != 1:
        raise ValueError("stat helper and errno proofs used different runtime archives or objects")
    return {"outcome": "pass", "engine": HELPER, "functions": bindings,
            "runtime_artifacts_sha256": runtime_digests.pop()}


def load_stat_probes():
    def parse(table, where):
        return parse_probe(table, where, suite=PLAN.suite, programs=(), asm_fixtures=PLAN.assembly,
                           fault_wrappers=dict(PLAN.fault_wrappers))

    probes, _ = load_probes(SUITE / "manifest.toml", PLAN.public, parse, supplement=True)
    selected = {probe.case.name: probe for probe in probes}
    if set(selected) != {PLAN.trace, PLAN.abi, "stat-query-seccomp", *PACKET_CASES}:
        raise GateError("private stat manifest does not contain its exact independent cases")
    return selected


def check_stub(probe, directory, runtime, record):
    directory.mkdir()
    name = f"__wrap_{HELPER}"
    source = directory / "zero.asm"
    obj = directory / "zero.o"
    source.write_text(f"""; Generated zero-return control for the private stat ABI.
bits 64
default rel
global {name}:function
section .text.{name} progbits alloc exec nowrite
{name}:
    xor eax, eax
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
""", encoding="utf-8")
    log = record["commands"]
    checked(log, [*NASM, "-o", obj, source])
    checked(log, ["tools/elf-audit", "--assembly-object", obj])
    if nm_symbols(log, obj, ["-g", "--defined-only"]) != {name: "T"}:
        raise GateError("generated private stat stub did not define the expected symbol")
    binary, artifacts = build_case(probe.case, directory / "linked", runtime, log, (HELPER, obj),
                                   link_wraps=probe.wraps)
    record.update(source_sha256=sha256_file(source), artifacts=artifacts, expected_status=STUB_REJECTION)
    execute_probe(probe, binary, directory / "observed", record["runs"], {f"stub:{HELPER}": []}, (STUB_REJECTION, b"", b""))
    record["outcome"] = "pass"


def compare_raw_packets(probe, directory, runtime, record):
    directory.mkdir()
    if probe.files or probe.wraps or probe.case.sources != (SUITE / "packets.c",):
        raise GateError(f"{probe.case.name}: private stat timed oracle requires a direct unwrapped packet fixture")
    log = record["commands"]
    candidate, artifacts = build_case(probe.case, directory / "target", runtime, log)
    raw_object, raw_binary = directory / "raw-linux.o", directory / "raw-linux"
    checked(log, ["gcc", *COMPILE_FLAGS, "-DOA_PHASE6_HOST", "-DOA_STAT_QUERY_RAW", "-c",
                  probe.case.sources[0], "-o", raw_object])
    checked(log, ["tools/elf-audit", "--test-object", raw_object])
    raw_symbols = nm_symbols(log, raw_object, ["-g"])
    if raw_symbols.get("syscall") != "U" or raw_symbols.keys() & {HELPER, "stat", "lstat", "fstat", "fstatat"}:
        raise GateError("independent raw stat oracle must reference syscall and no public or private stat symbol")
    checked(log, ["gcc", *LINK_FLAGS, "-o", raw_binary, raw_object])
    record["artifacts"] = {"candidate": artifacts, "raw_linux_object_sha256": sha256_file(raw_object),
                           "raw_linux_binary_sha256": sha256_file(raw_binary)}
    commands = {"candidate": [candidate.resolve()], "raw-linux": [raw_binary.resolve()]}
    timed_packets(probe.case.name, probe, PLAN.record_sizes, directory, commands, record)


def verify_stat_query():
    evidence = {"schema_version": 1, "scope": "production-private-dependency", "function": HELPER,
                "outcome": "fail", "checks": {}}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "objdump", "qemu-x86_64")
        evidence["inputs"] = verify_setup(checks, False, snapshot=stat_query_inputs)
        probes = load_stat_probes()
        source = source_paths()[HELPER]
        evidence["source_sha256"] = sha256_file(source)
        workspace = BUILD / "production"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="stat-query-") as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            build = checks["runtime_build"] = {"outcome": "fail", "commands": []}
            runtime = build_runtime(directory / "runtime", build["commands"])
            repeated = build_runtime(directory / "repeated-runtime", build["commands"])
            if runtime[3] != repeated[3]:
                raise GateError("repeated private stat runtime artifacts differ")
            build.update(outcome="pass", artifacts={"first": runtime[3], "second": repeated[3]})
            original = directory / "runtime/obj" / source.relative_to("src/x86_64-linux").with_suffix(".o")
            candidate = checks["candidate_build"] = {"outcome": "fail", "commands": []}
            checked(candidate["commands"], ["tools/lint", source])
            candidate.update(outcome="pass", source=str(source), source_sha256=evidence["source_sha256"],
                             object_sha256=sha256_file(original))

            observations = checks["native_oracles"] = {"outcome": "fail", "cases": {}}
            target = directory / "oracles"
            target.mkdir()
            runners = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
                       "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                    "--leak-check=full", "--errors-for-leak-kinds=all"]}
            run_cases(probes.values(), target, runtime, repeated, runners, observations["cases"], "OA_PHASE6_HOST")
            observations["outcome"] = "pass"
            abi_case = probes[PLAN.abi].case
            abi = checks["abi"] = {"outcome": "fail", "commands": []}
            objects = [target / PLAN.abi / "first" / f"test-{index}.o"
                       for index, path in enumerate(abi_case.sources) if path.suffix == ".c"]
            if not any(nm_symbols(abi["commands"], obj, ["-g", "-u"]).get("phase2_abi_probe_result") == "U"
                       for obj in objects):
                raise GateError("private stat ABI fixture lacks the typed result trampoline")
            abi.update(outcome="pass", case=PLAN.abi)

            unit = probes[PLAN.trace]
            trace = checks["branch_coverage"] = {"outcome": "fail", "commands": [], "runs": []}
            trace_function(HELPER, source, original, unit, directory / "coverage", runtime, trace)
            stub = checks["generated_stub"] = {"outcome": "fail", "commands": [], "runs": {}}
            check_stub(unit, directory / "stub", runtime, stub)
            mutation = checks["production_mutation"] = {"outcome": "fail", "commands": [], "operators": []}
            mutate_function(HELPER, SPEC, source, original, probes, PLAN, directory / "mutation", runtime, mutation,
                            semantic_mutants=(PADDING_MUTANT,))
            timed = checks["differential_fuzz"] = {"outcome": "fail", "selectors": {}}
            for name in PACKET_CASES:
                record = timed["selectors"][name] = {"outcome": "fail", "commands": []}
                compare_raw_packets(probes[name], directory / name, runtime, record)
            timed["outcome"] = "pass"
        if evidence["inputs"] != stat_query_inputs():
            raise GateError("private stat verification inputs changed during the run")
        evidence["outcome"] = "pass"
    except (GateError, KeyError, OSError, ValueError, subprocess.SubprocessError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(f"{HELPER}.production", evidence)
    print(f"{evidence['scope']} evidence: {report}", flush=True)
    return int(evidence["outcome"] != "pass")


if __name__ == "__main__":
    os.chdir(ROOT)
    raise SystemExit(verify_stat_query())

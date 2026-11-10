"""Build and exercise the Phase 0 verification controls in the pinned toolchain."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

from spec import (
    ROOT, SpecError, comment_header, load_project, phase0_input_paths, sha256_file, snapshot_inputs,
)

BUILD = Path("build")
EVIDENCE = BUILD / "evidence"
FIXTURES = Path("tests/fixtures")
TEST_SYMBOL = "__al_test_strlen"
COMPILE_FLAGS = ("-std=c17", "-O2", "-Wall", "-Wextra", "-Werror", "-ffreestanding",
                 "-fno-builtin", "-fno-lto", "-fno-pie", "-ffunction-sections",
                 "-fdata-sections")
LINK_FLAGS = ("-static", "-no-pie", "-Wl,--gc-sections,--no-undefined")
MODES = ("abi", "unit", "guard", "differential", "fuzz")
PENDING = {
    "branch_coverage": "source-mapped branches from drcov or QEMU plugin",
    "engine_fuzz": "AFL++ or libFuzzer differential campaign",
    "external_conformance": "pinned libc-test, POSIX, LTP and applicable gnulib cases",
    "musl_differential": "independent musl oracle where applicable",
    "production_mutation": "complete per-function mutation campaign with applicable operators",
    "platform_matrix": "per-function production checks across the required platform matrix",
}


class GateError(Exception):
    pass


def run(command, *, timeout=30):
    command = list(map(str, command))
    try:
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                timeout=timeout, env={**os.environ, "LC_ALL": "C"})
        return {"command": command, "returncode": result.returncode,
                "stdout": result.stdout, "stderr": result.stderr}
    except subprocess.TimeoutExpired as error:
        raise GateError(f"{' '.join(command)} exceeded its {timeout}-second limit") from error


def checked(log, command, *, timeout=30):
    result = run(command, timeout=timeout)
    log.append(result)
    if result["returncode"] != 0:
        detail = (result["stderr"] or result["stdout"]).strip()
        raise GateError(f"{' '.join(result['command'])} exited {result['returncode']}. {detail}")
    return result["stdout"]


def write_evidence(name, evidence):
    EVIDENCE.mkdir(parents=True, exist_ok=True)
    target = EVIDENCE / f"{name}.json"
    with tempfile.NamedTemporaryFile(mode="w", dir=EVIDENCE, encoding="utf-8", delete=False) as handle:
        temporary = Path(handle.name)
        json.dump(evidence, handle, indent=2, sort_keys=True)
        handle.write("\n")
    temporary.replace(target)
    return target


def identify_tools():
    result = {}
    for tool in ("python3", "nasm", "gcc", "ld", "nm", "objcopy", "readelf", "valgrind", "git"):
        path = shutil.which(tool)
        if path is None:
            raise GateError(f"missing tool {tool}")
        version = checked([], [tool, "--version"]).splitlines()[0]
        result[tool] = {"sha256": sha256_file(Path(path).resolve()), "version": version}
    return result


def inputs():
    return snapshot_inputs(ROOT, phase0_input_paths(ROOT))


def static_controls(checks, directory):
    log = []
    controls = {"outcome": "fail", "commands": log}
    checks["checker_corpus"] = controls
    target = directory / "checker-corpus.json"
    result = run(["python3", "tests/tooling/test_lint.py", "--json", target], timeout=120)
    log.append(result)
    if not target.is_file():
        raise GateError("independent checker corpus did not produce evidence")
    corpus = json.loads(target.read_text())
    report = write_evidence("checker-corpus", corpus)
    controls.update(evidence=str(report), evidence_sha256=sha256_file(report))
    cases = corpus.get("cases", [])
    public_cases = corpus.get("public_cases", [])
    if (result["returncode"] != 0 or corpus.get("schema") != 1 or corpus.get("passed") is not True
            or not public_cases or any(case.get("passed") is not True for case in cases + public_cases)):
        raise GateError("checker corpus failed: " + (result["stderr"] or result["stdout"]).strip())
    negatives = sum(case["expected_rule"] is not None for case in cases)
    positives = len(cases) - negatives
    if negatives < 30 or not positives:
        raise GateError("checker corpus requires at least 30 intended defects and a passing control")
    controls.update(outcome="pass", negatives=negatives, positives=positives, public_cases=len(public_cases))
    print(result["stdout"].strip(), flush=True)


def runtime_controls(checks, harness):
    log = []
    record = {"outcome": "fail", "commands": log}
    checks["runtime_probe_controls"] = record
    target = harness.directory / "runtime-probes.json"
    result = run(["python3", "tests/tooling/test_probes.py", "--test-object", harness.test_obj,
                  "--abi-object", harness.abi_obj, "--json", target], timeout=60)
    log.append(result)
    if not target.is_file():
        raise GateError("independent runtime probe controls did not produce evidence")
    data = json.loads(target.read_text())
    report = write_evidence("runtime-probes", data)
    record.update(evidence=str(report), evidence_sha256=sha256_file(report))
    cases = data.get("cases", [])
    if (result["returncode"] != 0 or data.get("schema") != 1 or data.get("passed") is not True
            or len(cases) < 4 or any(case.get("passed") is not True for case in cases)):
        detail = (result["stderr"] or result["stdout"]).strip()
        raise GateError(f"runtime probe controls failed. {detail}")
    record.update(outcome="pass", cases=len(cases))
    print(result["stdout"].strip(), flush=True)


def source_policy(checks, directory):
    log = []
    record = {"outcome": "fail", "commands": log}
    checks["shipped_source_policy"] = record
    files = checked(log, ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"]).split("\0")
    c_family = {".c", ".cc", ".cpp", ".cxx", ".c++", ".h", ".hpp", ".hxx", ".s"}
    forbidden = sorted({name for name in files if name and Path(name).parts[0] != "tests"
                        and Path(name).suffix.lower() in c_family})
    if forbidden:
        raise GateError("C-family or non-NASM source outside tests: " + ", ".join(forbidden))
    object_path = directory / "shipped.o"
    for source in sorted(path for root in ("src", "ext", "apps")
                         for path in Path(root).rglob("*.asm")):
        checked(log, ["tools/lint", source])
        checked(log, ["nasm", "-f", "elf64", "-o", object_path, source])
        checked(log, ["tools/elf-audit", "--assembly-object", object_path])
    record["outcome"] = "pass"


def verify_protected_base(base):
    if not re.fullmatch(r"[a-f0-9]{40}", base):
        raise GateError("protected-tree base must be a full commit SHA")
    log = []
    diff = checked(log, ["git", "diff", "--name-status", "-z", "--no-renames", base, "HEAD", "--",
                         "tests/oracle", "tests/external"])
    entries = diff.rstrip("\0").split("\0") if diff else []
    changes = [(status, path) for status, path in zip(entries[::2], entries[1::2]) if status != "A"]
    if changes:
        lines = "\n".join(f"{status} {path}" for status, path in changes)
        raise GateError("protected oracle and external suite paths allow new files only\n" + lines)
    print(f"PASS protected paths against {base}", flush=True)


def nm_symbols(log, path, flags):
    lines = checked(log, ["nm", "-P", *flags, path]).splitlines()
    return {fields[0]: fields[1] for line in lines if len(fields := line.split()) >= 2}


class Harness:
    def __init__(self, directory, log):
        self.directory = directory
        self.oracle = directory / "glibc-oracle"
        self.test_obj = directory / "checks.o"
        self.abi_obj = directory / "abi.o"
        oracle_obj = directory / "glibc-oracle.o"
        for source, target in (("tests/unit/strlen.c", self.test_obj),
                               ("tests/external/strlen_glibc.c", oracle_obj)):
            checked(log, ["gcc", *COMPILE_FLAGS, "-include", "build/include/c/string.h",
                          "-c", source, "-o", target])
        checked(log, ["nasm", "-f", "elf64", "-o", self.abi_obj, "tests/abi/strlen.asm"])
        checked(log, ["tools/elf-audit", "--assembly-object", self.abi_obj])
        for path in (self.test_obj, self.abi_obj):
            if nm_symbols(log, path, ["-u"]).get(TEST_SYMBOL) != "U":
                raise GateError(f"{path} does not reference the candidate symbol {TEST_SYMBOL}")
        if nm_symbols(log, oracle_obj, ["-u"]).get("strlen") != "U":
            raise GateError("glibc oracle does not reference host strlen")
        checked(log, ["gcc", *LINK_FLAGS, "-o", self.oracle, oracle_obj])
        checked(log, ["tools/elf-audit", self.oracle])
        self.artifacts = {str(path.name): sha256_file(path) for path in (
            self.test_obj, self.abi_obj, oracle_obj, self.oracle)}

    def link(self, source, directory, log):
        object_path = directory / "strlen.o"
        renamed = directory / "candidate.o"
        binary = directory / "checks"
        checked(log, ["tools/lint", "--function", "strlen", source])
        checked(log, ["nasm", "-f", "elf64", "-o", object_path, source])
        checked(log, ["tools/elf-audit", "--assembly-object", object_path])
        if nm_symbols(log, object_path, ["-g", "--defined-only"]) != {"strlen": "T"}:
            raise GateError("candidate object must define exactly the exported strlen text symbol")
        checked(log, ["objcopy", "--redefine-sym", f"strlen={TEST_SYMBOL}", object_path, renamed])
        checked(log, ["gcc", *LINK_FLAGS, "-o", binary, self.test_obj, self.abi_obj, renamed])
        if nm_symbols(log, binary, ["-g", "--defined-only"]).get(TEST_SYMBOL) != "T":
            raise GateError("linked test executable does not contain the candidate symbol")
        checked(log, ["tools/elf-audit", binary])
        artifacts = {path.name: sha256_file(path) for path in (object_path, renamed, binary)}
        return binary, artifacts

    def probe(self, binary, mode, duration=0):
        command = [binary, mode]
        if mode in ("differential", "fuzz"):
            command.append(self.oracle)
        if mode == "fuzz":
            command.append(duration)
        result = run(command, timeout=duration + 20)
        if (result["returncode"] == 0 and result["stdout"].startswith(f"PASS {mode} ")
                and not result["stderr"]):
            return {**result, "outcome": "pass"}
        if (result["returncode"] == 1
                and re.search(rf"^FAIL {mode} [a-z]+:[a-z0-9-]+: ", result["stderr"], re.M)
                and "ERROR " not in result["stderr"]):
            return {**result, "outcome": "fail"}
        return {**result, "outcome": "error"}


def generate_stub(destination):
    spec = load_project().functions["strlen"]
    destination.write_text(
        comment_header(spec) + """
bits 64
default rel

section .text.strlen progbits alloc exec nowrite align=16
global strlen:function
strlen:
    xor eax, eax
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
"""
    )


def evaluate_fixture(checks, harness, kind, *, duration=0, memcheck=False):
    record = {"outcome": "fail", "commands": [], "probes": {}}
    checks[kind] = record
    directory = harness.directory / kind
    directory.mkdir()
    source = FIXTURES / f"strlen.{kind}.asm"
    if kind == "stub":
        source = directory / "strlen.stub.asm"
        generate_stub(source)
    record["source_sha256"] = sha256_file(source)
    binary, artifacts = harness.link(source, directory, record["commands"])
    record["artifacts"] = artifacts
    if memcheck:
        memcheck_record = {"outcome": "fail", "commands": []}
        checks["valgrind_guard"] = memcheck_record
        stdout = checked(memcheck_record["commands"], ["valgrind", "--quiet", "--error-exitcode=99",
                                                        "--leak-check=full", binary, "guard"], timeout=60)
        if not stdout.startswith("PASS guard "):
            raise GateError("Valgrind guard run did not execute the expected probes")
        memcheck_record["outcome"] = "pass"
        print("Valgrind: " + stdout.strip(), flush=True)
    for mode in MODES:
        probe = harness.probe(binary, mode, duration if mode == "fuzz" else 0)
        record["probes"][mode] = probe
        expected = "pass" if kind == "good" or mode == "abi" else "fail"
        if probe["outcome"] != expected:
            detail = (probe["stderr"] or probe["stdout"]).strip()
            raise GateError(f"{kind} {mode} expected {expected}, got {probe['outcome']}. {detail}")
        summary = (probe["stdout"] if expected == "pass" else probe["stderr"]).strip().splitlines()[0]
        print(f"{kind}: {summary}", flush=True)
    record["candidate_outcome"] = "pass" if kind == "good" else "fail"
    record["outcome"] = "pass"


def mutate(checks, harness):
    record = {"outcome": "fail", "operators": []}
    checks["bounded_mutation"] = record
    original = (FIXTURES / "strlen.good.asm").read_text()
    mutations = (
        ("invert-branch", "    jbe .done", "    ja .done"),
        ("signed-comparison", "    jbe .done", "    jle .done"),
        ("terminator-plus-one", "    cmp byte [rdi + rax], 0", "    cmp byte [rdi + rax], 1"),
        ("return-plus-one", "    ret", "    inc rax\n    ret"),
        ("return-minus-one", "    ret", "    dec rax\n    ret"),
    )
    for name, find, replacement in mutations:
        if original.count(find) != 1:
            raise GateError(f"mutation {name} needs exactly one matching instruction")
        directory = harness.directory / f"mutation-{name}"
        directory.mkdir()
        source = directory / "strlen.asm"
        source.write_text(original.replace(find, replacement, 1))
        item = {"name": name, "commands": [], "probes": [], "killed": False,
                "source_sha256": sha256_file(source)}
        record["operators"].append(item)
        binary, item["artifacts"] = harness.link(source, directory, item["commands"])
        for mode in ("guard", "unit", "differential"):
            probe = harness.probe(binary, mode)
            item["probes"].append(probe)
            if probe["outcome"] == "fail":
                item["killed"] = True
                break
            if probe["outcome"] != "pass":
                raise GateError(f"mutation {name} caused a harness error in {mode}")
    killed = sum(item["killed"] for item in record["operators"])
    total = len(mutations)
    record.update(killed=killed, total=total, threshold_percent=90)
    if 100 * killed < 90 * total:
        raise GateError(f"bounded fixture mutation killed {killed}/{total}, below 90%")
    record["outcome"] = "pass"
    print(f"PASS bounded fixture mutation {killed}/{total} killed", flush=True)


def verify_setup(checks, phase0):
    log = []
    result = {"outcome": "fail", "commands": log}
    checks["generated_outputs"] = result
    checked(log, ["tools/gen", "--test-headers"])
    snapshot = inputs()
    checked(log, ["tools/gen", "--check"])
    checked(log, ["tools/provenance", "--check"])
    if phase0:
        checked(log, ["python3", "tests/tooling/test_spec.py"], timeout=60)
    result["outcome"] = "pass"
    return snapshot


def execute(phase0, fixture, default_fixture):
    name = "phase0" if phase0 else "strlen" if fixture is None else f"strlen.{fixture}"
    if default_fixture == "stub":
        name = "strlen.stubcheck"
    evidence = {
        "schema_version": 1,
        "scope": "phase0" if phase0 else "phase0-fixture",
        "production_verified": False,
        "outcome": "fail",
        "checks": {key: {"outcome": "pending", "reason": value} for key, value in PENDING.items()},
    }
    if not phase0:
        evidence["function"] = "strlen"
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools()
        evidence["inputs"] = verify_setup(checks, phase0)
        workspace = BUILD / "phase0"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            if phase0:
                source_policy(checks, directory)
                static_controls(checks, directory)
            log = []
            record = {"outcome": "fail", "commands": log}
            checks["harness_build"] = record
            harness = Harness(directory, log)
            record.update(outcome="pass", artifacts=harness.artifacts)
            if phase0:
                runtime_controls(checks, harness)
            if fixture is None:
                for kind in ("good", "stub", "wrong"):
                    evaluate_fixture(checks, harness, kind, duration=60 if kind == "good" else 0,
                                     memcheck=phase0 and kind == "good")
                mutate(checks, harness)
            elif fixture == "mutation":
                evaluate_fixture(checks, harness, "good")
                mutate(checks, harness)
            elif default_fixture == "stub":
                evaluate_fixture(checks, harness, "good")
                evaluate_fixture(checks, harness, "stub")
            else:
                evaluate_fixture(checks, harness, fixture)
        if evidence["inputs"] != inputs():
            raise GateError("inputs changed during verification")
        if fixture in {"wrong", "stub"} and default_fixture is None:
            print(f"{fixture} candidate rejected by independent semantic probes", file=sys.stderr)
        else:
            evidence["outcome"] = "pass"
    except (GateError, OSError, SpecError, KeyError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    target = write_evidence(name, evidence)
    print(f"{evidence['scope']} evidence: {target}", flush=True)
    if phase0 and evidence["outcome"] == "pass":
        fixture_evidence = {**evidence, "scope": "phase0-fixture", "function": "strlen"}
        target = write_evidence("strlen", fixture_evidence)
        print(f"phase0-fixture evidence: {target}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


def main(default_fixture=None):
    os.chdir(ROOT)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("function", nargs="?")
    options = parser.add_mutually_exclusive_group()
    options.add_argument("--phase0", action="store_true", help="run Phase 0 milestone acceptance")
    options.add_argument("--fixture", choices=("good", "wrong", "stub"),
                         help="test one candidate and return its semantic result")
    options.add_argument("--production", action="store_true", help="require full production verification")
    options.add_argument("--protected-base", metavar="SHA", help="check protected paths against a commit")
    args = parser.parse_args()
    if default_fixture and (args.phase0 or args.fixture or args.production or args.protected_base):
        parser.error("this tool only accepts a function name")
    if args.protected_base:
        if args.function:
            parser.error("--protected-base does not take a function")
        try:
            verify_protected_base(args.protected_base)
        except (GateError, OSError) as error:
            print(f"gate: {error}", file=sys.stderr)
            return 1
        return 0
    if args.phase0:
        if args.function:
            parser.error("--phase0 does not take a function")
    elif args.function is None:
        parser.error("supply a function name or --phase0")
    if args.production:
        for key, reason in PENDING.items():
            print(f"{args.function}: pending {key} ({reason})", file=sys.stderr)
        return 1
    if args.function not in (None, "strlen"):
        print(f"{args.function}: no Phase 0 fixture or verification harness", file=sys.stderr)
        return 1
    return execute(args.phase0, args.fixture or default_fixture, default_fixture)

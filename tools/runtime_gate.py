"""Verify selected runtime functions through the actual freestanding runtime."""

import os
from pathlib import Path
import sys
import tempfile

from branch_coverage import verify_coverage
from gate import (BUILD, COMPILE_FLAGS, GateError, LINK_FLAGS, checked, identify_tools,
                  nm_symbols, run, verify_setup, write_evidence)
from phase1 import NASM, build_case, build_runtime, execute_case, generate_stub, load_manifest
from production import phase2_inputs
from spec import ROOT, load_project, sha256_file

ERRNO = "__errno_location"
SOURCE = Path("src/x86_64-linux/rt/__errno_location.asm")
HOST_ORACLE = Path("tests/external/errno_glibc.c")
REQUIRED_CHECKS = {
    "generated_outputs", "candidate_build", "runtime_build", "native_oracles",
    "abi", "branch_coverage", "generated_stub", "production_mutation", "glibc_differential",
    "oracle_applicability",
}


def result_tuple(result):
    return result["returncode"], result["stdout"], result["stderr"]


def check_fixture(case, path, runtime, checks):
    record = {"outcome": "fail", "commands": [], "runs": {}, "oracle": case.oracle,
              "skipped_backends": case.skip}
    checks[case.name] = record
    binary, record["artifacts"] = build_case(case, path, runtime, record["commands"])
    execute_case(case, binary, record)
    record["outcome"] = "pass"
    return record


def assemble(path, source, log, *, debug=False):
    command = (*NASM, "-g", "-F", "dwarf") if debug else NASM
    checked(log, [*command, "-o", path, source])
    checked(log, ["tools/elf-audit", "--assembly-object", path])
    if (nm_symbols(log, path, ["-g", "--defined-only"]) != {ERRNO: "T"}
            or nm_symbols(log, path, ["-g", "-u"])):
        raise GateError(f"{source}: expected only the freestanding {ERRNO} definition")
    return path


def text_disassembly(path, log):
    output = checked(log, ["objdump", "-dr", "-j", f".text.{ERRNO}", path])
    _, separator, text = output.partition("Disassembly of section ")
    if not separator or f"<{ERRNO}>" not in text:
        raise GateError(f"{path}: missing disassembly for {ERRNO}")
    return text


def trace_function(directory, runtime, original, case, record):
    directory.mkdir()
    log = record["commands"]
    debug = assemble(directory / f"{ERRNO}.debug.o", SOURCE, log, debug=True)
    if text_disassembly(debug, log) != text_disassembly(original, log):
        raise GateError("debug candidate text differs from the audited runtime object")
    binary, record["artifacts"] = build_case(case, directory / "linked", runtime, log,
                                              candidate=(ERRNO, debug))
    record["debug_object_sha256"] = sha256_file(debug)
    verify_coverage(record, directory, binary, ERRNO, SOURCE, [case.args], exact_case=case)


def check_stub(spec, control, directory, runtime, record):
    case, expected = control
    directory.mkdir()
    log = record["commands"]
    stub, record["source_sha256"] = generate_stub(spec, directory, log)
    binary, record["artifacts"] = build_case(case, directory / "linked", runtime, log, (ERRNO, stub))
    observed = run([binary, *case.args], environment=case.env)
    record.update(run=observed, oracle=case.oracle, expected_rejection=expected)
    if result_tuple(observed) != expected:
        raise GateError(f"{ERRNO}: generated stub did not produce its named oracle mismatch")
    record["outcome"] = "pass"
    print(f"PASS {case.name} rejected generated {ERRNO} stub", flush=True)


def check_mutation(case, directory, runtime, record):
    variants = (
        ("tcb-offset-plus-one", "    add rax, 0x40", "    add rax, 0x41"),
        ("tcb-offset-minus-one", "    add rax, 0x40", "    add rax, 0x3f"),
        ("omit-tcb-self-pointer", "    mov rax, [fs:0]", "    xor eax, eax"),
    )
    source = SOURCE.read_text(encoding="utf-8")
    directory.mkdir()
    for name, old, new in variants:
        if source.count(old) != 1:
            raise GateError(f"{ERRNO}: mutation {name} requires exactly one matching instruction")
        item = {"operator": name, "commands": [], "killed": False, "oracle": case.oracle,
                "expected_rejection": [31, "", ""]}
        record["operators"].append(item)
        work = directory / name
        work.mkdir()
        mutant = work / f"{ERRNO}.asm"
        mutant.write_text(source.replace(old, new, 1), encoding="utf-8")
        obj = assemble(work / f"{ERRNO}.o", mutant, item["commands"])
        binary, item["artifacts"] = build_case(case, work / "linked", runtime, item["commands"],
                                                candidate=(ERRNO, obj))
        observed = run([binary, *case.args], environment=case.env)
        item.update(run=observed, source_sha256=sha256_file(mutant))
        if result_tuple(observed) != (31, "", ""):
            raise GateError(f"{ERRNO}: mutation {name} did not produce the expected pointer mismatch")
        item["killed"] = True
    record.update(outcome="pass", killed=len(variants), total=len(variants), threshold_percent=90)
    print(f"PASS {ERRNO} mutation {len(variants)}/{len(variants)} killed", flush=True)


def check_glibc(directory, runtime_result, record):
    directory.mkdir()
    log = record["commands"]
    obj = directory / "errno-glibc.o"
    binary = directory / "errno-glibc"
    checked(log, ["gcc", *COMPILE_FLAGS, "-c", HOST_ORACLE, "-o", obj])
    checked(log, ["tools/elf-audit", "--test-object", obj])
    if nm_symbols(log, obj, ["-g", "-u"]).get(ERRNO) != "U":
        raise GateError("host errno oracle does not reference glibc __errno_location")
    checked(log, ["gcc", *LINK_FLAGS, "-o", binary, obj])
    checked(log, ["tools/elf-audit", binary])
    if nm_symbols(log, binary, ["-g", "--defined-only"]).get(ERRNO) != "T":
        raise GateError("host errno oracle did not link glibc __errno_location")
    observed = run([binary])
    record.update(run=observed, oracle="diff:glibc", compared_scope="stable writable errno cell",
                  source_sha256=sha256_file(HOST_ORACLE), binary_sha256=sha256_file(binary))
    if result_tuple(observed) != result_tuple(runtime_result) or observed["returncode"] != 0:
        raise GateError("freestanding and glibc errno contract observations disagree")
    record["outcome"] = "pass"
    print(f"PASS {ERRNO} differential glibc errno contract", flush=True)


def runtime_production(function, only=None):
    scope = "production-runtime-function" if only is None else f"production-runtime-{only}"
    evidence = {"schema_version": 1, "scope": scope, "function": function, "outcome": "fail",
                "production_verified": False, "checks": {}}
    checks = evidence["checks"]
    try:
        if function != ERRNO:
            raise GateError(f"{function}: independent runtime per-function gate is pending")
        evidence["toolchain"] = identify_tools("ar", "make", "objdump", "qemu-x86_64")
        evidence["inputs"] = verify_setup(checks, False, snapshot=phase2_inputs)
        project = load_project()
        cases, controls = load_manifest()
        by_name = {case.name: case for case in cases}
        context = by_name["errno-context"]
        workspace = BUILD / "production"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix=f"{function}-") as temp:
            directory = Path(temp).resolve().relative_to(ROOT)
            runtime_build = {"outcome": "fail", "commands": []}
            checks["runtime_build"] = runtime_build
            runtime = build_runtime(directory / "runtime", runtime_build["commands"])
            runtime_build.update(outcome="pass", artifacts=runtime[3])
            original = directory / "runtime/obj/rt" / f"{function}.o"
            checks["candidate_build"] = candidate = {"outcome": "fail", "commands": []}
            checked(candidate["commands"], ["tools/lint", SOURCE])
            candidate.update(outcome="pass", source=str(SOURCE), source_sha256=sha256_file(SOURCE),
                             object_sha256=sha256_file(original))
            if only is None:
                positives = {"outcome": "fail", "cases": {}}
                checks["native_oracles"] = positives
                for name in ("startup", "startup-empty-env", "startup-valgrind", "errno-context"):
                    check_fixture(by_name[name], directory / name, runtime, positives["cases"])
                positives["outcome"] = "pass"
                check_fixture(by_name["errno-context-abi"], directory / "abi", runtime, checks)
                checks["abi"] = checks.pop("errno-context-abi")
                checks["glibc_differential"] = {"outcome": "fail", "commands": []}
                check_glibc(directory / "glibc", positives["cases"]["errno-context"]["runs"]["native"],
                            checks["glibc_differential"])
                checks["oracle_applicability"] = {
                    "outcome": "pass",
                    "libc_test": {"outcome": "not_applicable",
                                  "reason": "The pinned suite has no Open Assembly TLS accessor case."},
                    "feedback_fuzz": {"outcome": "not_applicable",
                                      "reason": "There are no argument or data-dependent paths. The freestanding context model varies FS and errno values."},
                }
            if only in (None, "coverage"):
                checks["branch_coverage"] = {"outcome": "fail", "commands": [], "runs": []}
                trace_function(directory / "coverage", runtime, original, context, checks["branch_coverage"])
            if only in (None, "stub"):
                checks["generated_stub"] = {"outcome": "fail", "commands": []}
                check_stub(project.functions[function], controls[function], directory / "stub", runtime,
                           checks["generated_stub"])
            if only in (None, "mutation"):
                checks["production_mutation"] = {"outcome": "fail", "operators": []}
                check_mutation(context, directory / "mutations", runtime, checks["production_mutation"])
        if evidence["inputs"] != phase2_inputs():
            raise GateError("inputs changed during runtime per-function verification")
        if only is None and not REQUIRED_CHECKS <= checks.keys():
            raise GateError("runtime production evidence is missing a required check")
        evidence.update(outcome="pass", production_verified=only is None)
    except (GateError, KeyError, OSError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(f"{function}.{only or 'production'}", evidence)
    print(f"{scope} evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1

"""Verify the shared integer scanner across its signed and unsigned wrappers."""

import argparse
import os
from pathlib import Path
import re
import sys
import tempfile

from branch_coverage import verify_coverage
from gate import BUILD, GateError, checked, identify_tools, nm_symbols, run, verify_setup, write_evidence
from phase1 import NASM, RUNTIME_LINK, TEST_C_FLAGS, build_runtime
from production import (applicable_variants, arguments, assemble_candidate, build_checks,
                        candidate_symbol, link_checks, phase2_inputs, probe, read_plan, source_paths)
from spec import ROOT, sha256_file

HELPER = "__al_strtox"
WRAPPERS = ("strtol", "strtoul", "atoi", "atol", "atoll", "strtoll", "strtoull", "strtoimax",
            "strtoumax")
WIDE_WRAPPERS = {"wcstol", "wcstoll", "wcstoul", "wcstoull", "wcstoimax", "wcstoumax"}
WIDE_FIXTURE = Path("tests/phase9/wide_numeric/scanner.c")
WIDE_MODES = ("unit", "guard")
WIDE_ORACLE = "reference:wide-integer-scanner"


def link_wide(directory, startup, archive, fixture, helper, log):
    binary = directory / "wide-scanner"
    link_map = directory / "wide-scanner.map"
    checked(log, [*RUNTIME_LINK, f"--unique=.text.{HELPER}", f"-Map={link_map}", "--cref",
                  "-o", binary, startup, fixture, helper, archive])
    reference = re.compile(rf"^{HELPER}\s+{re.escape(str(helper))}\s*\n"
                           rf"[^\n]*{re.escape(str(archive))}\(__al_wcstox\.o\)\s*$", re.M)
    if not reference.search(link_map.read_text()):
        raise GateError("wide scanner link map does not bind the selected shared helper")
    checked(log, ["tools/elf-audit", binary])
    symbols = nm_symbols(log, binary, ["-g", "--defined-only"])
    if any(symbols.get(name) != "T" for name in WIDE_WRAPPERS | {HELPER}):
        raise GateError("wide scanner fixture did not retain its real public wrappers and helper")
    return binary


def wide_observation(binary, mode):
    result = run([binary, mode], environment={})
    if (result["returncode"] == 0 and not result["stderr"]
            and result["stdout"] == f"PASS {mode} {WIDE_ORACLE}\n"):
        return {**result, "outcome": "pass"}
    if (result["returncode"] == 1 and not result["stdout"]
            and result["stderr"].startswith(f"FAIL {mode} {WIDE_ORACLE}: ")):
        return {**result, "outcome": "fail"}
    return {**result, "outcome": "error"}


def prepare_wide(directory, source, record):
    directory.mkdir()
    log = record["commands"]
    runtime = directory / "runtime"
    startup, archive, _, hashes = build_runtime(runtime, log)
    fixture = directory / "scanner.o"
    checked(log, ["gcc", *TEST_C_FLAGS, "-c", WIDE_FIXTURE, "-o", fixture])
    checked(log, ["tools/elf-audit", "--test-object", fixture])
    references = nm_symbols(log, fixture, ["-g", "-u"])
    if any(references.get(name) != "U" for name in WIDE_WRAPPERS) or HELPER in references:
        raise GateError("wide scanner fixture must directly exercise the six public wrappers")
    helper = directory / f"{HELPER}.debug.o"
    checked(log, [*NASM, "-g", "-F", "dwarf", "-o", helper, source])
    checked(log, ["tools/elf-audit", "--assembly-object", helper])
    original = runtime / "obj" / source.relative_to("src/x86_64-linux").with_suffix(".o")
    texts = [checked(log, ["objdump", "-dr", "-j", f".text.{HELPER}", obj])
             .partition("Disassembly of section ")[2] for obj in (helper, original)]
    if not texts[0] or texts[0] != texts[1]:
        raise GateError("debug wide scanner helper differs from the archived machine code")
    binary = link_wide(directory, startup, archive, fixture, helper, log)
    runs = [wide_observation(binary, mode) for mode in WIDE_MODES]
    record.update(artifacts={"fixture": sha256_file(fixture), "helper": sha256_file(helper),
                             "binary": sha256_file(binary), "archive": hashes["libopenasm.a"],
                             "startup": hashes["crt1.o"]}, runs=runs)
    if any(result["outcome"] != "pass" for result in runs):
        raise GateError(f"independent wide scanner reference failed: {runs}")
    record["outcome"] = "pass"
    return startup, archive, fixture, binary


def collect_coverage(directory, wrappers, source, record, wide=None):
    expected, covered = set(), set()
    targets = [(name, binary, [arguments(plan, mode) for mode in plan.coverage_modes])
               for name, (plan, _, _, binary) in wrappers.items()]
    if wide:
        targets.append(("wide-public-wrappers", wide[3], [[mode] for mode in WIDE_MODES]))
    for name, binary, commands in targets:
        case = directory / name
        case.mkdir()
        item = {"outcome": "fail", "commands": [], "runs": []}
        record["wrappers"][name] = item
        verify_coverage(item, case, binary, HELPER, source, commands, require_complete=False)
        for edge in item["edges"]:
            identity = (edge["line"], edge["instruction"], edge["branch"])
            expected.add(identity)
            if edge["covered"]:
                covered.add(identity)
    missing = [{"line": line, "instruction": instruction, "branch": branch}
               for line, instruction, branch in sorted(expected - covered)]
    record.update(covered=len(covered), total=len(expected), missing=missing)
    if not expected or missing:
        raise GateError(f"{HELPER}: aggregate QEMU coverage {len(covered)}/{len(expected)} edges")
    record["outcome"] = "pass"
    print(f"PASS {HELPER} QEMU coverage {len(covered)}/{len(expected)} edges across {len(targets)} fixture groups",
          flush=True)


def mutant_object(source, directory, log):
    obj = directory / f"{HELPER}.o"
    renamed = directory / f"{HELPER}.renamed.o"
    checked(log, [*NASM, "-o", obj, source])
    checked(log, ["tools/elf-audit", "--assembly-object", obj])
    if (nm_symbols(log, obj, ["-g", "--defined-only"]) != {HELPER: "T"}
            or nm_symbols(log, obj, ["-g", "-u"]) != {"__errno_location": "U"}):
        raise GateError(f"{source}: scanner mutant changed the helper ABI")
    checked(log, ["objcopy", "--redefine-sym", f"{HELPER}={candidate_symbol(HELPER)}", obj, renamed])
    checked(log, ["tools/elf-audit", "--assembly-object", renamed])
    return renamed


def mutate_helper(directory, wrappers, source, record, wide=None):
    for operator, contents in applicable_variants(HELPER, source, record):
        case = directory / operator
        case.mkdir()
        mutant = case / f"{HELPER}.asm"
        mutant.write_text(contents, encoding="utf-8")
        item = {"operator": operator, "source_sha256": sha256_file(mutant),
                "commands": [], "probes": [], "killed": False}
        record["operators"].append(item)
        obj = mutant_object(mutant, case, item["commands"])
        item["object_sha256"] = sha256_file(obj)
        for name, (plan, test_objects, candidate, _) in wrappers.items():
            link = [obj if path.name == obj.name else path for path in candidate]
            binary = link_checks(plan, "gcc", test_objects, link, case / name, item["commands"])
            for mode in ("guard", "unit", "differential"):
                result = probe(plan, binary, mode)
                item["probes"].append({"wrapper": name, **result})
                if result["outcome"] == "fail":
                    item["killed"] = True
                    break
                if result["outcome"] != "pass":
                    raise GateError(f"{HELPER} {operator}: unclassified {name} {mode} result")
            if item["killed"]:
                break
        if wide and not item["killed"]:
            startup, archive, fixture, _ = wide
            binary = link_wide(case, startup, archive, fixture, case / f"{HELPER}.o", item["commands"])
            item["wide_binary_sha256"] = sha256_file(binary)
            for mode in WIDE_MODES:
                result = wide_observation(binary, mode)
                item["probes"].append({"wrapper": "wide-public-wrappers", **result})
                if result["outcome"] == "fail":
                    item["killed"] = True
                    break
                if result["outcome"] != "pass":
                    raise GateError(f"{HELPER} {operator}: unclassified wide {mode} result")
    total = len(record["operators"])
    killed = sum(item["killed"] for item in record["operators"])
    record.update(total=total, killed=killed, threshold_percent=90)
    if total == 0 or 100 * killed < 90 * total:
        raise GateError(f"{HELPER}: mutation killed {killed}/{total}, below 90%")
    record["outcome"] = "pass"
    print(f"PASS {HELPER} mutation {killed}/{total} killed across the wrapper fixtures", flush=True)


def check_helper(only=None):
    evidence = {
        "schema_version": 1,
        "scope": "production-private-dependency" if not only else f"production-private-{only}",
        "function": HELPER, "outcome": "fail", "checks": {},
    }
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("objdump", "qemu-x86_64", "ar", "make")
        evidence["inputs"] = verify_setup(checks, False, snapshot=phase2_inputs)
        sources = source_paths()
        source = sources[HELPER]
        evidence["source_sha256"] = sha256_file(source)
        workspace = BUILD / "production"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="strtox-") as temp:
            directory = Path(temp).resolve().relative_to(ROOT)
            log = []
            checks["wrapper_builds"] = {"outcome": "fail", "commands": log, "artifacts": {}}
            wrappers = {}
            for name in WRAPPERS:
                plan = read_plan(name)
                case = directory / name
                case.mkdir()
                candidate, info = assemble_candidate(name, sources[name], case / "candidate", log)
                if str(source) not in info["dependencies"].values():
                    raise GateError(f"{name}: did not link the scanner")
                test_objects = build_checks(plan, "gcc", case / "tests", log)
                binary = link_checks(plan, "gcc", test_objects, candidate, case / "checks", log)
                checks["wrapper_builds"]["artifacts"][name] = {
                    "candidate": info["artifacts"], "binary_sha256": sha256_file(binary),
                }
                wrappers[name] = (plan, test_objects, candidate, binary)
            checks["wrapper_builds"]["outcome"] = "pass"
            wide = None
            if WIDE_WRAPPERS & sources.keys():
                if not WIDE_WRAPPERS <= sources.keys():
                    raise GateError("wide integer scanner wrappers are incomplete")
                checks["wide_fixture"] = {"outcome": "fail", "commands": []}
                wide = prepare_wide(directory / "wide", source, checks["wide_fixture"])

            if only in (None, "coverage"):
                coverage = directory / "coverage"
                coverage.mkdir()
                checks["branch_coverage"] = {"outcome": "fail", "wrappers": {}}
                collect_coverage(coverage, wrappers, source, checks["branch_coverage"], wide)
            if only in (None, "mutation"):
                mutations = directory / "mutation"
                mutations.mkdir()
                checks["production_mutation"] = {"outcome": "fail", "operators": []}
                mutate_helper(mutations, wrappers, source, checks["production_mutation"], wide)
        if evidence["inputs"] != phase2_inputs():
            raise GateError("inputs changed during scanner verification")
        evidence["outcome"] = "pass"
    except (GateError, OSError, KeyError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(f"{HELPER}.{only or 'production'}", evidence)
    print(f"{evidence['scope']} evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    os.chdir(ROOT)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", choices=("coverage", "mutation"))
    raise SystemExit(check_helper(parser.parse_args().only))

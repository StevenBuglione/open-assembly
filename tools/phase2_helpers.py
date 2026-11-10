"""Verify the shared integer scanner across its signed and unsigned wrappers."""

import argparse
import os
from pathlib import Path
import sys
import tempfile

from branch_coverage import verify_coverage
from gate import BUILD, GateError, checked, identify_tools, nm_symbols, verify_setup, write_evidence
from phase1 import NASM
from production import (applicable_variants, arguments, assemble_candidate, build_checks,
                        candidate_symbol, link_checks, phase2_inputs, probe, read_plan, source_paths)
from spec import ROOT, sha256_file

HELPER = "__al_strtox"
WRAPPERS = ("strtol", "strtoul", "atoi", "atol", "atoll", "strtoll", "strtoull", "strtoimax",
            "strtoumax")


def collect_coverage(directory, wrappers, source, record):
    expected, covered = set(), set()
    for name, (plan, _, _, binary) in wrappers.items():
        case = directory / name
        case.mkdir()
        item = {"outcome": "fail", "commands": [], "runs": []}
        record["wrappers"][name] = item
        verify_coverage(item, case, binary, HELPER, source,
                        [arguments(plan, mode) for mode in plan.coverage_modes], require_complete=False)
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
    print(f"PASS {HELPER} QEMU coverage {len(covered)}/{len(expected)} edges across {len(wrappers)} wrappers",
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


def mutate_helper(directory, wrappers, source, record):
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
        evidence["toolchain"] = identify_tools("objdump", "qemu-x86_64")
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

            if only in (None, "coverage"):
                coverage = directory / "coverage"
                coverage.mkdir()
                checks["branch_coverage"] = {"outcome": "fail", "wrappers": {}}
                collect_coverage(coverage, wrappers, source, checks["branch_coverage"])
            if only in (None, "mutation"):
                mutations = directory / "mutation"
                mutations.mkdir()
                checks["production_mutation"] = {"outcome": "fail", "operators": []}
                mutate_helper(mutations, wrappers, source, checks["production_mutation"])
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

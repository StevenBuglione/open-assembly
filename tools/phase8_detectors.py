"""Calibrate Helgrind and DRD on the shipped futex lock."""

import os
from pathlib import Path
import re
import sys
import tempfile

from gate import BUILD, GateError, checked, identify_tools, run, source_policy, verify_setup, write_evidence
from phase1 import Case, build_case, build_runtime
from phase8 import inputs
from spec import ROOT, SpecError, sha256_file

SCOPE = "phase8-detectors"
SUITE = Path("tests/phase8/detectors")
MARKER = "detector fixture complete\n"
WRAPS = ("__al_lock", "__al_unlock")
HEADERS = ("valgrind.h", "helgrind.h", "drd.h", "memcheck.h")
RACE = {
    "helgrind": r"Possible data race during (?:read|write) of size 4 at (0x[0-9a-f]+)",
    "drd": r"Conflicting (?:load|store) by thread [0-9]+ at (0x[0-9a-f]+) size 4",
}
ORDER = r'lock order "(0x[0-9a-f]+) before (0x[0-9a-f]+)" violated'


def header_hashes(include):
    return {name: sha256_file(include / "valgrind" / name) for name in HEADERS}


def symbol_addresses(binary, log):
    listing = checked(log, ["nm", "-an", binary])
    addresses = {}
    for name in ("global_counter", "lock_words"):
        matches = re.findall(rf"^([0-9a-f]+)\s+[bBdD]\s+{name}$", listing, re.M)
        if len(matches) != 1:
            raise GateError(f"expected one fixture symbol named {name}")
        addresses[name] = int(matches[0], 16)
    return addresses


def execute_control(detector, mode, binary, directory, addresses):
    output = directory / f"{detector}-{mode}.log"
    result = run(["valgrind", f"--tool={detector}", "--error-exitcode=99", f"--log-file={output}",
                  binary, mode], timeout=45)
    diagnostics = output.read_text()
    result["diagnostics"] = diagnostics
    expected = 99 if mode == "race" or (mode == "order" and detector == "helgrind") else 0
    if (result["returncode"], result["stdout"], result["stderr"]) != (expected, MARKER, ""):
        raise GateError(f"{detector} {mode}: unexpected process result")
    summary = re.search(r"ERROR SUMMARY: ([0-9,]+) errors from ([0-9,]+) contexts", diagnostics)
    if not summary or (int(summary[1].replace(",", "")) == 0) != (expected == 0):
        raise GateError(f"{detector} {mode}: missing or unexpected detector summary")
    races = {int(value, 16) for value in re.findall(RACE[detector], diagnostics, re.I)}
    orders = {frozenset(map(lambda value: int(value, 16), pair))
              for pair in re.findall(ORDER, diagnostics, re.I)}
    if mode == "race":
        if races != {addresses["global_counter"]} or orders or "counter_worker" not in diagnostics:
            raise GateError(f"{detector}: race did not identify the planted counter access")
    elif mode == "order" and detector == "helgrind":
        left = addresses["lock_words"]
        if races or orders != {frozenset({left, left + 4})}:
            raise GateError("Helgrind: lock-order error did not identify the planted pair")
    elif races or orders:
        raise GateError(f"{detector} {mode}: unexpected race or lock order")
    return result


def execute():
    evidence = {"schema_version": 1, "scope": SCOPE, "production_verified": False,
                "outcome": "fail", "checks": {},
                "pending": ["full runtime detector stress and annotation coverage"]}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make")
        evidence["inputs"] = verify_setup(checks, False, snapshot=inputs)
        include = Path(os.environ["OPEN_ASSEMBLY_VALGRIND_HEADERS"])
        evidence["client_headers"] = header_hashes(include)
        workspace = BUILD / SCOPE
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as work:
            directory = Path(work).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            runtime = {"outcome": "fail", "commands": []}
            checks["runtime_build"] = runtime
            first = build_runtime(directory / "first", runtime["commands"])
            second = build_runtime(directory / "second", runtime["commands"])
            runtime["artifacts"] = {"first": first[3], "second": second[3]}
            if first[3] != second[3]:
                raise GateError("isolated runtime builds differ")
            runtime["outcome"] = "pass"
            checks["detectors"] = {}
            for detector in RACE:
                item = {"outcome": "fail", "commands": [], "runs": {}}
                checks["detectors"][detector] = item
                case = Case(detector, (SUITE / f"{detector}.c",), ("pthread_create", "_Exit", "write"),
                            [], {}, 0, MARKER, "", ("reference:detector-calibration",), ("native",), {})
                binary, artifacts = build_case(case, directory / (detector + "-first"), first,
                                               item["commands"], link_wraps=WRAPS, c_include=(include,))
                _, repeated = build_case(case, directory / (detector + "-second"), second,
                                         item["commands"], link_wraps=WRAPS, c_include=(include,))
                item["artifacts"] = {"first": artifacts, "second": repeated}
                if artifacts != repeated:
                    raise GateError(f"{detector}: isolated detector fixtures differ")
                item["addresses"] = addresses = symbol_addresses(binary, item["commands"])
                native = run([binary, "locked"])
                item["runs"]["native-locked"] = native
                if (native["returncode"], native["stdout"], native["stderr"]) != (0, MARKER, ""):
                    raise GateError(f"{detector}: native locked counter failed")
                for mode in ("locked", "race", "order"):
                    item["runs"][mode] = execute_control(detector, mode, binary, directory, addresses)
                    print(f"PASS {detector} {mode}", flush=True)
                item["outcome"] = "pass"
        if evidence["inputs"] != inputs() or evidence["client_headers"] != header_hashes(include):
            raise GateError("inputs changed during detector verification")
        evidence["outcome"] = "pass"
    except (GateError, KeyError, OSError, SpecError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(SCOPE, evidence)
    print(f"{SCOPE} evidence {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute())

"""Verify Phase 7 transcendental functions on a freshly built candidate archive."""

import argparse
from collections import Counter
import json
from pathlib import Path
import re
import sys
import tempfile

from gate import BUILD, COMPILE_FLAGS, GateError, checked, identify_tools, source_policy, verify_setup, write_evidence
from phase1 import TEST_C_FLAGS, build_runtime, generate_stub, nm_symbols
from phase5 import mpfr_identity
from phase7_exact import FORMATS, SUFFIXES, link_fixture, phase7_inputs, require_symbols
from spec import ROOT, SpecError, load_project, sha256_file, snapshot_inputs

TESTS = Path("tests/phase7/transcendental")
OPERATIONS = ("exp2", "log2", "log", "log10", "sin", "cos", "tan",
              "exp", "expm1", "log1p", "pow", "asin", "acos", "atan", "atan2",
              "sinh", "cosh", "tanh", "asinh", "acosh", "atanh",
              "erf", "erfc", "tgamma", "lgamma")
SHARDS = (
    ("asin-one", "asin", 0x3f7e0000, 262144, 2, None),
    ("atan2-ratio", "atan2", 0x007e0000, 262144, 3, 0x3f800000),
    ("cosh-range", "cosh", 0x42b0d000, 262144, 1, None),
    ("tanh-saturation", "tanh", 0x41000000, 262144, 2, None),
    ("atanh-pole", "atanh", 0x3f7f8000, 65536, 1, None),
    ("erfc-tiny", "erfc", 0x411f8000, 65536, 2, None),
    ("tgamma-range", "tgamma", 0x420c0000, 32768, 1, None),
    ("lgamma-negative", "lgamma", 0xc02f8000, 32768, 3, None),
)


def input_snapshot():
    bound = phase7_inputs()
    paths = [Path(__file__).relative_to(ROOT)]
    paths.extend(TESTS / name for name in ("README.md", "controls.py", "operations.def",
                                          "oracle.py", "probe.c", "verify.py"))
    bound.update(snapshot_inputs(ROOT, paths))
    return dict(sorted(bound.items()))


def required_symbols(width):
    return {operation + SUFFIXES[width] for operation in OPERATIONS}


def validate_specs(project):
    lines = (TESTS / "operations.def").read_text().splitlines()
    parsed = [re.fullmatch(r"OP(2?)\(([a-z0-9]+)\)", line) for line in lines]
    if (not all(parsed) or tuple(item[2] for item in parsed) != OPERATIONS or
            {item[2] for item in parsed if item[1]} != {"pow", "atan2"}):
        raise GateError("the typed transcendental inventory differs from the required operations")
    for width in FORMATS:
        for symbol in required_symbols(width):
            spec = project.functions.get(symbol)
            if spec is None or spec.header != "math.h":
                raise GateError(f"missing math.h specification for {symbol}")


def build_fixtures(directory, runtime, log):
    directory.mkdir()
    artifacts = {}
    for width in FORMATS:
        name = f"trans-f{width}"
        obj, binary = directory / (name + ".o"), directory / name
        checked(log, ["gcc", *TEST_C_FLAGS, f"-DTEST_FORMAT={width}", "-c", TESTS / "probe.c", "-o", obj])
        checked(log, ["tools/elf-audit", "--test-object", obj])
        required = required_symbols(width)
        require_symbols(log, obj, ["--undefined-only"], required, "U")
        link_fixture(log, binary, obj, runtime, required)
        artifacts.update({path.name: sha256_file(path) for path in (obj, binary)})
    return artifacts


def build_hosts(directory, log):
    directory.mkdir()
    artifacts = {}
    for width in FORMATS:
        for compiler in ("gcc", "musl-gcc"):
            binary = directory / f"{compiler}-trans-f{width}"
            obj = binary.with_suffix(".o")
            checked(log, [compiler, *COMPILE_FLAGS, f"-DTEST_FORMAT={width}", "-c",
                          TESTS / "probe.c", "-o", obj])
            checked(log, ["tools/elf-audit", "--test-object", obj])
            require_symbols(log, obj, ["--undefined-only"], required_symbols(width), "U")
            checked(log, [compiler, "-static", "-no-pie", "-o", binary, obj, "-lm"])
            checked(log, ["tools/elf-audit", binary])
            defined = nm_symbols(log, binary, ["-g", "--defined-only"])
            if any(defined.get(symbol) not in {"T", "W", "i"} for symbol in required_symbols(width)):
                raise GateError(f"{binary} omitted a required hosted mathematics entry")
            artifacts.update({path.name: sha256_file(path) for path in (obj, binary)})
    return artifacts


def build_stubs(directory, fixtures, runtime, project, record):
    directory.mkdir()
    for width in FORMATS:
        required = required_symbols(width)
        fixture = fixtures / f"trans-f{width}.o"
        for symbol in sorted(required):
            log = []
            stub = record[symbol] = {"commands": log}
            wrapped, source_hash = generate_stub(project.functions[symbol], directory, log)
            binary = directory / symbol
            link_fixture(log, binary, fixture, runtime, required, stub=(symbol, wrapped))
            stub.update(source_sha256=source_hash, object_sha256=sha256_file(wrapped),
                        executable_sha256=sha256_file(binary))


def validate_sample(report):
    symbols = set().union(*(required_symbols(width) for width in FORMATS))
    stubs = report["generated_stub_rejections"]
    if (report.get("passed") is not True or report.get("inputs_frozen") is not True
            or set(report["results"]) != {f"f{width}" for width in FORMATS}
            or set(stubs) != symbols or any(not item["stub_rejected"] for item in stubs.values())):
        raise GateError("incomplete sampled report or a generated stub passed its oracle")
    totals = Counter()
    maximum = {}
    hosted_differences = {}
    for kind, operations in report["results"].items():
        if set(operations) != set(OPERATIONS):
            raise GateError(f"the {kind} sample omitted an operation")
        for operation, backends in operations.items():
            required = {"native", "qemu", "gcc", "musl-gcc"}
            if kind != "f80":
                required.add("valgrind")
            if set(backends) != required:
                raise GateError(f"unexpected backends for {kind} {operation}")
            for backend, item in backends.items():
                if item["records"] <= 0 or item.get("finite_distances", 0) <= 0:
                    raise GateError(f"no comparable {backend} records for {kind} {operation}")
                totals[backend] += item["records"]
                ulp = item["max_finite_ulp"]
                maximum[backend] = max(maximum.get(backend, 0), ulp)
                if backend in {"native", "qemu", "valgrind"}:
                    if not item["passed"] or ulp > 1:
                        raise GateError(f"{kind} {operation} exceeded the {backend} accuracy contract")
                elif not item["passed"]:
                    hosted_differences[f"{kind}:{operation}:{backend}"] = {
                        "max_finite_ulp": ulp, "failures_by_reason": item["failures_by_reason"]}
    return dict(totals), maximum, hosted_differences


def run_shards(directory, fixtures, startup, archive, record):
    for name, operation, start, count, mode, second in SHARDS:
        target = directory / f"{name}.json"
        command = ["python3", TESTS / "verify.py", fixtures, target,
                   "--shard", operation, start, count, mode, "--input", archive, "--input", startup]
        if second is not None:
            command.extend(["--second", second])
        item = record[name] = {"commands": []}
        checked(item["commands"], command, timeout=300)
        data = json.loads(target.read_text())
        if (not data["passed"] or not data["inputs_frozen"] or data["count"] != count
                or data["results"]["native"]["records"] != count):
            raise GateError(f"the {name} shard report is incomplete")
        report = write_evidence(f"phase7-transcendental-shard-{name}", data)
        item.update(outcome="pass", observations=count, complete_domain=False,
                    evidence=str(report), evidence_sha256=sha256_file(report))
        print(f"PASS selected binary32 {name} shard with {count} observations", flush=True)


def execute(shards):
    evidence = {
        "schema_version": 1, "scope": "phase7-transcendental", "production_verified": False,
        "outcome": "fail", "checks": {},
        "limits": ["Selected transcendental inputs measured against MPFR.",
                   "Hosted result differences are recorded independently.",
                   "Consecutive binary32 shards cover selected ranges."],
    }
    checks = evidence["checks"]
    try:
        project = load_project()
        validate_specs(project)
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64", "musl-gcc")
        evidence["mpfr"] = mpfr_identity()
        evidence["inputs"] = verify_setup(checks, False, snapshot=input_snapshot)
        workspace = BUILD / "phase7-transcendental"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            build = checks["build"] = {"outcome": "fail", "commands": []}
            log = build["commands"]
            runtimes = [build_runtime(directory / f"runtime-{n}", log) for n in (1, 2)]
            if runtimes[0][3] != runtimes[1][3]:
                raise GateError("isolated transcendental runtime builds differ")
            first, second = (directory / f"fixtures-{n}" for n in (1, 2))
            left = build_fixtures(first, runtimes[0], log)
            right = build_fixtures(second, runtimes[1], log)
            if left != right:
                raise GateError("isolated transcendental probe builds differ")
            startup, archive, _, runtime_hashes = runtimes[0]
            hosts, stubs = directory / "hosts", directory / "stubs"
            build.update(outcome="pass", runtime_artifacts=runtime_hashes,
                         candidate_artifacts=left, hosted_artifacts=build_hosts(hosts, log))
            stub_record = checks["stubs"] = {"outcome": "fail", "symbols": {}}
            build_stubs(stubs, first, runtimes[0], project, stub_record["symbols"])
            control = checks["accuracy_controls"] = {"outcome": "fail", "commands": []}
            target = directory / "controls.json"
            checked(control["commands"], ["python3", TESTS / "controls.py", first, startup, archive,
                                          directory / "controls", target, "--accuracy-only"], timeout=60)
            controls = json.loads(target.read_text())
            if (not controls["passed"] or len(controls["controls"]) != 4 or
                    any(not item["matched"] for item in controls["controls"].values())):
                raise GateError("an accuracy comparator control failed")
            control_report = write_evidence("phase7-transcendental-controls", controls)
            control.update(outcome="pass", evidence=str(control_report),
                           evidence_sha256=sha256_file(control_report))
            sampled = checks["sampled"] = {"outcome": "fail", "commands": []}
            target = directory / "sampled.json"
            checked(sampled["commands"], ["python3", TESTS / "verify.py", first, target, "--hosts", hosts,
                                          "--stubs", stubs, "--input", startup, "--input", archive,
                                          "--input", control_report], timeout=600)
            sample = json.loads(target.read_text())
            totals, maxima, differences = validate_sample(sample)
            sample_report = write_evidence("phase7-transcendental-sampled", sample)
            sampled.update(outcome="pass", records=totals, max_finite_ulp=maxima,
                           hosted_differences=differences, evidence=str(sample_report),
                           evidence_sha256=sha256_file(sample_report))
            stub_record.update(outcome="pass", rejections=len(sample["generated_stub_rejections"]))
            print(f"PASS sampled transcendental {totals}, {stub_record['rejections']} typed stub rejections",
                  flush=True)
            if shards:
                record = checks["shards"] = {"outcome": "fail", "groups": {}}
                run_shards(directory, first, startup, archive, record["groups"])
                record["outcome"] = "pass"
        if evidence["inputs"] != input_snapshot():
            raise GateError("inputs changed during transcendental verification")
        evidence["outcome"] = "pass"
    except (GateError, KeyError, OSError, SpecError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence("phase7-transcendental", evidence)
    print(f"phase7-transcendental evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shards", action="store_true", help="also run the selected large binary32 ranges")
    raise SystemExit(execute(parser.parse_args().shards))

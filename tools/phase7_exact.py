"""Gate the exact mathematics slice of Phase 7."""

import argparse
import json
from pathlib import Path
import re
import sys
import tempfile

from gate import BUILD, COMPILE_FLAGS, GateError, checked, identify_tools, source_policy, verify_setup, write_evidence
from phase1 import RUNTIME_LINK, TEST_C_FLAGS, build_runtime, generate_stub, nm_symbols
from phase5 import mpfr_identity, phase5_inputs
from spec import ROOT, SpecError, load_project, sha256_file, snapshot_inputs

TESTS = Path("tests/phase7")
FORMATS = (32, 64, 80)
SUFFIXES = {32: "f", 64: "", 80: "l"}
EXHAUSTIVE_OPERATIONS = (
    "class", "sign", "fabsf", "copysignf", "ceilf", "floorf", "truncf", "roundf",
    "nearbyintf", "rintf", "frexpf", "ilogbf", "logbf", "modff",
)
WINDOWS = (
    0, 0x007ff800, 0x3efff800, 0x3f7ff800, 0x4afff800, 0x7f7ff800,
    0x7fbff800, 0x7ffff800, 0x807ff800, 0xbefff800, 0xbf7ff800,
    0xcafff800, 0xff7ff800, 0xffbff800, 0xfffff000,
)
DOMAIN = 1 << 32


def phase7_inputs():
    bound = phase5_inputs()
    bound.update(snapshot_inputs(ROOT, [Path("docs/adr/0008-math-range-reduction.md")]))
    return dict(sorted(bound.items()))


def exact_operations():
    lines = (TESTS / "operations.def").read_text().splitlines()
    groups = []
    for line in lines:
        match = re.fullmatch(r"OP\(([a-z]+)\)", line)
        if match is None:
            raise GateError(f"invalid exact math fixture operation {line!r}")
        groups.append(match[1])
    if len(set(groups)) != 34 or len(groups) != 34 or not {"classify", "compare"} <= set(groups):
        raise GateError("exact fixture must provide 32 function groups and two macro groups")
    return tuple(op for op in groups if op not in {"classify", "compare"})


def require_symbols(log, path, flags, expected, kind):
    symbols = nm_symbols(log, path, ["-g", *flags])
    missing = sorted(name for name in expected if symbols.get(name) != kind)
    if missing:
        raise GateError(f"{path} does not bind required {kind} symbols {', '.join(missing)}")


def link_fixture(log, binary, obj, runtime, expected, *, stub=None):
    startup, archive, exports, _ = runtime
    if any(exports.get(symbol) != "T" for symbol in expected):
        raise GateError("the runtime archive lacks an exact mathematics entry")
    options = []
    objects = [obj]
    if stub is not None:
        symbol, wrapped = stub
        options.append(f"--wrap={symbol}")
        objects.append(wrapped)
        expected = set(expected) - {symbol} | {f"__wrap_{symbol}"}
    checked(log, [*RUNTIME_LINK, *options, "-o", binary, startup, *objects, archive])
    checked(log, ["tools/elf-audit", binary])
    require_symbols(log, binary, ["--defined-only"], {"_start", "main", *expected}, "T")


def build_fixtures(directory, runtime, operations, log):
    directory.mkdir()
    artifacts = {}
    for width in FORMATS:
        name = f"math-f{width}"
        obj, binary = directory / (name + ".o"), directory / name
        checked(log, ["gcc", *TEST_C_FLAGS, f"-DTEST_FORMAT={width}",
                      "-c", TESTS / "math_packet.c", "-o", obj])
        checked(log, ["tools/elf-audit", "--test-object", obj])
        expected = {op + SUFFIXES[width] for op in (
            *operations, "__al_fpclassify", "__al_signbit", "__al_compare",
        )}
        require_symbols(log, obj, ["--undefined-only"], expected, "U")
        link_fixture(log, binary, obj, runtime, expected)
        artifacts.update({p.name: sha256_file(p) for p in (obj, binary)})
    obj, binary = directory / "exhaustive.o", directory / "exhaustive"
    checked(log, ["gcc", *TEST_C_FLAGS, "-c", TESTS / "exhaustive.c", "-o", obj])
    checked(log, ["tools/elf-audit", "--test-object", obj])
    expected = set(EXHAUSTIVE_OPERATIONS) - {"class", "sign"} | {"__al_fpclassifyf", "__al_signbitf"}
    require_symbols(log, obj, ["--undefined-only"], expected, "U")
    link_fixture(log, binary, obj, runtime, expected)
    artifacts.update({p.name: sha256_file(p) for p in (obj, binary)})
    return artifacts


def build_hosts(directory, log):
    directory.mkdir()
    artifacts = {}
    for compiler in ("gcc", "musl-gcc"):
        for width in FORMATS:
            binary = directory / f"{compiler}-math-f{width}"
            checked(log, [compiler, *COMPILE_FLAGS, f"-DTEST_FORMAT={width}", "-static",
                          "-no-pie", "-o", binary, TESTS / "math_packet.c", "-lm"])
            checked(log, ["tools/elf-audit", binary])
            artifacts[binary.name] = sha256_file(binary)
    return artifacts


def build_stubs(directory, binaries, runtime, operations, record):
    directory.mkdir()
    project = load_project()
    record["artifacts"] = {}
    for width in FORMATS:
        obj = binaries / f"math-f{width}.o"
        expected = {op + SUFFIXES[width] for op in (
            *operations, "__al_fpclassify", "__al_signbit", "__al_compare",
        )}
        for op in operations:
            symbol = op + SUFFIXES[width]
            log = []
            item = {"commands": log}
            record["artifacts"][symbol] = item
            spec = project.functions.get(symbol)
            if spec is None or spec.header != "math.h":
                raise GateError(f"missing math specification for generated stub {symbol}")
            wrapped, source_hash = generate_stub(spec, directory, log)
            binary = directory / symbol
            link_fixture(log, binary, obj, runtime, expected, stub=(symbol, wrapped))
            item.update(source_sha256=source_hash, object_sha256=sha256_file(wrapped),
                        executable_sha256=sha256_file(binary))
    record["outcome"] = "pass"


def validate_sample(data, operations):
    expected_groups = set(operations) | {"classify", "compare"}
    expected_stubs = {op + SUFFIXES[width] for op in operations for width in FORMATS}
    if (data.get("schema") != 1 or data.get("scope") != "sampled Phase 7 exact mathematics"
            or data.get("passed") is not True or data.get("inputs_frozen") is not True
            or set(data["results"]) != {f"f{width}" for width in FORMATS}
            or set(data["generated_stub_rejections"]) != expected_stubs
            or any(item["passed"] is not True for item in data["generated_stub_rejections"].values())):
        raise GateError("the independent sampled report is incomplete")
    totals = {}
    for result in data["results"].values():
        if set(result) != expected_groups:
            raise GateError("the independent sampled report omitted an operation")
        for group in result.values():
            if not {"native", "qemu", "gcc", "musl-gcc"} <= set(group):
                raise GateError("the independent sampled report omitted a required backend")
            for backend, item in group.items():
                if item["passed"] is not True or item["records"] <= 0:
                    raise GateError(f"the independent sampled report has no passing {backend} records")
                totals[backend] = totals.get(backend, 0) + item["records"]
    if not totals.get("valgrind"):
        raise GateError("the independent sampled report omitted Memcheck")
    return totals


def boundary_windows(binary, record):
    log = record["commands"]
    for op in EXHAUSTIVE_OPERATIONS:
        for mode in range(4):
            for first in WINDOWS:
                checked(log, [binary, op, mode, first, 4096])
    record.update(outcome="pass", observations=len(log) * 4096, complete_domain=False,
                  operations=list(EXHAUSTIVE_OPERATIONS), rounding_mode_indices=list(range(4)))
    print(f"PASS binary32 boundary windows {record['observations']} observations", flush=True)


def exhaustive_cases(suite):
    if suite == "representative":
        return [("fabsf", 0)]
    cases = [(op, 0) for op in EXHAUSTIVE_OPERATIONS]
    if suite == "rounding":
        cases.extend((op, mode) for op in ("nearbyintf", "rintf") for mode in (1, 2, 3))
    return cases


def run_exhaustive(directory, binary, runtime, suite, workers, record):
    startup, archive, _, _ = runtime
    for op, mode in exhaustive_cases(suite):
        name = f"phase7-exact-{op}-mode{mode}"
        target = directory / (name + ".json")
        commands = []
        item = {"outcome": "fail", "commands": commands}
        record["groups"][f"{op}:{mode}"] = item
        checked(commands, ["python3", TESTS / "exhaustive.py", binary, op, target,
                           "--mode", mode, "--shards", 64, "--workers", workers,
                           "--input", startup, "--input", archive], timeout=900)
        data = json.loads(target.read_text())
        if (data.get("schema") != 1 or data.get("complete_domain") is not True
                or data.get("inputs_frozen") is not True or data["operation"] != op
                or data["rounding_mode_index"] != mode or data["start"] != 0
                or data["requested_patterns"] != DOMAIN or data["passed_patterns"] != DOMAIN):
            raise GateError(f"incomplete exhaustive binary32 group {op}:{mode}")
        report = write_evidence(name, data)
        item.update(outcome="pass", patterns=DOMAIN, evidence=str(report),
                    evidence_sha256=sha256_file(report))
        print(f"PASS exhaustive binary32 {op} mode {mode}, {DOMAIN} patterns", flush=True)
    record["outcome"] = "pass"


def execute(suite, workers):
    evidence = {
        "schema_version": 1, "scope": "phase7-exact", "production_verified": False,
        "outcome": "fail", "checks": {},
        "exhaustive_suite": suite,
        "limitations": ["Exact math slice only. Transcendental and complex functions and Lua are outside this gate.",
                        "Exhaustive status applies to each named binary32 operation and rounding mode."],
    }
    checks = evidence["checks"]
    try:
        operations = exact_operations()
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64", "musl-gcc")
        evidence["mpfr"] = mpfr_identity()
        evidence["inputs"] = verify_setup(checks, False, snapshot=phase7_inputs)
        workspace = BUILD / "phase7-exact"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            record = checks["build"] = {"outcome": "fail", "commands": []}
            log = record["commands"]
            runtime = [build_runtime(directory / f"runtime-{i}", log) for i in (1, 2)]
            if runtime[0][3] != runtime[1][3]:
                raise GateError("two isolated exact math runtime builds differ")
            first, second = (directory / f"fixtures-{i}" for i in (1, 2))
            fixtures = [build_fixtures(path, built, operations, log)
                        for path, built in zip((first, second), runtime, strict=True)]
            if fixtures[0] != fixtures[1]:
                raise GateError("two isolated exact math fixture builds differ")
            hosts, stubs = (directory / child for child in ("hosts", "stubs"))
            record.update(outcome="pass", runtime_artifacts=runtime[0][3], fixture_artifacts=fixtures[0],
                          hosted_artifacts=build_hosts(hosts, log))
            build_stubs(stubs, first, runtime[0], operations, checks.setdefault("stubs", {"outcome": "fail"}))
            record = checks["sampled"] = {"outcome": "fail", "commands": []}
            target = directory / "sampled.json"
            startup, archive, _, _ = runtime[0]
            checked(record["commands"], ["python3", TESTS / "sample.py", first, target, "--hosts", hosts,
                                         "--stubs", stubs, "--input", startup, "--input", archive], timeout=600)
            sample = json.loads(target.read_text())
            totals = validate_sample(sample, operations)
            report = write_evidence("phase7-exact-sampled", sample)
            record.update(outcome="pass", records=totals, stub_rejections=len(sample["generated_stub_rejections"]),
                          evidence=str(report), evidence_sha256=sha256_file(report))
            print(f"PASS sampled exact math {totals}, 96 typed stub rejections", flush=True)
            boundary_windows(first / "exhaustive", checks.setdefault("windows", {"outcome": "fail", "commands": []}))
            run_exhaustive(directory, first / "exhaustive", runtime[0], suite, workers,
                           checks.setdefault("exhaustive", {"outcome": "fail", "groups": {}}))
        if evidence["inputs"] != phase7_inputs():
            raise GateError("inputs changed during exact math verification")
        evidence["outcome"] = "pass"
    except (GateError, KeyError, OSError, SpecError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence("phase7-exact", evidence)
    print(f"phase7-exact evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exhaustive-suite", choices=("representative", "nearest", "rounding"),
                        default="representative")
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    if not 1 <= args.workers <= 32:
        parser.error("--workers must be between 1 and 32")
    raise SystemExit(execute(args.exhaustive_suite, args.workers))

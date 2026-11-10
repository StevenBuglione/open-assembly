"""Verify the first Phase 7 complex ABI and numerical slice."""

from collections import Counter
import json
from pathlib import Path
import sys
import tempfile

from gate import BUILD, COMPILE_FLAGS, GateError, checked, identify_tools, source_policy, verify_setup, write_evidence
from phase1 import TEST_C_FLAGS, build_runtime, generate_stub, nm_symbols
from phase5 import mpfr_identity
from phase7_exact import FORMATS, SUFFIXES, link_fixture, phase7_inputs, require_symbols
from spec import ROOT, SpecError, load_project, sha256_file, snapshot_inputs

TESTS = Path("tests/phase7/complex")
OPERATIONS = ("creal", "cimag", "conj", "cproj", "cabs", "carg", "clog", "csqrt", "cexp",
              "ccos", "csin", "ccosh", "csinh", "ctan", "ctanh",
              "cacos", "casin", "catan", "cacosh", "casinh", "catanh", "cpow")


def input_snapshot():
    result = phase7_inputs()
    extra = [Path(__file__).relative_to(ROOT), Path("docs/adr/0011-complex-abi.md"),
             TESTS / "probe.c", TESTS / "verify_complex.py", TESTS / "README.md",
             TESTS / "operations.def", TESTS / "complex_math.py", TESTS / "power.py",
             TESTS / "replay_boundaries.py"]
    extra.extend(Path("tests/phase7/transcendental") / name
                 for name in ("oracle.py", "verify.py", "operations.def"))
    result.update(snapshot_inputs(ROOT, extra))
    return dict(sorted(result.items()))


def symbols_for(width):
    return {operation + SUFFIXES[width] for operation in OPERATIONS}


def build_fixtures(directory, runtime, log):
    directory.mkdir()
    artifacts = {}
    for width in FORMATS:
        binary = directory / f"complex-f{width}"
        obj = binary.with_suffix(".o")
        checked(log, ["gcc", *TEST_C_FLAGS, f"-DTEST_FORMAT={width}", "-c", TESTS / "probe.c", "-o", obj])
        checked(log, ["tools/elf-audit", "--test-object", obj])
        required = symbols_for(width)
        require_symbols(log, obj, ["--undefined-only"], required, "U")
        link_fixture(log, binary, obj, runtime, required)
        artifacts.update({path.name: sha256_file(path) for path in (obj, binary)})
    return artifacts


def build_hosts(directory, log):
    directory.mkdir()
    artifacts = {}
    for width in FORMATS:
        for compiler in ("gcc", "musl-gcc"):
            binary = directory / f"{compiler}-complex-f{width}"
            obj = binary.with_suffix(".o")
            checked(log, [compiler, *COMPILE_FLAGS, f"-DTEST_FORMAT={width}", "-c",
                          TESTS / "probe.c", "-o", obj])
            checked(log, ["tools/elf-audit", "--test-object", obj])
            require_symbols(log, obj, ["--undefined-only"], symbols_for(width), "U")
            checked(log, [compiler, "-static", "-no-pie", "-o", binary, obj, "-lm"])
            checked(log, ["tools/elf-audit", binary])
            defined = nm_symbols(log, binary, ["-g", "--defined-only"])
            if any(defined.get(symbol) not in {"T", "W", "i"} for symbol in symbols_for(width)):
                raise GateError(f"{binary} omitted a hosted complex entry")
            artifacts.update({path.name: sha256_file(path) for path in (obj, binary)})
    return artifacts


def build_stubs(directory, fixtures, runtime, project, record):
    directory.mkdir()
    for width in FORMATS:
        required = symbols_for(width)
        fixture = fixtures / f"complex-f{width}.o"
        for symbol in sorted(required):
            log = []
            item = record[symbol] = {"commands": log}
            spec = project.functions.get(symbol)
            if spec is None or spec.header != "complex.h":
                raise GateError(f"missing complex.h specification for {symbol}")
            wrapped, source_hash = generate_stub(spec, directory, log)
            binary = directory / symbol
            link_fixture(log, binary, fixture, runtime, required, stub=(symbol, wrapped))
            item.update(source_sha256=source_hash, object_sha256=sha256_file(wrapped),
                        executable_sha256=sha256_file(binary))


def validate(report):
    names = set().union(*(symbols_for(width) for width in FORMATS))
    stubs = report["stubs"]
    if (not report["passed"] or not report["inputs_frozen"] or set(stubs) != names or
            any(not result["rejected"] for result in stubs.values()) or
            set(report["results"]) != {"f32", "f64", "f80"}):
        raise GateError("incomplete complex evidence or a generated stub was accepted")
    totals, maxima = Counter(), {}
    host_differences = {}
    for kind, group in report["results"].items():
        if set(group) != set(OPERATIONS):
            raise GateError(f"complex {kind} omitted an operation")
        for operation, backends in group.items():
            required = {"native", "qemu", "gcc", "musl-gcc"}
            if kind != "f80":
                required.add("valgrind")
            if set(backends) != required:
                raise GateError(f"complex {kind} {operation} omitted a backend")
            for backend, result in backends.items():
                if result["records"] <= 0:
                    raise GateError(f"complex {kind} {operation} has no {backend} records")
                totals[backend] += result["records"]
                maxima[backend] = max(maxima.get(backend, 0), result.get("max_real_ulp", 0),
                                      result.get("max_imaginary_ulp", 0))
                if not result["passed"]:
                    if backend in {"native", "qemu", "valgrind"} or result.get("error"):
                        raise GateError(f"complex {kind} {operation} failed under {backend}")
                    host_differences[f"{kind}:{operation}:{backend}"] = result["failures_by_reason"]
    return dict(totals), maxima, host_differences


def execute():
    evidence = {"schema_version": 1, "scope": "phase7-complex", "production_verified": False,
                "outcome": "fail", "checks": {},
                "limits": ["Twenty-two complex families at three widths, sampled inputs.",
                           "Hosted differences and Memcheck's shared subset are reported separately."]}
    checks = evidence["checks"]
    try:
        project = load_project()
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64", "musl-gcc")
        evidence["mpfr"] = mpfr_identity()
        evidence["inputs"] = verify_setup(checks, False, snapshot=input_snapshot)
        workspace = BUILD / "phase7-complex"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            build = checks["build"] = {"outcome": "fail", "commands": []}
            log = build["commands"]
            runtimes = [build_runtime(directory / f"runtime-{n}", log) for n in (1, 2)]
            if runtimes[0][3] != runtimes[1][3]:
                raise GateError("isolated complex runtime builds differ")
            first, second = (directory / f"fixtures-{n}" for n in (1, 2))
            left = build_fixtures(first, runtimes[0], log)
            if left != build_fixtures(second, runtimes[1], log):
                raise GateError("isolated complex fixture builds differ")
            startup, archive, _, runtime_hashes = runtimes[0]
            hosts, stubs = directory / "hosts", directory / "stubs"
            build.update(outcome="pass", runtime_artifacts=runtime_hashes,
                         candidate_artifacts=left, hosted_artifacts=build_hosts(hosts, log))
            stub_record = checks["stubs"] = {"outcome": "fail", "symbols": {}}
            build_stubs(stubs, first, runtimes[0], project, stub_record["symbols"])
            sample = checks["sampled"] = {"outcome": "fail", "commands": []}
            target = directory / "sampled.json"
            try:
                checked(sample["commands"], ["python3", TESTS / "verify_complex.py", first, target,
                                             "--hosts", hosts, "--stubs", stubs,
                                             "--input", startup, "--input", archive], timeout=600)
            finally:
                if target.is_file():
                    data = json.loads(target.read_text())
                    saved = write_evidence("phase7-complex-sampled", data)
                    sample.update(evidence=str(saved), evidence_sha256=sha256_file(saved))
            totals, maxima, differences = validate(data)
            sample.update(outcome="pass", records=totals, max_component_ulp=maxima,
                          host_differences=differences)
            stub_record.update(outcome="pass", rejections=len(data["stubs"]))
            print(f"PASS sampled complex {totals}, {stub_record['rejections']} typed stubs", flush=True)
        if evidence["inputs"] != input_snapshot():
            raise GateError("inputs changed during complex verification")
        evidence["outcome"] = "pass"
    except (GateError, KeyError, OSError, SpecError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence("phase7-complex", evidence)
    print(f"phase7-complex evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute())

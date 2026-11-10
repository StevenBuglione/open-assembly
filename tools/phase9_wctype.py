"""Verify Phase 9 wide character functions against original Unicode 16 data."""

from pathlib import Path
import os
import shutil
import subprocess
import sys
import tempfile
from time import monotonic

from gate import BUILD, COMPILE_FLAGS, GateError, checked, identify_tools, source_policy, verify_setup, write_evidence
from phase1 import TEST_C_FLAGS, build_runtime, generate_stub, nm_symbols, phase1_inputs
from phase7_exact import link_fixture, require_symbols
from spec import ROOT, SpecError, load_project, sha256_file, snapshot_inputs

SUITE = Path("tests/phase9/wctype")
DATA = Path("spec/unicode/16.0.0")
sys.path.insert(0, str(ROOT / SUITE))
from oracle import CLASSES, LIMIT, SYMBOLS, make_records

PUBLIC = set(SYMBOLS)


def inputs():
    result = phase1_inputs()
    extra = [Path(__file__).relative_to(ROOT), Path("docs/adr/0012-c-utf8-multibyte.md"),
             *sorted(path for path in SUITE.iterdir() if path.is_file()),
             *sorted(path for path in DATA.iterdir() if path.is_file())]
    result.update(snapshot_inputs(ROOT, extra))
    return dict(sorted(result.items()))


def build_probe(directory, runtime, record):
    directory.mkdir()
    probe, obj = directory / "wctype", directory / "wctype.o"
    log = record["commands"]
    checked(log, ["gcc", *TEST_C_FLAGS, "-c", SUITE / "probe.c", "-o", obj])
    checked(log, ["tools/elf-audit", "--test-object", obj])
    require_symbols(log, obj, ["--undefined-only"], PUBLIC, "U")
    link_fixture(log, probe, obj, runtime, PUBLIC)
    record.update(outcome="pass", object_sha256=sha256_file(obj), executable_sha256=sha256_file(probe))
    return probe, obj


def build_host(compiler, directory, record):
    directory.mkdir()
    probe, obj = directory / "wctype", directory / "wctype.o"
    log = record["commands"]
    checked(log, [compiler, *COMPILE_FLAGS, "-DOA_PHASE9_HOST", "-c", SUITE / "probe.c", "-o", obj])
    checked(log, ["tools/elf-audit", "--test-object", obj])
    require_symbols(log, obj, ["--undefined-only"], PUBLIC, "U")
    checked(log, [compiler, "-static", "-no-pie", "-o", probe, obj])
    checked(log, ["tools/elf-audit", probe])
    defined = nm_symbols(log, probe, ["-g", "--defined-only"])
    if any(defined.get(symbol) not in {"T", "W", "i"} for symbol in PUBLIC):
        raise GateError(f"{compiler} omitted a public wide classification symbol")
    record.update(outcome="pass", object_sha256=sha256_file(obj), executable_sha256=sha256_file(probe))
    return probe


def observe(command, record, packets=None):
    command = list(map(str, command))
    began = monotonic()
    stream = open(packets, "rb") if packets is not None else open(os.devnull, "rb")
    with stream:
        result = subprocess.run(command, cwd=ROOT, stdin=stream, capture_output=True, timeout=300,
                                env={"LC_ALL": "C"})
    record.update(command=command, status=result.returncode, elapsed_seconds=monotonic() - began,
                  stdout=result.stdout.decode(errors="replace"), stderr=result.stderr.decode(errors="replace"))
    return result


def domain(probe, wrapper, locale, packets, expected, record, *, hosted_unicode=False):
    cmd = [*wrapper, probe.resolve(), locale]
    if hosted_unicode:
        cmd.append("compare")
    result = observe(cmd, record, packets)
    values = result.stdout.split()
    if result.returncode or len(values) != 5 + len(CLASSES) or not all(value.isdigit() for value in values):
        raise GateError(f"{locale} wide classification probe failed with status {result.returncode}")
    count, lower, upper, descriptors, errno, *classifications = map(int, values)
    if count != expected["rows"] or descriptors or errno:
        raise GateError(f"{locale} wide classification probe omitted rows or broke descriptor and errno rules")
    if not hosted_unicode and (lower or upper or any(classifications) or result.stderr):
        raise GateError(f"{locale} wide classification differed from the independent oracle")
    record.update(outcome="pass", rows=count, input_sha256=expected["sha256"],
                  executable_sha256=sha256_file(probe), mapping_differences={"lower": lower, "upper": upper},
                  classification_differences=dict(zip(CLASSES, classifications, strict=True)),
                  descriptor_differences=descriptors, errno_differences=errno)


def stubs(project, runtime, probe, obj, directory, record):
    directory.mkdir()
    for name in SYMBOLS:
        item = record[name] = {"outcome": "fail", "commands": [], "baseline": {}, "stub": {}}
        binary = directory / name
        wrapped, source_hash = generate_stub(project.functions[name], directory, item["commands"])
        link_fixture(item["commands"], binary, obj, runtime, PUBLIC, stub=(name, wrapped))
        baseline = observe([probe.resolve(), "direct", name], item["baseline"])
        rejected = observe([binary.resolve(), "direct", name], item["stub"])
        if ((baseline.returncode, baseline.stdout, baseline.stderr) != (0, b"", b"") or
                (rejected.returncode, rejected.stdout, rejected.stderr) != (1, b"", b"")):
            raise GateError(f"the directed oracle did not reject the typed {name} stub")
        item.update(outcome="pass", source_sha256=source_hash, object_sha256=sha256_file(wrapped),
                    executable_sha256=sha256_file(binary))


def execute():
    scope = "phase9-wctype"
    evidence = {"schema_version": 1, "scope": scope, "outcome": "fail", "production_verified": False,
                "checks": {}, "limits": ["Complete Unicode code-point domain for C.UTF-8.",
                                         "C locale ASCII and selected out-of-range cases.",
                                         "Host Unicode-version and locale policy differences are measured separately."]}
    checks = evidence["checks"]
    try:
        project = load_project()
        if not PUBLIC <= project.functions.keys() or any(
                project.functions[name].header != "wctype.h" for name in PUBLIC):
            raise GateError("the wide classification public inventory is incomplete")
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64", "musl-gcc")
        evidence["inputs"] = verify_setup(checks, False, snapshot=inputs)
        workspace = BUILD / scope
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            runtime = checks["runtime"] = {"outcome": "fail", "commands": []}
            first = build_runtime(directory / "runtime-1", runtime["commands"])
            second = build_runtime(directory / "runtime-2", runtime["commands"])
            if first[3] != second[3]:
                raise GateError("the two wide classification runtime builds differ")
            runtime.update(outcome="pass", artifacts=first[3])

            candidates = checks["candidate_build"] = [{"outcome": "fail", "commands": []} for _ in range(2)]
            probe, obj = build_probe(directory / "candidate-1", first, candidates[0])
            build_probe(directory / "candidate-2", second, candidates[1])
            for key in ("object_sha256", "executable_sha256"):
                if candidates[0][key] != candidates[1][key]:
                    raise GateError("the two wide classification probe builds differ")

            expected = directory / "oracle"
            expected.mkdir()
            identity, packets = make_records(DATA, expected)
            if packets["unicode"]["rows"] != LIMIT:
                raise GateError("incomplete Unicode oracle")
            checks["oracle"] = {"outcome": "pass", "unicode_version": "16.0.0",
                                "raw_files": identity, "packets": packets}
            controls = checks["stubs"] = {}
            stubs(project, first, probe, obj, directory / "stubs", controls)

            runs = checks["runs"] = {}
            runners = {"native": (), "qemu": (shutil.which("qemu-x86_64"),),
                       "valgrind": (shutil.which("valgrind"), "--quiet", "--error-exitcode=99")}
            for backend, wrapper in runners.items():
                runs[backend] = {}
                for sample, locale in (("c", "C"), ("unicode", "C.UTF-8"), ("invalid", "C.UTF-8")):
                    runs[backend][sample] = {"outcome": "fail"}
                    domain(probe, wrapper, locale, expected / f"{sample}.packets", packets[sample],
                           runs[backend][sample])
                print(f"PASS {backend} {LIMIT:,} Unicode code points and C-locale/invalid boundaries", flush=True)
            hosts = checks["host_build"] = {}
            for compiler in ("gcc", "musl-gcc"):
                item = hosts[compiler] = {"outcome": "fail", "commands": []}
                host = build_host(compiler, directory / compiler, item)
                runs[compiler] = {}
                for sample, locale in (("ascii", "C"), ("unicode", "C.UTF-8")):
                    runs[compiler][sample] = {"outcome": "fail"}
                    domain(host, (), locale, expected / f"{sample}.packets", packets[sample],
                           runs[compiler][sample], hosted_unicode=sample == "unicode")
            if any(sha256_file(expected / f"{name}.packets") != item["sha256"]
                   for name, item in packets.items()):
                raise GateError("the wide classification input stream changed")
        if evidence["inputs"] != inputs():
            raise GateError("inputs changed during the wide classification gate")
        evidence["outcome"] = "pass"
    except (GateError, KeyError, OSError, SpecError, ValueError, subprocess.SubprocessError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(scope, evidence)
    print(f"{scope} evidence {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute())

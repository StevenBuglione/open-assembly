"""Verify exact floating conversions, floating environments, and float stdio."""

from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from hashlib import sha256
import os
from pathlib import Path
import shutil
import sys
import tempfile
from time import monotonic

from gate import BUILD, COMPILE_FLAGS, GateError, checked, identify_tools, source_policy, verify_setup, write_evidence
from phase1 import Case, build_case, build_runtime, generate_stub, phase1_inputs
from phase4 import Probe, execute_probe, observation
from spec import ROOT, SpecError, load_project, sha256_file, snapshot_inputs

sys.path.insert(0, str(ROOT / "tests/phase5"))
from vectors import FORMATS, PACKET, SEED, corpus, fuzz_packets, gmpy2

FP_FLAGS = "Memcheck did not preserve the seeded floating status flag."
EXTENDED = "Memcheck rounded an extended-precision result to binary64."
VALUE_ONLY = "The native and QEMU cases verify the full floating environment."
FUZZ_SECONDS = 60
FUZZ_BATCH = 64
FENV_CASES = {
    "rounding": ("fegetround", "fesetround"),
    "exceptions": ("fetestexcept", "feclearexcept"),
    "flags": ("fegetexceptflag", "fesetexceptflag"),
    "restore": ("fegetenv", "fesetenv"),
    "hold": ("feholdexcept", "feupdateenv", "feraiseexcept"),
    "raise": ("feraiseexcept",),
}


def make_probe(name, source, requires, args, oracle, *, data=b"", stdout="", skips=None,
               host_skip="The fixture checks the declared AMD64 floating environment."):
    skips = skips or {}
    backends = tuple(name for name in ("native", "qemu", "valgrind") if name not in skips)
    case = Case(name, (Path(f"tests/phase5/{source}.c"),), tuple(requires), list(args), {},
                0, stdout, "", tuple(oracle), backends, skips)
    return Probe(case, data, stdout.encode(), b"", {}, (), host_skip)


def float_stdio():
    output = {
        "decimal": ("snprintf",), "rounding": ("snprintf",), "variadic": ("vsnprintf",),
        "hex": ("snprintf", "strtod", "strtold"), "special": ("snprintf",),
        "overflow": ("snprintf",), "stdout": ("printf", "vprintf"),
    }
    for mode, requires in output.items():
        extended = mode == "hex"
        yield make_probe("float-format-" + mode, "format", requires, [mode],
                         ["c17:float-format", "abi:sysv-amd64"],
                         stdout="+1.25|-2.50" if mode == "stdout" else "",
                         skips={"valgrind": EXTENDED} if extended else None,
                         host_skip="The candidate requires prompt checked count overflow." if mode == "overflow" else None)
    inputs = {
        "values": (("vsscanf",), b""),
        "rounding": (("sscanf",), b""),
        "fields": (("sscanf",), b""),
        "prefix": (("fscanf", "fgetc"), b"1e+Q NaN(payload_1)!"),
        "stdin": (("scanf", "vscanf"), b"1.5 -2.5"),
    }
    for mode, (requires, data) in inputs.items():
        yield make_probe("float-scan-" + mode, "scan", requires, [mode],
                         ["c17:float-scan", "abi:sysv-amd64"], data=data,
                         skips={"valgrind": EXTENDED} if mode == "values" else None,
                         host_skip="The candidate checks the project maximal subject and NaN payload policy."
                         if mode == "prefix" else None)


def record_probe(probe, binary, work, record, runners, expected=None):
    execute_probe(probe, binary, work, record, runners, expected)
    for backend in runners:
        item = record[backend]
        item.pop("stdin_hex")
        item["stdin_sha256"] = sha256(probe.input_bytes).hexdigest()
        item["stdin_bytes"] = len(probe.input_bytes)


def host_build(compiler, source, directory, commands):
    binary = directory / f"{compiler}-{source.stem}"
    if not binary.exists():
        checked(commands, [compiler, *COMPILE_FLAGS, "-DOA_PHASE5_HOST", "-static", "-no-pie",
                           "-o", binary, source])
        checked(commands, ["tools/elf-audit", binary])
    return binary


def build_probe(probe, directory, runtime, records, runners):
    case = probe.case
    item = {"outcome": "fail", "oracle": case.oracle, "required_symbols": case.requires,
            "host_skip": probe.host_skip, "skipped_backends": case.skip, "commands": [], "runs": {}}
    records[case.name] = item
    binary, first = build_case(case, directory / case.name, runtime[0], item["commands"])
    _, second = build_case(case, directory / (case.name + "-second"), runtime[1], item["commands"])
    item["artifacts"] = {"first": first, "second": second}
    if first != second:
        raise GateError(f"{case.name}: isolated builds differ")
    record_probe(probe, binary, directory / (case.name + "-inputs"), item["runs"],
                 {backend: runners[backend] for backend in case.backends})
    item["outcome"] = "pass"
    return binary, item


def host_probe(probe, directory, host_directory, item, variants=None):
    item["host_runs"] = {}
    for compiler, oracle in (("gcc", "diff:glibc"), ("musl-gcc", "diff:musl")):
        case = variants[oracle] if variants else probe
        binary = host_build(compiler, case.case.sources[0], host_directory, item["commands"])
        record_probe(case, binary, directory / (probe.case.name + "-" + compiler),
                     item["host_runs"], {oracle: []})
        item["host_runs"][oracle]["artifact_sha256"] = sha256_file(binary)


def mpfr_identity():
    library = Path(os.environ["OPEN_ASSEMBLY_MPFR"]).resolve(strict=True)
    extension = Path(gmpy2.gmpy2.__file__).resolve(strict=True)
    entries = Path("/proc/self/maps").read_text().splitlines()
    if not any(line.endswith(" " + str(library)) for line in entries):
        raise GateError("the Python oracle did not load the pinned MPFR library")
    log = []
    dynamic = checked(log, ["readelf", "-dW", library])
    if "(SONAME)" not in dynamic or "[libmpfr.so.6]" not in dynamic:
        raise GateError("unexpected MPFR library SONAME")
    return {
        "library": str(library), "sha256": sha256_file(library), "soname": "libmpfr.so.6",
        "version": gmpy2.mpfr_version(), "gmpy2_version": gmpy2.version(),
        "gmpy2_extension_sha256": sha256_file(extension), "commands": log,
    }


def phase5_inputs():
    hashes = phase1_inputs()
    inputs = [*(path for path in Path("tests/phase5").glob("*") if path.is_file()), Path("nix/float-vectors.nix"),
              Path("docs/adr/0006-exact-numerics.md"), Path(__file__).relative_to(ROOT)]
    hashes.update(snapshot_inputs(ROOT, inputs))
    return dict(sorted(hashes.items()))


def stub_controls(controls, directory, runtime, record):
    project = load_project()
    record["symbols"] = {}
    for symbol, (probe, expected) in controls.items():
        work = directory / f"stub-{symbol}"
        work.mkdir()
        item = {"outcome": "fail", "case": probe.case.name, "commands": [], "runs": {}}
        record["symbols"][symbol] = item
        obj, item["source_sha256"] = generate_stub(project.functions[symbol], work, item["commands"])
        binary, item["artifacts"] = build_case(probe.case, work / "probe", runtime,
                                                item["commands"], (symbol, obj))
        record_probe(probe, binary, work / "inputs", item["runs"], {f"stub:{symbol}": []}, expected)
        item["outcome"] = "pass"
    record["outcome"] = "pass"


def timed_campaign(kind, binary, directory, record):
    seed = SEED ^ FORMATS[kind].bits
    command = [binary.resolve(), kind]
    directory.mkdir()
    record.update(outcome="fail", seed=seed, minimum_seconds=FUZZ_SECONDS, batch_size=FUZZ_BATCH,
                  records=0, command=list(map(str, command)),
                  oracle=["reference:exact-rational", "reference:mpfr", "project:fp-effects"])
    packets = fuzz_packets(kind, seed, FUZZ_BATCH)
    stream = sha256()
    start = monotonic()
    expected = (0, f"{FUZZ_BATCH}\n".encode(), b"")
    while record["records"] < 4 * FUZZ_BATCH or monotonic() - start < FUZZ_SECONDS:
        data = next(packets)
        observed, run = observation(command, directory, data, {}, timeout=30)
        if observed != expected:
            record["failed_batch"] = run
            raise GateError(f"{kind} timed comparison failed at record {record['records']}: {observed!r}")
        stream.update(data)
        record["records"] += FUZZ_BATCH
    record.update(outcome="pass", elapsed_seconds=monotonic() - start,
                  stream_sha256=stream.hexdigest(), mpfr_crosschecks=record["records"])
    print(f"PASS {kind} timed differential {record['records']} records "
          f"in {record['elapsed_seconds']:.2f}s seed={seed:#x}", flush=True)


def execute_phase5():
    evidence = {"schema_version": 1, "scope": "phase5", "production_verified": False,
                "outcome": "fail", "checks": {}}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64", "musl-gcc")
        evidence["mpfr"] = mpfr_identity()
        evidence["inputs"] = verify_setup(checks, False, snapshot=phase5_inputs)
        runners = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
                   "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                "--leak-check=full", "--errors-for-leak-kinds=all"]}
        workspace = BUILD / "phase5"
        workspace.mkdir(parents=True, exist_ok=True)
        controls = {}
        parser_binaries = {}
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temp:
            directory = Path(temp).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            runtime_record = {"outcome": "fail", "commands": []}
            checks["runtime_build"] = runtime_record
            runtime = tuple(build_runtime(directory / name, runtime_record["commands"])
                            for name in ("first", "second"))
            runtime_record["artifacts"] = [result[3] for result in runtime]
            if runtime[0][3] != runtime[1][3]:
                raise GateError("two isolated Phase 5 runtime builds differ")
            runtime_record["outcome"] = "pass"
            host_directory = directory / "host"
            host_directory.mkdir()
            for kind, symbol in (("f32", "strtof"), ("f64", "strtod"),
                                 ("f80", "strtold"), ("atof", "atof")):
                data, metadata = corpus(kind)
                probe = make_probe("parse-" + kind, "parse", [symbol], [kind],
                                   ["reference:exact-rational", "reference:mpfr", "project:fp-effects"],
                                   data=data, stdout=f"{metadata['records']}\n",
                                   skips={"valgrind": EXTENDED if kind == "f80" else FP_FLAGS},
                                   host_skip=None)
                binary, item = build_probe(probe, directory, runtime, checks, runners)
                if kind != "atof":
                    parser_binaries[kind] = binary
                item["corpus"] = metadata
                host_case = replace(probe.case, args=[kind, "bits"])
                variants = {}
                item["host_corpus"] = {}
                for name in ("glibc", "musl"):
                    common_data, common = corpus(kind, compatible_host=name)
                    oracle = f"diff:{name}"
                    variants[oracle] = replace(probe, case=host_case, input_bytes=common_data,
                                               stdout=f"{common['records']}\n".encode())
                    item["host_corpus"][oracle] = common
                host_probe(probe, directory, host_directory, item, variants)
                if kind != "f80":
                    bits = make_probe("parse-" + kind + "-memcheck-bits", "parse", [symbol], [kind, "bits"],
                                      ["reference:exact-rational", "reference:mpfr"],
                                      data=data, stdout=f"{metadata['records']}\n",
                                      skips={"native": VALUE_ONLY, "qemu": VALUE_ONLY})
                    build_probe(bits, directory, runtime, checks, runners)
                first_length = PACKET.unpack_from(data)[0]
                status = 21 if kind == "atof" else 20
                controls[symbol] = (replace(probe, input_bytes=data[:PACKET.size + first_length]),
                                    (status, b"", f"record 0 status {status}\n".encode()))

            fenv_probes = {}
            for name, symbols in FENV_CASES.items():
                skips = None if name in ("rounding", "restore") else {
                    "valgrind": "Memcheck omits exception flags required by this hardware-state probe."}
                probe = make_probe("fenv-" + name, "fenv", symbols, [name],
                                   ["c17:fenv", "reference:x86-fp-state"], skips=skips)
                fenv_probes[name] = probe
                build_probe(probe, directory, runtime, checks, runners)
            for symbol, (name, status) in {
                "fegetround": ("rounding", 30), "fesetround": ("rounding", 31),
                "fetestexcept": ("exceptions", 40), "feclearexcept": ("exceptions", 42),
                "fegetexceptflag": ("flags", 51), "fesetexceptflag": ("flags", 53),
                "fegetenv": ("restore", 55), "fesetenv": ("restore", 57),
                "feholdexcept": ("hold", 61), "feupdateenv": ("hold", 65),
                "feraiseexcept": ("raise", 71),
            }.items():
                controls[symbol] = fenv_probes[name], (status, b"", b"")

            stdio_probes = {}
            for probe in float_stdio():
                _, item = build_probe(probe, directory, runtime, checks, runners)
                stdio_probes[probe.case.name] = probe
                if probe.host_skip is None:
                    host_probe(probe, directory, host_directory, item)
            for symbol, (name, status) in {
                "snprintf": ("float-format-decimal", 20), "vsnprintf": ("float-format-variadic", 25),
                "sscanf": ("float-scan-rounding", 43), "vsscanf": ("float-scan-values", 40),
            }.items():
                controls[symbol] = stdio_probes[name], (status, b"", b"")
            checks["stub_controls"] = {"outcome": "fail"}
            stub_controls(controls, directory, runtime[0], checks["stub_controls"])
            fuzz = {kind: {} for kind in parser_binaries}
            checks["timed_differential"] = fuzz
            with ThreadPoolExecutor(max_workers=len(fuzz)) as pool:
                runs = [pool.submit(timed_campaign, kind, binary, directory / (kind + "-fuzz"), fuzz[kind])
                        for kind, binary in parser_binaries.items()]
                for run in runs:
                    run.result()
        if evidence["inputs"] != phase5_inputs():
            raise GateError("inputs changed during Phase 5 verification")
        evidence["outcome"] = "pass"
    except (GateError, KeyError, OSError, SpecError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence("phase5", evidence)
    print(f"phase5 evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute_phase5())

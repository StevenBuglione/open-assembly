"""Verify Phase 4 byte streams, integer variadics, and assembly utilities."""

from dataclasses import dataclass
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

from gate import BUILD, COMPILE_FLAGS, GateError, checked, identify_tools, source_policy, verify_setup, write_evidence
from phase1 import BACKENDS, Case, build_case, build_runtime, expected_result, generate_stub, phase1_inputs
from spec import (IDENTIFIER, ROOT, SpecError, keys, load_project, matching, read_toml,
                  regular_file, relative_path, sha256_file, snapshot_inputs, string_list, version_one)

MANIFEST = Path("tests/phase4/manifest.toml")
APPS = {Path("apps/cat/main.asm"), Path("apps/wc/main.asm")}
FAULT = Path("tests/phase4/fault.c")
LIBC_TEST_PIN = "63e36e934e8f2bedf645303a90b64098e2af6c8f"
LIBC_TEST_CASES = {
    "scanf-bytes-consumed": ("sscanf",),
    "scanf-nullbyte-char": ("sscanf",),
    "scanf-match-literal-eof": ("sscanf",),
    "setvbuf-unget": ("setvbuf", "ungetc"),
}


@dataclass(frozen=True)
class Probe:
    case: Case
    input_bytes: bytes
    stdout: bytes
    stderr: bytes
    files: dict[str, bytes]
    wraps: tuple[str, ...]
    host_skip: str | None


def decode_hex(value, where):
    if type(value) is not str or not re.fullmatch(r"(?:[0-9a-f]{2})*", value):
        raise GateError(f"{where}: expected lowercase byte pairs")
    return bytes.fromhex(value)


def parse_probe(table, where):
    fields = set(Case.__dataclass_fields__) - {"skip"}
    keys(table, fields | {"stdin_hex"}, where,
         ("skip", "stdout_hex", "files", "link_wraps", "host", "host_skip"))
    name = matching(table["name"], r"[a-z][a-z0-9-]*", where)
    sources = tuple(relative_path(path, where) for path in
                    string_list(table["sources"], r".+", where, nonempty=True))
    for source in sources:
        if source not in APPS and (source.parts[:2] != ("tests", "phase4") or source.suffix != ".c"):
            raise GateError(f"{where}: invalid Phase 4 fixture source {source}")
        regular_file(ROOT, source, where)
    requires = string_list(table["requires"], IDENTIFIER, where, nonempty=True)
    oracle = string_list(table["oracle"], r"[a-z][a-z0-9_-]*:[A-Za-z0-9_./+-]+", where, nonempty=True)
    backends = string_list(table["backends"], r"native|qemu|valgrind", where, nonempty=True)
    skip = table.get("skip", {})
    if (type(skip) is not dict or set(skip) != BACKENDS - set(backends)
            or any(type(reason) is not str or not reason.strip() for reason in skip.values())):
        raise GateError(f"{where}: every omitted backend needs a reason")
    args, env = table["args"], table["env"]
    if type(args) is not list or any(type(arg) is not str or "\0" in arg for arg in args):
        raise GateError(f"{where}: expected argument strings")
    if type(env) is not dict or any(not re.fullmatch(IDENTIFIER, key) or type(value) is not str
                                    or "\0" in value for key, value in env.items()):
        raise GateError(f"{where}: invalid environment")
    status, stdout, stderr = expected_result(table, where)
    output = stdout.encode()
    if "stdout_hex" in table:
        if output:
            raise GateError(f"{where}: specify only one stdout representation")
        output = decode_hex(table["stdout_hex"], where)
    files = table.get("files", {})
    if type(files) is not dict or any(not re.fullmatch(r"[-A-Za-z0-9][A-Za-z0-9_.-]*", file) for file in files):
        raise GateError(f"{where}: expected simple fixture filenames")
    if files and not all(source in APPS for source in sources):
        raise GateError(f"{where}: only utility cases may use operand files")
    files = {file: decode_hex(value, where) for file, value in files.items()}
    wraps = tuple(string_list(table.get("link_wraps", []), IDENTIFIER, where))
    if wraps != (("__al_syscall",) if FAULT in sources else ()):
        raise GateError(f"{where}: only the designated fault fixture wraps the syscall boundary")
    host_skip = table.get("host_skip")
    if table.get("host") is True:
        if host_skip is not None or wraps or any(source.suffix != ".c" for source in sources):
            raise GateError(f"{where}: host comparisons require ordinary C fixtures")
    elif "host" in table or type(host_skip) is not str or not host_skip.strip():
        raise GateError(f"{where}: expected a host comparison or a reason for omission")
    case = Case(name, sources, requires, args, env, status, stdout, stderr, oracle, backends, skip)
    return Probe(case, decode_hex(table["stdin_hex"], where), output, stderr.encode(), files, wraps, host_skip)


def load_manifest():
    document = read_toml(regular_file(ROOT, MANIFEST, "Phase 4 manifest"))
    keys(document, {"schema", "case", "stub"}, MANIFEST)
    version_one(document["schema"], MANIFEST)
    if type(document["case"]) is not list or type(document["stub"]) is not list:
        raise GateError(f"{MANIFEST}: expected case and stub arrays")
    probes = {}
    for index, table in enumerate(document["case"], 1):
        probe = parse_probe(table, f"{MANIFEST}: case {index}")
        if probe.case.name in probes:
            raise GateError(f"{MANIFEST}: duplicate case {probe.case.name}")
        probes[probe.case.name] = probe
    if {source for probe in probes.values() for source in probe.case.sources} & APPS != APPS:
        raise GateError(f"{MANIFEST}: both assembly utilities must be exercised")
    public = {path.stem for path in Path("spec/functions/stdio").glob("*.toml")}
    if not public:
        raise GateError("missing Phase 4 stdio specifications")
    stubs = {}
    for index, table in enumerate(document["stub"], 1):
        where = f"{MANIFEST}: stub {index}"
        keys(table, {"symbol", "case", "status", "stdout", "stderr"}, where)
        symbol = matching(table["symbol"], IDENTIFIER, where)
        case_name = matching(table["case"], r"[a-z][a-z0-9-]*", where)
        if symbol not in public or symbol in stubs or case_name not in probes:
            raise GateError(f"{where}: expected a unique stdio symbol and existing case")
        probe = probes[case_name]
        if symbol not in probe.case.requires or "native" not in probe.case.backends:
            raise GateError(f"{where}: selected native case must exercise {symbol}")
        status, stdout, stderr = expected_result(table, where)
        expected = status, stdout.encode(), stderr.encode()
        if expected == (probe.case.status, probe.stdout, probe.stderr):
            raise GateError(f"{where}: stub must differ from the production result")
        stubs[symbol] = probe, expected
    if stubs.keys() != public:
        raise GateError("missing Phase 4 generated stubs: " + ", ".join(sorted(public - stubs.keys())))
    return probes.values(), stubs


def observation(command, cwd, input_bytes, environment, timeout=30):
    command = list(map(str, command))
    try:
        result = subprocess.run(command, input=input_bytes, cwd=cwd, env=environment,
                                capture_output=True, timeout=timeout)
    except subprocess.TimeoutExpired as error:
        raise GateError(f"{' '.join(command)} exceeded {timeout} seconds") from error
    observed = result.returncode, result.stdout, result.stderr
    return observed, {
        "command": command, "cwd": str(cwd), "returncode": result.returncode,
        "stdin_hex": input_bytes.hex(), "stdout_hex": result.stdout.hex(),
        "stderr": result.stderr.decode(errors="replace"),
    }


def execute_probe(probe, binary, work, record, runners, expected=None):
    work.mkdir()
    for name, contents in probe.files.items():
        (work / name).write_bytes(contents)
    if expected is None:
        expected = probe.case.status, probe.stdout, probe.stderr
    for backend, wrapper in runners.items():
        command = [*wrapper, Path(binary).resolve(), *probe.case.args]
        observed, run = observation(command, work, probe.input_bytes, probe.case.env)
        match = observed == expected
        record[backend] = {**run, "outcome": "pass" if match else "fail"}
        if not match:
            raise GateError(f"{probe.case.name} under {backend}: expected {expected!r}, got {observed!r}")
        print(f"PASS {probe.case.name} {backend}", flush=True)


def host_binary(compiler, sources, directory, commands):
    binary = directory / (compiler + "-" + sources[0].stem)
    if not binary.exists():
        checked(commands, [compiler, *COMPILE_FLAGS, "-DOA_PHASE4_HOST", "-static", "-no-pie",
                           "-o", binary, *sources])
        checked(commands, ["tools/elf-audit", binary])
    return binary


def libc_test(directory, runtime, runners, record):
    path = os.environ.get("OPEN_ASSEMBLY_LIBC_TEST")
    if not path:
        raise GateError("the pinned toolchain did not provide the libc-test source")
    root = Path(path)
    copyright_file = root / "COPYRIGHT"
    header = root / "src/common/test.h"
    if "MIT license" not in copyright_file.read_text() or LIBC_TEST_PIN not in Path("nix/libc-test.nix").read_text():
        raise GateError("unexpected libc-test license or pin")
    record.update(pin=LIBC_TEST_PIN, copyright_sha256=sha256_file(copyright_file),
                  header_sha256=sha256_file(header), cases={})
    for name, requires in LIBC_TEST_CASES.items():
        original = root / "src/regression" / (name + ".c")
        fixture_directory = directory / name
        fixture_directory.mkdir(parents=True)
        source = fixture_directory / original.name
        shutil.copyfile(original, source)
        shutil.copyfile(header, fixture_directory / header.name)
        case = Case("libc-test-" + name, (source, Path("tests/phase4/libc_test_support.c")),
                    requires, [], {}, 0, "", "", ("suite:libc-test",), tuple(runners), {})
        probe = Probe(case, b"", b"", b"", {}, (), "The upstream assertions are the oracle.")
        item = {"outcome": "fail", "source_sha256": sha256_file(original), "commands": [], "runs": {}}
        record["cases"][name] = item
        binary, item["artifacts"] = build_case(case, fixture_directory / "link", runtime, item["commands"])
        execute_probe(probe, binary, fixture_directory / "inputs", item["runs"], runners)
        item["outcome"] = "pass"
    record["outcome"] = "pass"


def phase4_inputs():
    hashes = phase1_inputs()
    paths = [*Path("tests/phase4").glob("*"), *APPS, Path("nix/libc-test.nix"),
             Path("docs/adr/0005-stdio-varargs.md"), Path(__file__).relative_to(ROOT)]
    hashes.update(snapshot_inputs(ROOT, paths))
    return dict(sorted(hashes.items()))


def execute_phase4():
    evidence = {"schema_version": 1, "scope": "phase4", "production_verified": False,
                "outcome": "fail", "checks": {}}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64", "musl-gcc")
        evidence["inputs"] = verify_setup(checks, False, snapshot=phase4_inputs)
        probes, controls = load_manifest()
        runners = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
                   "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                "--leak-check=full", "--errors-for-leak-kinds=all"]}
        workspace = BUILD / "phase4"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temp:
            directory = Path(temp).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            runtime = {"outcome": "fail", "commands": []}
            checks["runtime_build"] = runtime
            first = build_runtime(directory / "first", runtime["commands"])
            second = build_runtime(directory / "second", runtime["commands"])
            runtime["artifacts"] = {"first": first[3], "second": second[3]}
            if first[3] != second[3]:
                raise GateError("two isolated Phase 4 runtime builds differ")
            runtime["outcome"] = "pass"
            apps = {"outcome": "fail", "commands": [], "artifacts": {}}
            checks["utility_build"] = apps
            for label in ("first", "second"):
                output = directory / label
                checked(apps["commands"], ["make", "--no-print-directory", "apps",
                                          f"RUNTIME_BUILD={output}"], timeout=60)
                apps["artifacts"][label] = {source.parent.name: sha256_file(output / "apps" / source.parent.name)
                                            for source in sorted(APPS)}
            if apps["artifacts"]["first"] != apps["artifacts"]["second"]:
                raise GateError("two isolated utility builds differ")
            apps["outcome"] = "pass"
            host_directory = directory / "host"
            host_directory.mkdir()
            for probe in probes:
                case = probe.case
                item = {"outcome": "fail", "oracle": case.oracle, "required_symbols": case.requires,
                        "link_wraps": probe.wraps, "commands": [], "runs": {}, "host_runs": {},
                        "host_skip": probe.host_skip, "skipped_backends": case.skip,
                        "fixture_files": {name: value.hex() for name, value in probe.files.items()},
                        "expected": {"status": case.status, "stdout_hex": probe.stdout.hex(),
                                     "stderr": case.stderr}}
                checks[case.name] = item
                binary, hashes = build_case(case, directory / case.name, first, item["commands"],
                                            link_wraps=probe.wraps)
                _, repeated = build_case(case, directory / (case.name + "-second"), second,
                                         item["commands"], link_wraps=probe.wraps)
                item["artifacts"] = {"first": hashes, "second": repeated}
                if hashes != repeated:
                    raise GateError(f"{case.name}: isolated fixture builds differ")
                if len(case.sources) == 1 and case.sources[0] in APPS:
                    name = case.sources[0].parent.name
                    shipped = directory / "first" / "apps" / name
                    if sha256_file(binary) != apps["artifacts"]["first"][name]:
                        raise GateError(f"{case.name}: probe link differs from the built utility")
                    binary = shipped
                execute_probe(probe, binary, directory / (case.name + "-inputs"), item["runs"],
                              {backend: runners[backend] for backend in case.backends})
                if probe.host_skip is None:
                    for compiler, oracle in (("gcc", "diff:glibc"), ("musl-gcc", "diff:musl")):
                        host = host_binary(compiler, case.sources, host_directory, item["commands"])
                        execute_probe(probe, host, directory / (case.name + "-" + compiler),
                                      item["host_runs"], {oracle: []})
                        item["host_runs"][oracle]["artifact_sha256"] = sha256_file(host)
                item["outcome"] = "pass"

            checks["libc_test"] = {"outcome": "fail"}
            libc_test(directory / "upstream", first, runners, checks["libc_test"])
            checks["stub_controls"] = {"outcome": "fail", "symbols": {}}
            project = load_project()
            for symbol, (probe, expected) in controls.items():
                work = directory / f"stub-{symbol}"
                work.mkdir()
                item = {"outcome": "fail", "case": probe.case.name, "oracle": probe.case.oracle,
                        "expected_rejection": [expected[0], expected[1].hex(), expected[2].hex()],
                        "commands": [], "runs": {}}
                checks["stub_controls"]["symbols"][symbol] = item
                obj, item["source_sha256"] = generate_stub(project.functions[symbol], work, item["commands"])
                binary, item["artifacts"] = build_case(probe.case, work / "probe", first,
                                                        item["commands"], (symbol, obj),
                                                        link_wraps=probe.wraps)
                execute_probe(probe, binary, work / "inputs", item["runs"], {f"stub:{symbol}": []}, expected)
                item["outcome"] = "pass"
            checks["stub_controls"]["outcome"] = "pass"
        if evidence["inputs"] != phase4_inputs():
            raise GateError("inputs changed during Phase 4 verification")
        evidence["outcome"] = "pass"
    except (GateError, KeyError, OSError, SpecError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence("phase4", evidence)
    print(f"phase4 evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute_phase4())

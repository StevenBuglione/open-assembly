"""Run the unmodified definite JSONTestSuite cases against the extension."""

import errno
import os
from pathlib import Path
from hashlib import sha256
import shutil
import struct
import subprocess
import sys
import tarfile
import tempfile

from extension_build import build_extension, dependency_order
from extensions import extension_sources, load_packages
from gate import BUILD, GateError, identify_tools, source_policy, verify_setup, write_evidence
from phase1 import Case, build_case, generate_stub, phase1_inputs
from spec import ROOT, SpecError, load_project, sha256_file

SCOPE = "extension-json-upstream"
PIN = "1ef36fa01286573e846ac449e8683f8833c5b26a"
SHA256 = "32ab2fb37cc26679dbd9164dbb7053bcef10134643d53cb0cef45de7680dcdcc"
COUNTS = {"y_": 95, "n_": 188, "i_": 35}


def load_suite(path, checks):
    if sha256_file(path) != SHA256:
        raise GateError("JSONTestSuite archive hash differs from the pin")
    cases = {}
    prefix = f"JSONTestSuite-{PIN}/test_parsing/"
    with tarfile.open(path, "r:gz") as archive:
        license_file = archive.extractfile(f"JSONTestSuite-{PIN}/LICENSE")
        if license_file is None:
            raise GateError("missing JSONTestSuite license")
        checks.update(pin=PIN, archive_sha256=SHA256,
                      license_sha256=sha256(license_file.read()).hexdigest())
        for member in archive:
            if not member.name.startswith(prefix) or not member.isfile():
                continue
            name = member.name.removeprefix(prefix)
            if name in cases or "/" in name or name[:2] not in COUNTS or member.size > (1 << 18):
                raise GateError(f"invalid JSONTestSuite fixture {name!r}")
            with archive.extractfile(member) as stream:
                cases[name] = stream.read()
    if {kind: sum(name.startswith(kind) for name in cases) for kind in COUNTS} != COUNTS:
        raise GateError("JSONTestSuite case inventory differs from the pin")
    cases = dict(sorted(cases.items()))
    checks["cases"] = {name: {"bytes": len(data), "sha256": sha256(data).hexdigest()}
                       for name, data in cases.items()}
    checks["implementation_defined"] = [name for name in cases if name.startswith("i_")]
    checks["outcome"] = "pass"
    return {name: data for name, data in cases.items() if not name.startswith("i_")}


def observe(command, cases):
    payload = b"".join(struct.pack("<I", len(data)) + data for data in cases.values())
    process = subprocess.run(command, input=payload, capture_output=True, env={}, timeout=60)
    if process.returncode or process.stderr or len(process.stdout) != len(cases) * 8:
        raise GateError(f"JSONTestSuite process failed: {process.returncode}, "
                        f"{len(process.stdout)} output bytes, {process.stderr[:256]!r}")
    return {name: value for name, (value,) in zip(cases, struct.iter_unpack("<q", process.stdout))}


def run_suite(report):
    checks = report["checks"]
    report["toolchain"] = identify_tools("ar", "make", "qemu-x86_64")
    report["inputs"] = verify_setup(checks, False, snapshot=phase1_inputs)
    path = os.environ.get("OPEN_ASSEMBLY_JSON_TESTS")
    if not path:
        raise GateError("OPEN_ASSEMBLY_JSON_TESTS must identify the pinned toolchain input")
    cases = load_suite(Path(path), checks.setdefault("upstream", {"outcome": "fail"}))
    project = load_project()
    packages = load_packages(project)
    sources = extension_sources(project, packages)
    closure = dependency_order(packages, "json")
    oracle = ("external:jsontestsuite",)
    runners = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
               "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                            "--leak-check=full", "--errors-for-leak-kinds=all"]}
    fixture = Case("json-upstream", (Path("tests/ext/json/upstream.c"),), ("json_parse",), [], {},
                   0, "", "", oracle, tuple(runners), {})
    with tempfile.TemporaryDirectory(dir=BUILD, prefix=f"{SCOPE}-") as temporary:
        work = Path(temporary).resolve().relative_to(ROOT)
        source_policy(checks, work)
        build = checks["build"] = {"outcome": "fail", "commands": []}
        binaries = []
        for label in ("first", "second"):
            runtime = build_extension(work / f"{label}-runtime", closure, sources, build["commands"])
            binary, artifacts = build_case(fixture, work / label, runtime, build["commands"])
            build[label] = {"runtime": runtime[3], "fixture": artifacts}
            binaries.append((runtime, binary))
        if build["first"] != build["second"]:
            raise GateError("two independently linked JSONTestSuite fixtures differ")
        build["outcome"] = "pass"
        runtime, binary = binaries[0]
        backends = checks["backends"] = {}
        for backend, prefix in runners.items():
            values = observe([*prefix, binary.resolve()], cases)
            failures = [name for name, value in values.items()
                        if (value <= 0 if name.startswith("y_") else value != -errno.EILSEQ)]
            backends[backend] = {"outcome": "fail" if failures else "pass",
                                 "values": values, "failed": failures}
            if failures:
                raise GateError(f"{backend}: JSONTestSuite disagreed on {failures[0]}")
            print(f"PASS {SCOPE} {backend}: {len(values)} definite cases", flush=True)
        stub = checks["stub"] = {"outcome": "fail", "commands": []}
        stub_dir = work / "stub"
        stub_dir.mkdir()
        obj, stub["source_sha256"] = generate_stub(packages["json"].functions["json_parse"], stub_dir,
                                                   stub["commands"])
        target, stub["artifacts"] = build_case(fixture, work / "negative", runtime, stub["commands"],
                                               ("json_parse", obj))
        values = observe([target.resolve()], cases)
        if any(value != 0 for value in values.values()):
            raise GateError("the generated zero stub did not yield the expected semantic result")
        stub.update(outcome="pass", rejected=len(values), observed_status=0)
    if report["inputs"] != phase1_inputs() or sha256_file(Path(path)) != SHA256:
        raise GateError("inputs changed during the JSONTestSuite replay")


def main():
    evidence = {"schema_version": 1, "scope": SCOPE, "production_verified": False,
                "outcome": "fail", "checks": {}}
    try:
        run_suite(evidence)
        evidence["outcome"] = "pass"
    except (GateError, OSError, SpecError, ValueError, KeyError, tarfile.TarError,
            subprocess.SubprocessError) as error:
        evidence["error"] = str(error)
        print(f"{SCOPE}: {error}", file=sys.stderr)
    print(f"{SCOPE} evidence: {write_evidence(SCOPE, evidence)}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    sys.exit(main())

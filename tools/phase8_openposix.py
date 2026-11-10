"""Run selected, unmodified Open POSIX tests against the static runtime."""

import hashlib
import os
from pathlib import Path
import re
import shutil
import sys
import tarfile
import tempfile

from gate import BUILD, GateError, identify_tools, run, source_policy, verify_setup, write_evidence
from phase1 import Case, build_case, build_runtime
from phase8 import inputs
from spec import IDENTIFIER, ROOT, SpecError, keys, read_toml, sha256_file, string_list, version_one

SUITE = Path("tests/phase8/openposix")
MANIFEST = SUITE / "manifest.toml"
SCOPE = "phase8-openposix"


def digest(value, size):
    if type(value) is not str or not re.fullmatch(rf"[0-9a-f]{{{size}}}", value):
        raise GateError(f"{MANIFEST}: invalid digest")
    return value


def copy_member(archive, prefix, member, expected, destination):
    info = archive.getmember(f"{prefix}/{member}")
    if not info.isfile() or info.size > 256 * 1024:
        raise GateError(f"invalid upstream test file {member}")
    with archive.extractfile(info) as source:
        contents = source.read()
    if hashlib.sha256(contents).hexdigest() != expected:
        raise GateError(f"upstream test hash mismatch for {member}")
    destination.write_bytes(contents)


def load_cases(source, directory, evidence):
    manifest = read_toml(MANIFEST)
    keys(manifest, {"schema", "release", "revision", "archive_sha256", "notice_sha256",
                    "header_sha256", "case"}, MANIFEST)
    version_one(manifest["schema"], MANIFEST)
    revision = digest(manifest["revision"], 40)
    compressed = digest(manifest["archive_sha256"], 64)
    if sha256_file(source) != compressed:
        raise GateError("upstream Open POSIX archive hash mismatch")
    prefix = f"ltp-{revision}/testcases/open_posix_testsuite"
    evidence["external"] = {"release": manifest["release"], "revision": revision,
                            "archive_sha256": compressed, "notice_sha256": manifest["notice_sha256"],
                            "header_sha256": manifest["header_sha256"]}
    if type(manifest["case"]) is not list:
        raise GateError(f"{MANIFEST}: case must be an array of tables")
    if type(manifest["release"]) is not str or not re.fullmatch(r"[0-9]{8}", manifest["release"]):
        raise GateError(f"{MANIFEST}: invalid release")
    cases = {}
    with tarfile.open(source, mode="r:gz") as archive:
        copy_member(archive, prefix, "COPYING", digest(manifest["notice_sha256"], 64), directory / "COPYING")
        copy_member(archive, prefix, "include/posixtest.h", digest(manifest["header_sha256"], 64),
                    directory / "posixtest.h")
        for row in manifest["case"]:
            keys(row, {"path", "sha256", "requires", "stdout"}, MANIFEST)
            path = row["path"]
            if type(path) is not str or not re.fullmatch(
                    r"conformance/interfaces/pthread_[a-z_]+/[0-9]+-[0-9]+\.c", path):
                raise GateError(f"{MANIFEST}: invalid upstream test path")
            name = "-".join(Path(path).with_suffix("").parts[-2:])
            if name in cases or type(row["stdout"]) is not str:
                raise GateError(f"{MANIFEST}: invalid or duplicate test {name}")
            fixture = directory / f"{name}.c"
            copy_member(archive, prefix, path, digest(row["sha256"], 64), fixture)
            required = string_list(row["requires"], IDENTIFIER, f"{MANIFEST}: {name} requires", nonempty=True)
            if not required or any(not symbol.startswith("pthread_") for symbol in required):
                raise GateError(f"{MANIFEST}: invalid thread requirements for {name}")
            cases[name] = (Case(name, (SUITE / "driver.c", fixture), required, [], {}, 0,
                                row["stdout"], "", ("reference:open-posix",),
                                ("native", "qemu", "valgrind"), {}), row)
    if not cases:
        raise GateError(f"{MANIFEST}: no tests")
    return cases


def execute():
    evidence = {"schema_version": 1, "scope": SCOPE, "production_verified": False,
                "outcome": "fail", "checks": {}}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64")
        evidence["inputs"] = verify_setup(checks, False, snapshot=inputs)
        source = Path(os.environ["OPEN_ASSEMBLY_OPEN_POSIX"])
        workspace = BUILD / SCOPE
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as work:
            directory = Path(work).resolve().relative_to(ROOT)
            upstream = directory / "upstream"
            upstream.mkdir()
            cases = load_cases(source, upstream, evidence)
            source_policy(checks, directory)
            runtime = {"outcome": "fail", "commands": []}
            checks["runtime_build"] = runtime
            first = build_runtime(directory / "first", runtime["commands"])
            second = build_runtime(directory / "second", runtime["commands"])
            runtime["artifacts"] = {"first": first[3], "second": second[3]}
            if first[3] != second[3]:
                raise GateError("isolated runtime builds differ")
            runtime["outcome"] = "pass"
            checks["cases"] = {}
            runners = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
                       "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                    "--leak-check=full", "--errors-for-leak-kinds=all"]}
            for name, (case, row) in cases.items():
                item = {"outcome": "fail", "upstream": row, "commands": [], "runs": {}}
                checks["cases"][name] = item
                binary, artifacts = build_case(case, directory / (name + "-first"), first,
                                               item["commands"], c_include=(upstream,))
                _, repeated = build_case(case, directory / (name + "-second"), second,
                                         item["commands"], c_include=(upstream,))
                item["artifacts"] = {"first": artifacts, "second": repeated}
                if artifacts != repeated:
                    raise GateError(f"{name}: isolated fixture builds differ")
                for backend, runner in runners.items():
                    result = run([*runner, binary], timeout=30)
                    item["runs"][backend] = result
                    observed = (result["returncode"], result["stdout"], result["stderr"])
                    if observed != (case.status, case.stdout, case.stderr):
                        raise GateError(f"{name} {backend}: unexpected Open POSIX result {observed!r}")
                    print(f"PASS {name} {backend}", flush=True)
                item["outcome"] = "pass"
        if evidence["inputs"] != inputs() or sha256_file(source) != evidence["external"]["archive_sha256"]:
            raise GateError("inputs changed during Open POSIX verification")
        evidence["outcome"] = "pass"
    except (GateError, KeyError, OSError, SpecError, ValueError, tarfile.TarError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(SCOPE, evidence)
    print(f"{SCOPE} evidence {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute())

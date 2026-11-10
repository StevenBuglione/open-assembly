"""Replay unmodified pinned libc-test socket, address and pattern cases."""

from pathlib import Path
import shutil
import sys
import tempfile

from gate import BUILD, GateError, identify_tools, source_policy, verify_setup, write_evidence
from phase1 import build_runtime
from phase4 import libc_test
from phase6 import phase6_inputs
from spec import ROOT, SpecError, load_project, snapshot_inputs

SCOPE = "phase10-libc-test"
CASES = {
    "functional-fnmatch": ("functional/fnmatch.c", ("fnmatch",)),
    "functional-inet-pton": ("functional/inet_pton.c", ("inet_addr", "inet_ntoa", "inet_pton", "inet_ntop")),
    "functional-socket": ("functional/socket.c", (
        "socket", "bind", "getsockname", "setsockopt", "htonl", "sendto", "recvfrom",
        "fcntl", "listen", "connect", "accept", "close",
    )),
    "regression-inet-pton-empty-last-field": ("regression/inet_pton-empty-last-field.c", ("inet_pton",)),
}
ORIGINALS = {
    "functional-fnmatch": "c91a6b7dce4cd09f52b0fb55ccb8408ef2d8194320732a2e58725929940809e3",
    "functional-inet-pton": "59907245422d8f7d167658b03912b19eca793040ed7eac17ee0a30604ea6125b",
    "functional-socket": "0d4bf1f5a6030c378dddfa5efd24bdd10a8488bdde76cdddb06532c346b6eb2e",
    "regression-inet-pton-empty-last-field": "3f2f33fb1f08def6753cf639cb40240273386ef5eea905ec6ad8c2a5db88a513",
}


def inputs():
    bound = phase6_inputs()
    contracts = [Path("docs/adr") / name for name in (
        "0013-linux-sockets-readiness.md", "0015-numeric-addresses.md",
        "0034-legacy-ipv4-addresses.md",
    )]
    bound.update(snapshot_inputs(ROOT, contracts))
    return dict(sorted(bound.items()))


def execute():
    evidence = {"schema_version": 1, "scope": SCOPE, "outcome": "fail", "production_verified": False,
                "checks": {}, "limits": ["Four unchanged libc-test cases in the current Phase 10 scope."]}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64")
        evidence["inputs"] = verify_setup(checks, False, snapshot=inputs)
        project = load_project()
        required = {symbol for _, symbols in CASES.values() for symbol in symbols}
        missing = sorted(required - project.functions.keys())
        if missing:
            raise GateError("the pinned libc-test scope is missing specifications for " + ", ".join(missing))
        runners = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
                   "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                "--leak-check=full", "--errors-for-leak-kinds=all"]}
        workspace = BUILD / SCOPE
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as scratch:
            directory = Path(scratch).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            runtime = checks["runtime_build"] = {"outcome": "fail", "commands": []}
            first = build_runtime(directory / "runtime-1", runtime["commands"])
            second = build_runtime(directory / "runtime-2", runtime["commands"])
            if first[3] != second[3]:
                raise GateError("isolated Phase 10 libc-test runtime builds differ")
            runtime.update(outcome="pass", artifacts=first[3])
            external = checks["external_conformance"] = {"outcome": "fail"}
            libc_test(directory / "libc-test", first, runners, external,
                      cases=CASES, c_flags=("-D_XOPEN_SOURCE=700", "-Wno-error=sign-compare"))
            if {name: item["source_sha256"] for name, item in external["cases"].items()} != ORIGINALS:
                external["outcome"] = "fail"
                raise GateError("libc-test original source hashes differ")
        if evidence["inputs"] != inputs():
            raise GateError("inputs changed during Phase 10 libc-test verification")
        evidence["outcome"] = "pass"
        print(f"PASS {SCOPE}", flush=True)
    except (GateError, OSError, SpecError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(SCOPE, evidence)
    print(f"{SCOPE} evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute())

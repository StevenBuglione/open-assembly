"""Reproduce the tier session clash with the unchanged fcntl sentinel fixture.

This is a causal harness preflight, not a full function or milestone gate.
Both boundaries execute the same audited archive-only ELF and assertions.
"""

from functools import partial
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from time import time_ns

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from gate import GateError, identify_tools, verify_setup
from phase1 import build_case, build_runtime, generate_stub, phase1_inputs
from phase4 import load_probes, parse_probe
from phase6 import FCNTL, SUITE
from spec import load_project, sha256_file
from tier_process import subreaper_state
from verify_tiers import invoke


def main():
    root = Path("build/fcntl-tier-session") / str(time_ns())
    root.mkdir(parents=True)
    checks = {}
    record = {"schema_version": 1, "scope": "fcntl-tier-session-causal-preflight",
              "outcome": "fail", "production_verified": False, "full_gate_executed": False,
              "artifact_directory": str(root), "checks": checks,
              "driver": {"pid": os.getpid(), "group": os.getpgrp(), "session": os.getsid(0),
                         "subreaper_before": subreaper_state(), "kernel": os.uname().release}}
    report = Path("build/author/fcntl-tier-session-preflight.json")
    try:
        record["inputs"] = verify_setup(checks, False, snapshot=phase1_inputs)
        record["toolchain"] = identify_tools("ar", "qemu-x86_64")
        probes, _ = load_probes(SUITE / "fcntl/manifest.toml", FCNTL,
                               partial(parse_probe, suite=SUITE / "fcntl",
                                       asm_fixtures=(Path("tests/phase2/abi.asm"), SUITE / "fcntl/variadic.asm")))
        case = next(p.case for p in probes if p.case.name == "fcntl-owner-sentinel")
        fixture = Path(case.sources[0])
        baseline = subprocess.check_output(["git", "show", "HEAD:" + str(fixture)])
        if fixture.read_bytes() != baseline:
            raise AssertionError("sentinel fixture changed")
        log = checks["runtime_commands"] = []
        runtime = build_runtime(root / "runtime", log)
        checks["runtime_artifacts"] = runtime[3]
        checks["archive_sha256"] = sha256_file(runtime[1])
        binary, artifacts = build_case(case, root / "sentinel", runtime, log)
        checks["fixture"] = {"source": str(fixture), "source_sha256": sha256_file(fixture),
                             "unchanged_from_HEAD": True, "artifacts": artifacts,
                             "binary_sha256": sha256_file(binary)}
        commands = {
            "native": [str(binary.resolve()), *case.args],
            "qemu": [shutil.which("qemu-x86_64"), str(binary.resolve()), *case.args],
            "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                         str(binary.resolve()), *case.args],
        }
        observations = checks["boundary_comparison"] = {}
        for backend, command in commands.items():
            old = subprocess.run(command, capture_output=True, env=case.env,
                                 start_new_session=True, timeout=30)
            old_tuple = [old.returncode, old.stdout.hex(), old.stderr.hex()]
            if old_tuple != [69, "", ""]:
                raise AssertionError((backend, "old boundary", old_tuple))
            new = {}
            invoke(command, new, timeout=30, environment=case.env, preserve_pgid1=True)
            if (new["returncode"], new["stdout"], new["stderr"]) != (0, "", ""):
                raise AssertionError((backend, "proposed boundary", new))
            observations[backend] = {"command": command, "same_binary_sha256": sha256_file(binary),
                                     "isolated_session": old_tuple, "inherited_pgid1": new}
        stub_log = checks["zero_stub_commands"] = []
        stub_dir = root / "zero-stub"
        stub_dir.mkdir()
        stub, digest = generate_stub(load_project().functions["fcntl"], stub_dir, stub_log)
        wrong, wrong_artifacts = build_case(case, stub_dir / "probe", runtime, stub_log, ("fcntl", stub))
        wrong_result = {}
        try:
            invoke([str(wrong.resolve()), *case.args], wrong_result, timeout=30,
                   environment=case.env, preserve_pgid1=True)
        except GateError:
            if (wrong_result.get("returncode"), wrong_result.get("stdout"), wrong_result.get("stderr")) != (62, "", ""):
                raise
        else:
            raise AssertionError("generated fcntl zero stub was accepted")
        checks["sentinel_zero_control"] = {"source_sha256": digest, "artifacts": wrong_artifacts,
                                           "actual": wrong_result,
                                           "note": "Existing typed-owner assertion rejects; original manifest stub is unchanged."}
        if record["inputs"] != phase1_inputs():
            raise AssertionError("preflight inputs changed")
        record["driver"]["subreaper_after"] = subreaper_state()
        if record["driver"]["subreaper_after"] != record["driver"]["subreaper_before"]:
            raise AssertionError("subreaper setting changed")
        record["outcome"] = "pass"
    except Exception as error:
        record["error"] = str(error)
        raise
    finally:
        report.parent.mkdir(parents=True, exist_ok=True)
        report.write_text(json.dumps(record, indent=2, sort_keys=True) + "\n")
        print(report, sha256_file(report), flush=True)


if __name__ == "__main__":
    main()

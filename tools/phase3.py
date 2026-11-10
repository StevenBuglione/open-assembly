"""Verify the freestanding Phase 3 allocator and environment fixtures."""

import os
from pathlib import Path
import re
import sys
import tempfile

from gate import BUILD, GateError, identify_tools, run, source_policy, verify_setup, write_evidence
from phase1 import (BACKENDS, Case, build_case, build_runtime, execute_case, expected_result,
                    generate_stub, phase1_inputs)
from spec import (IDENTIFIER, ROOT, SpecError, keys, load_project, matching, read_toml,
                  regular_file, relative_path, snapshot_inputs, string_list, version_one)

MANIFEST = Path("tests/phase3/manifest.toml")
PHASE3_PUBLIC = {"malloc", "free", "calloc", "realloc", "aligned_alloc", "posix_memalign",
                 "getenv", "setenv", "unsetenv", "putenv"}
LINK_WRAPS = {"__al_syscall"}


def load_manifest():
    document = read_toml(regular_file(ROOT, MANIFEST, "Phase 3 manifest"))
    keys(document, {"schema", "case", "stub"}, MANIFEST)
    version_one(document["schema"], MANIFEST)
    if type(document["case"]) is not list or not document["case"] or type(document["stub"]) is not list:
        raise GateError(f"{MANIFEST}: expected nonempty cases and per-function stubs")

    cases = {}
    required = set(Case.__dataclass_fields__) - {"skip"}
    for index, table in enumerate(document["case"], 1):
        where = f"{MANIFEST}: case {index}"
        keys(table, required, where, ("skip", "link_wraps"))
        name = matching(table["name"], r"[a-z][a-z0-9-]*", where)
        if name in cases:
            raise GateError(f"{where}: duplicate case {name}")
        sources = tuple(relative_path(path, where) for path in
                        string_list(table["sources"], r".+", where, nonempty=True))
        for source in sources:
            if source.parts[:2] != ("tests", "phase3") and source != Path("tests/phase2/abi.asm"):
                raise GateError(f"{where}: source must be a Phase 3 fixture or the shared ABI probe")
            if source.suffix not in {".c", ".asm"}:
                raise GateError(f"{where}: unsupported fixture source {source}")
            regular_file(ROOT, source, where)
        requires = string_list(table["requires"], IDENTIFIER, where, nonempty=True)
        oracle = string_list(table["oracle"], r"[a-z][a-z0-9_-]*:[A-Za-z0-9_./+-]+",
                             where, nonempty=True)
        backends = string_list(table["backends"], r"native|qemu|valgrind", where, nonempty=True)
        skip = table.get("skip", {})
        if (type(skip) is not dict or set(skip) != BACKENDS - set(backends)
                or any(type(reason) is not str or not reason.strip() for reason in skip.values())):
            raise GateError(f"{where}: each omitted backend requires a reason")
        args, env = table["args"], table["env"]
        if type(args) is not list or any(type(arg) is not str or "\0" in arg for arg in args):
            raise GateError(f"{where}: args must contain argument strings")
        if type(env) is not dict or any(not re.fullmatch(IDENTIFIER, key) or type(value) is not str
                                        or "\0" in value for key, value in env.items()):
            raise GateError(f"{where}: invalid environment")
        status, stdout, stderr = expected_result(table, where)
        wraps = string_list(table.get("link_wraps", []), IDENTIFIER, where)
        if set(wraps) - LINK_WRAPS:
            raise GateError(f"{where}: unsupported test-only wrap")
        if bool(wraps) != (Path("tests/phase3/fault.c") in sources):
            raise GateError(f"{where}: the fault fixture must be the only wrapped test source")
        case = Case(name, sources, requires, args, env, status, stdout, stderr, oracle, backends, skip)
        cases[name] = (case, wraps)

    stubs = {}
    for index, table in enumerate(document["stub"], 1):
        where = f"{MANIFEST}: stub {index}"
        keys(table, {"symbol", "case", "status", "stdout", "stderr"}, where)
        symbol = matching(table["symbol"], IDENTIFIER, where)
        name = matching(table["case"], r"[a-z][a-z0-9-]*", where)
        if symbol not in PHASE3_PUBLIC or symbol in stubs or name not in cases:
            raise GateError(f"{where}: expected a unique Phase 3 symbol and an existing case")
        case, wraps = cases[name]
        if symbol not in case.requires or "native" not in case.backends:
            raise GateError(f"{where}: the native case must reference {symbol}")
        expected = expected_result(table, where)
        if expected == (case.status, case.stdout, case.stderr):
            raise GateError(f"{where}: generated stub must differ from the production result")
        stubs[symbol] = (case, wraps, expected)
    if stubs.keys() != PHASE3_PUBLIC:
        raise GateError("missing Phase 3 generated stubs")
    for name in ("alloc-model", "environment-model", "fault-realloc", "fault-env-vector-set",
                 "fault-env-vector-put", "fault-env-churn"):
        if name not in cases or set(cases[name][0].backends) != BACKENDS:
            raise GateError(f"{MANIFEST}: missing required three-backend case {name}")
    return cases, stubs


def phase3_inputs():
    hashes = phase1_inputs()
    paths = [*Path("tests/phase3").glob("*"), Path("tests/phase2/abi.asm"),
             Path("docs/adr/0004-allocator-environment.md"), Path(__file__).relative_to(ROOT)]
    hashes.update(snapshot_inputs(ROOT, paths))
    return dict(sorted(hashes.items()))


def check_stubs(controls, directory, runtime, record):
    project = load_project()
    for symbol, (case, wraps, expected) in controls.items():
        item = {"outcome": "fail", "case": case.name, "oracle": case.oracle,
                "expected_rejection": expected, "commands": []}
        record["symbols"][symbol] = item
        work = directory / f"stub-{symbol}"
        work.mkdir()
        obj, item["source_sha256"] = generate_stub(project.functions[symbol], work, item["commands"])
        binary, item["artifacts"] = build_case(case, work / "probe", runtime, item["commands"],
                                                (symbol, obj), link_wraps=wraps)
        result = run([binary, *case.args], environment=case.env)
        item["run"] = result
        observed = (result["returncode"], result["stdout"], result["stderr"])
        if observed != expected:
            raise GateError(f"{symbol} stub in {case.name}: expected {expected!r}, got {observed!r}")
        item["outcome"] = "pass"
        print(f"PASS {case.name} rejected generated {symbol} stub", flush=True)
    record["outcome"] = "pass"


def execute_phase3():
    evidence = {
        "schema_version": 1, "scope": "phase3", "production_verified": False, "outcome": "fail",
        "platform": {key: getattr(os.uname(), key) for key in ("sysname", "release", "machine")},
        "checks": {},
    }
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64")
        evidence["inputs"] = verify_setup(checks, False, snapshot=phase3_inputs)
        cases, controls = load_manifest()
        workspace = BUILD / "phase3"
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
                raise GateError("two isolated Phase 3 runtime builds produced different artifacts")
            runtime.update(outcome="pass", reproducible=True)
            for case, wraps in cases.values():
                record = {
                    "outcome": "fail", "commands": [], "runs": {}, "skipped_backends": case.skip,
                    "oracle": case.oracle, "required_symbols": case.requires, "link_wraps": wraps,
                    "expected": {"status": case.status, "stdout": case.stdout, "stderr": case.stderr},
                    "environment": case.env,
                }
                checks[case.name] = record
                binary, first_hashes = build_case(case, directory / case.name, first, record["commands"],
                                                  link_wraps=wraps)
                _, second_hashes = build_case(case, directory / (case.name + "-second"), second,
                                              record["commands"], link_wraps=wraps)
                record["artifacts"] = {"first": first_hashes, "second": second_hashes}
                if first_hashes != second_hashes:
                    raise GateError(f"{case.name}: isolated fixture builds differ")
                execute_case(case, binary, record)
                record["outcome"] = "pass"
            checks["stub_controls"] = {"outcome": "fail", "symbols": {}}
            check_stubs(controls, directory, first, checks["stub_controls"])
        if evidence["inputs"] != phase3_inputs():
            raise GateError("inputs changed during Phase 3 verification")
        evidence["outcome"] = "pass"
    except (GateError, KeyError, OSError, SpecError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence("phase3", evidence)
    print(f"phase3 evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute_phase3())

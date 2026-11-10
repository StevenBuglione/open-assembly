"""Verify compiler-generated and direct baseline atomic libcall ABI."""

from functools import partial
from pathlib import Path
import shutil
import sys
import tempfile

from gate import BUILD, GateError, checked, identify_tools, nm_symbols, source_policy, verify_setup, write_evidence
from phase1 import Case, RUNTIME_LINK, TEST_C_FLAGS, build_runtime
from phase4 import Probe, execute_probe, load_probes, parse_probe
from phase6 import phase6_inputs, run_cases, run_stubs
from spec import ROOT, SpecError, load_project, sha256_file, snapshot_inputs

SUITE = Path("tests/phase8/atomics")
SCOPE = "phase8-compiler-atomics"
SYMBOLS = {
    "__atomic_load", "__atomic_store", "__atomic_exchange", "__atomic_compare_exchange", "__atomic_is_lock_free",
    "__atomic_load_16", "__atomic_store_16", "__atomic_exchange_16", "__atomic_compare_exchange_16",
    "__atomic_fetch_add_16", "__atomic_fetch_sub_16", "__atomic_fetch_and_16", "__atomic_fetch_or_16",
    "__atomic_fetch_xor_16", "__atomic_fetch_nand_16",
}
ORACLES = ("reference:compiler-atomic-abi", "reference:c17-atomic-representations")


def inputs():
    bound = phase6_inputs()
    bound.update(snapshot_inputs(ROOT, [Path("docs/adr/0037-compiler-atomic-libcalls.md")]))
    return dict(sorted(bound.items()))


def emitted(compiler, directory, runtime, log):
    directory.mkdir(parents=True)
    startup, archive, _, _ = runtime
    source = SUITE / "emitted.c"
    obj, binary, link_map = (directory / name for name in ("test.o", "atomics", "atomics.map"))
    warning = ["-Wno-error=atomic-alignment"] if compiler == "al-clang" else []
    flags = [flag for flag in TEST_C_FLAGS if compiler != "al-clang" or flag != "-fstack-protector-explicit"]
    checked(log, [compiler, *flags, "-march=x86-64", "-mno-cx16", *warning,
                  "-c", source, "-o", obj])
    checked(log, ["tools/elf-audit", "--test-object", obj])
    undefined = nm_symbols(log, obj, ["-g", "-u"])
    references = {name for name, kind in undefined.items() if name.startswith("__atomic_") and kind == "U"}
    if references != SYMBOLS:
        raise GateError(f"{compiler}: emitted atomics differ. Missing {sorted(SYMBOLS - references)}, "
                        f"extra {sorted(references - SYMBOLS)}")
    checked(log, [*RUNTIME_LINK, f"-Map={link_map}", "--cref", "-o", binary, startup, obj, archive])
    checked(log, ["tools/elf-audit", binary])
    defined = nm_symbols(log, binary, ["-g", "--defined-only"])
    origins = {}
    table = link_map.read_text().partition("Cross Reference Table\n")[2]
    for line in table.splitlines():
        if line and not line[0].isspace():
            fields = line.split(maxsplit=1)
            if len(fields) == 2 and fields[0] in SYMBOLS:
                origins.setdefault(*fields)
    expected = {name: f"{archive}({name}.o)" for name in SYMBOLS}
    if origins != expected or any(defined.get(name) != "T" for name in SYMBOLS):
        raise GateError(f"{compiler}: linked atomic calls do not resolve to the audited runtime archive")
    return binary, {"object_sha256": sha256_file(obj), "binary_sha256": sha256_file(binary),
                    "symbols": sorted(references)}


def execute():
    evidence = {"schema_version": 1, "scope": SCOPE, "outcome": "fail", "production_verified": False,
                "checks": {}, "limits": ["Pinned baseline x86-64 compiler libcalls without CMPXCHG16B.",
                                         "Contention tests cover process-local threads."]}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64", "al-clang")
        evidence["inputs"] = verify_setup(checks, False, snapshot=inputs)
        project = load_project()
        if not SYMBOLS <= project.functions.keys():
            raise GateError("the compiler atomic ABI specifications are incomplete")
        parse = partial(parse_probe, suite=SUITE, programs=(), fault_wrappers={},
                        asm_fixtures=(Path("tests/phase2/abi.asm"),))
        probes, stubs = load_probes(SUITE / "manifest.toml", SYMBOLS, parse)
        runners = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
                   "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                "--leak-check=full", "--errors-for-leak-kinds=all"]}
        workspace = BUILD / SCOPE
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as scratch:
            directory = Path(scratch).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            build = checks["runtime_build"] = {"outcome": "fail", "commands": []}
            first, second = (build_runtime(directory / f"runtime-{i}", build["commands"]) for i in (1, 2))
            if first[3] != second[3]:
                raise GateError("two isolated atomic runtime builds differ")
            build.update(outcome="pass", artifacts=first[3])
            checks["cases"] = {}
            run_cases(probes, directory, first, second, runners, checks["cases"], "OA_PHASE8_HOST")
            record = checks["stub_controls"] = {"outcome": "fail", "symbols": {}}
            run_stubs(stubs, project, directory, first, record)
            checks["compiler_emission"] = {}
            for compiler in ("gcc", "al-clang"):
                record = checks["compiler_emission"][compiler] = {"outcome": "fail", "commands": [], "runs": {}}
                work = directory / compiler
                binary, a = emitted(compiler, work / "first", first, record["commands"])
                _, b = emitted(compiler, work / "second", second, record["commands"])
                if a != b:
                    raise GateError(f"{compiler}: isolated compiler-emitted artifacts differ")
                record["artifacts"] = a
                case = Case(f"emitted-{compiler}", (SUITE / "emitted.c",), tuple(sorted(SYMBOLS)),
                            [], {}, 0, "", "", ORACLES, tuple(runners), {})
                probe = Probe(case, b"", b"", b"", {}, (), "Direct pinned compiler emission.")
                for backend, command in runners.items():
                    execute_probe(probe, binary, work / backend, record["runs"], {backend: command})
                record["outcome"] = "pass"
        if evidence["inputs"] != inputs():
            raise GateError("compiler atomic verification inputs changed during the run")
        evidence["outcome"] = "pass"
    except (GateError, OSError, SpecError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(SCOPE, evidence)
    print(f"{SCOPE} evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute())

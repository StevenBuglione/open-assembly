"""Verify selected runtime functions using independent manifest cases."""

from dataclasses import dataclass
from functools import partial
from hashlib import sha256
from pathlib import Path
import random
import shutil
import subprocess
import sys
import tempfile
import time

from branch_coverage import verify_coverage
from gate import (BUILD, COMPILE_FLAGS, LINK_FLAGS, GateError, checked, identify_tools,
                  nm_symbols, verify_setup, write_evidence)
from phase1 import NASM, build_case, build_runtime
from phase4 import load_probes, observation, parse_probe
from phase6 import run_cases, run_stubs
from production import applicable_variants, phase2_inputs, source_paths
from spec import ROOT, load_project, sha256_file, snapshot_inputs


@dataclass(frozen=True)
class Plan:
    suite: Path
    public: frozenset
    assembly: tuple
    abi: str
    trace: str
    mutations: tuple
    fuzz: str
    record_sizes: tuple
    contracts: tuple


FCNTL = Path("tests/phase6/fcntl")
PLANS = {
    "fcntl": Plan(
        FCNTL, frozenset({"fcntl"}), (Path("tests/phase2/abi.asm"), FCNTL / "variadic.asm"),
        "fcntl-abi", "fcntl-dispatch",
        (("fcntl-dispatch", tuple(range(10, 59))), ("fcntl-abi", (11, 12)),
         ("fcntl-descriptor", (12, 13, 14, 15, 16)), ("fcntl-pipe-size", (22,)),
         ("fcntl-owner", (62, 63, 64, 65, 66)), ("fcntl-unknown", (51, 52, 53))),
        "fcntl-fuzz", (4, 12), (Path("docs/adr/0007-linux-files-process-signal-time.md"),),
    ),
}
REQUIRED_CHECKS = {
    "generated_outputs", "candidate_build", "runtime_build", "native_oracles", "abi",
    "branch_coverage", "generated_stub", "production_mutation", "differential_fuzz",
}
FUZZ_SECONDS = 60
FUZZ_SEED = 0x5C7D3AA1


def manifest_inputs(function):
    inputs = phase2_inputs()
    inputs.update(snapshot_inputs(ROOT, PLANS[function].contracts))
    return dict(sorted(inputs.items()))


def candidate_object(path, source, name, original, log, *, debug=False):
    command = (*NASM, "-g", "-F", "dwarf") if debug else NASM
    checked(log, [*command, "-o", path, source])
    checked(log, ["tools/elf-audit", "--assembly-object", path])
    if nm_symbols(log, path, ["-g", "--defined-only"]) != {name: "T"}:
        raise GateError(f"{source}: candidate must define only {name}")
    if nm_symbols(log, path, ["-g", "-u"]) != nm_symbols(log, original, ["-g", "-u"]):
        raise GateError(f"{source}: candidate references differ from the archived object")
    return path


def trace_function(name, source, original, probe, directory, runtime, record):
    if probe.files or probe.input_bytes or probe.wraps:
        raise GateError(f"{probe.case.name}: trace case requires a direct, argument-only probe")
    directory.mkdir()
    log = record["commands"]
    debug = candidate_object(directory / f"{name}.debug.o", source, name, original, log, debug=True)
    text = [checked(log, ["objdump", "-dr", "-j", f".text.{name}", path])
            .partition("Disassembly of section ")[2] for path in (debug, original)]
    if not text[0] or text[0] != text[1]:
        raise GateError("traced candidate differs from the archived function")
    binary, artifacts = build_case(probe.case, directory / "linked", runtime, log,
                                  candidate=(name, debug))
    record.update(debug_object_sha256=sha256_file(debug), linked_artifacts=artifacts)
    verify_coverage(record, directory, binary, name, source, [probe.case.args], exact_case=probe.case)


def expected(probe):
    return probe.case.status, probe.stdout, probe.stderr


def execute_native(probe, binary, directory):
    directory.mkdir()
    for name, contents in probe.files.items():
        (directory / name).write_bytes(contents)
    command = [binary.resolve(), *probe.case.args]
    return observation(command, directory, probe.input_bytes, probe.case.env)


def mutate_function(name, spec, source, original, probes, plan, directory, runtime, record):
    directory.mkdir()
    returns_value = not spec.prototype.startswith("void ") and not spec.abi.noreturn
    for operator, contents in applicable_variants(name, source, record, returns_value=returns_value):
        work = directory / operator
        work.mkdir()
        mutant = work / f"{name}.asm"
        mutant.write_text(contents, encoding="utf-8")
        item = {"operator": operator, "source_sha256": sha256_file(mutant), "commands": [],
                "probes": [], "killed": False}
        record["operators"].append(item)
        obj = candidate_object(work / f"{name}.o", mutant, name, original, item["commands"])
        item["object_sha256"] = sha256_file(obj)
        for case_name, rejection_codes in plan.mutations:
            probe = probes[case_name]
            binary, artifacts = build_case(probe.case, work / case_name, runtime, item["commands"],
                                          candidate=(name, obj), link_wraps=probe.wraps)
            observed, log = execute_native(probe, binary, work / f"{case_name}-inputs")
            item["probes"].append({"case": case_name, "binary_sha256": artifacts[binary.name], **log})
            if observed == expected(probe):
                continue
            if observed[0] not in rejection_codes or observed[1:] != (b"", b""):
                raise GateError(f"{operator}: {case_name} unclassified result {observed!r}")
            item["killed"] = True
            break
    total = len(record["operators"])
    killed = sum(item["killed"] for item in record["operators"])
    record.update(total=total, killed=killed, threshold_percent=90)
    if not total or 100 * killed < 90 * total:
        raise GateError(f"{name}: mutation killed {killed}/{total}, below 90%")
    record["outcome"] = "pass"
    print(f"PASS {name} mutation {killed}/{total} killed", flush=True)


def fuzz_observation(command, probe, payload, work, output_size):
    result = subprocess.run([*command, *probe.case.args], input=payload, cwd=work, env=probe.case.env,
                            capture_output=True, timeout=15)
    if result.returncode or result.stderr or len(result.stdout) != output_size:
        raise GateError(f"{command[-1]}: bad differential packet result "
                        f"({result.returncode}, {len(result.stdout)}, {result.stderr[:256]!r})")
    return result.stdout


def timed_fuzz(name, probe, plan, directory, runtime, record):
    if probe.files or probe.wraps or probe.host_skip is not None or len(probe.case.sources) != 1:
        raise GateError(f"{probe.case.name}: timed fuzz requires a shared direct C packet fixture")
    directory.mkdir()
    log = record["commands"]
    candidate, artifacts = build_case(probe.case, directory / "target", runtime, log)
    binaries = {"candidate": candidate}
    for compiler, label in (("gcc", "glibc"), ("musl-gcc", "musl")):
        obj, binary = directory / f"{label}.o", directory / label
        checked(log, [compiler, *COMPILE_FLAGS, "-DOA_PHASE6_HOST", "-c", probe.case.sources[0], "-o", obj])
        checked(log, ["tools/elf-audit", "--test-object", obj])
        if nm_symbols(log, obj, ["-g", "-u"]).get(name) != "U":
            raise GateError(f"{label} differential fixture lacks its direct {name} reference")
        checked(log, [compiler, *LINK_FLAGS, "-o", binary, obj])
        checked(log, ["tools/elf-audit", binary])
        artifacts.update({path.name: sha256_file(path) for path in (obj, binary)})
        binaries[label] = binary
    record["artifacts"] = artifacts
    commands = {label: [str(binary.resolve())] for label, binary in binaries.items()}
    timed_packets(name, probe, plan.record_sizes, directory, commands, record)


def timed_packets(name, probe, record_sizes, directory, commands, record):
    if "candidate" not in commands or len(commands) < 2:
        raise GateError("timed differential requires a candidate and independent oracle")
    record.update(seed=FUZZ_SEED, runs=list(commands))
    seed_size, result_size = record_sizes
    rng = random.Random(FUZZ_SEED)
    start = time.monotonic()
    count = 0
    digests = {label: sha256() for label in ["input", *commands]}
    while time.monotonic() - start < FUZZ_SECONDS:
        payload = rng.randbytes(seed_size * 512)
        digests["input"].update(payload)
        results = {label: fuzz_observation(command, probe, payload, directory, result_size * 512)
                   for label, command in commands.items()}
        if len(set(results.values())) != 1:
            for i in range(512):
                row = {label: data[i * result_size:(i + 1) * result_size].hex()
                       for label, data in results.items()}
                if len(set(row.values())) != 1:
                    stimulus = payload[i * seed_size:(i + 1) * seed_size].hex()
                    raise GateError(f"timed differential seed {FUZZ_SEED:#x}, row {count + i}, "
                                    f"input {stimulus}: {row}")
        for label, result in results.items():
            digests[label].update(result)
        count += 512
    if count == 0:
        raise GateError("timed differential produced no records")
    record.update(outcome="pass", records=count, elapsed_s=round(time.monotonic() - start, 6),
                  sha256={label: digest.hexdigest() for label, digest in digests.items()})
    print(f"PASS {name} timed differential {count} records", flush=True)


def runtime_manifest_production(function, only=None):
    scope = "production-runtime-manifest-function" if only is None else f"production-runtime-manifest-{only}"
    evidence = {"schema_version": 1, "scope": scope, "function": function, "outcome": "fail",
                "production_verified": False, "checks": {}}
    checks = evidence["checks"]
    try:
        if only not in (None, "coverage", "mutation", "stub", "fuzz"):
            raise GateError(f"unsupported manifest production check {only}")
        plan = PLANS[function]
        snapshot = partial(manifest_inputs, function)
        evidence["toolchain"] = identify_tools("ar", "make", "objdump", "qemu-x86_64", "musl-gcc")
        evidence["inputs"] = verify_setup(checks, False, snapshot=snapshot)
        project = load_project()
        spec = project.functions[function]
        source = source_paths()[function]
        parse = partial(parse_probe, suite=plan.suite, programs=(), asm_fixtures=plan.assembly,
                        fault_wrappers={}, allow_fixture_files=True)
        probes, controls = load_probes(plan.suite / "manifest.toml", plan.public, parse)
        probes = {probe.case.name: probe for probe in probes if function in probe.case.requires}
        selected = {plan.abi, plan.trace, plan.fuzz, *(case for case, _ in plan.mutations)}
        if not selected <= probes.keys() or function not in controls:
            raise GateError(f"{function}: incomplete function coverage in the runtime manifest")
        runners = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
                   "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                "--leak-check=full", "--errors-for-leak-kinds=all"]}
        workspace = BUILD / "production"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix=f"{function}-") as temp:
            directory = Path(temp).resolve().relative_to(ROOT)
            build = checks["runtime_build"] = {"outcome": "fail", "commands": []}
            runtime = build_runtime(directory / "runtime", build["commands"])
            build["artifacts"] = {"first": runtime[3]}
            if only is None:
                second = build_runtime(directory / "repeated-runtime", build["commands"])
                build["artifacts"]["second"] = second[3]
                if runtime[3] != second[3]:
                    raise GateError(f"{function}: repeated runtime artifacts differ")
            build["outcome"] = "pass"
            original = directory / "runtime/obj" / source.relative_to("src/x86_64-linux").with_suffix(".o")
            candidate = checks["candidate_build"] = {"outcome": "fail", "commands": []}
            checked(candidate["commands"], ["tools/lint", source])
            candidate.update(outcome="pass", source=str(source), source_sha256=sha256_file(source),
                             object_sha256=sha256_file(original))

            if only is None:
                for check, cases in (("native_oracles", [probe for key, probe in probes.items() if key != plan.abi]),
                                     ("abi", [probes[plan.abi]])):
                    target = directory / check
                    target.mkdir()
                    record = checks[check] = {"outcome": "fail", "cases": {}}
                    run_cases(cases, target, runtime, second, runners, record["cases"],
                              host_macro="OA_PHASE6_HOST")
                    record["outcome"] = "pass"
            if only in (None, "coverage"):
                trace = checks["branch_coverage"] = {"outcome": "fail", "commands": [], "runs": []}
                trace_function(function, source, original, probes[plan.trace], directory / "coverage", runtime, trace)
            if only in (None, "stub"):
                stub = checks["generated_stub"] = {"outcome": "fail", "symbols": {}}
                run_stubs({function: controls[function]}, project, directory, runtime, stub)
            if only in (None, "mutation"):
                mutation = checks["production_mutation"] = {"outcome": "fail", "operators": []}
                mutate_function(function, spec, source, original, probes, plan,
                                directory / "mutation", runtime, mutation)
            if only in (None, "fuzz"):
                fuzz = checks["differential_fuzz"] = {"outcome": "fail", "commands": []}
                timed_fuzz(function, probes[plan.fuzz], plan, directory / "fuzz", runtime, fuzz)
        if evidence["inputs"] != snapshot():
            raise GateError("runtime manifest verification inputs changed during the run")
        if only is None and (not REQUIRED_CHECKS <= checks.keys()
                             or any(checks[name]["outcome"] != "pass" for name in REQUIRED_CHECKS)):
            raise GateError("runtime manifest production evidence is missing a passing required check")
        evidence.update(outcome="pass", production_verified=only is None)
    except (GateError, KeyError, OSError, ValueError, subprocess.SubprocessError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(f"{function}.{only or 'production'}", evidence)
    print(f"{scope} evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1

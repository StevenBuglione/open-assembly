"""Check selected public math wrappers using the independent MPFR packet oracle."""

import argparse
from concurrent.futures import ThreadPoolExecutor
from functools import partial
import json
import os
from pathlib import Path
import random
import re
import subprocess
import sys
import tempfile
from time import monotonic

from branch_coverage import verify_coverage
from gate import (BUILD, COMPILE_FLAGS, EVIDENCE, LINK_FLAGS, CandidateFailure, GateError, checked,
                  finish_function_gate, identify_tools, nm_symbols, run, verify_setup, write_evidence)
from phase1 import Case, RUNTIME_SRC, build_case, build_runtime, generate_stub, phase1_inputs
from production import applicable_variants
from runtime_manifest_gate import candidate_object, debug_candidate
from spec import ROOT, SpecError, load_project, sha256_file, snapshot_inputs


TESTS = Path("tests/phase7/transcendental")
ABI = (TESTS / "abi.c", TESTS / "abi.asm", Path("tests/phase2/abi.asm"))
WRAPPERS = {symbol: (operation, width, engine)
            for operation, engine in (("exp2", "__al_math_exp"), ("log2", "__al_math_log"))
            for width, symbol in ((32, operation + "f"), (64, operation))}
SCOPE = "math-wrapper-verification"
SECONDS = 60
SEED = 0x4D415448
BATCH = 512
VALGRIND_SCOPE = "Nearest normal or zero results through Memcheck. Native and QEMU check the complete floating environment."


def math_inputs():
    contracts = (Path("docs/adr/0006-exact-numerics.md"), Path("docs/adr/0008-math-range-reduction.md"))
    return dict(sorted((phase1_inputs() | snapshot_inputs(ROOT, contracts)).items()))


def bind_case(name, sources, symbol, backends):
    return Case(name, sources, (symbol,), [], {}, 0, "", "", ("reference:mpfr",), backends, {})


def oracle_pass(record, context, *, candidate=False):
    if record.get("passed") is True:
        return
    if record.get("error") or record.get("status") != 0 or record.get("stderr") or not record.get("failures"):
        raise GateError(f"{context}: invalid packet transport {record.get('error') or record.get('stderr')}")
    failure = CandidateFailure if candidate else GateError
    first = record["failures"][0]
    raise failure(f"{context}: {first['input']} disagreed with MPFR ({', '.join(first['failures'])})")


def check_abi(name, width, directory, runtime, record):
    case = bind_case("math-abi", ABI, name, ("native", "qemu"))
    binary, record["artifacts"] = build_case(case, directory, runtime, record["commands"],
                                            c_flags=(f"-DTEST_FORMAT={width}", f"-DTEST_FUNCTION={name}"))
    c_refs = nm_symbols(record["commands"], directory / "test-0.o", ["-g", "-u"])
    if c_refs.get("phase7_scalar_abi_probe") != "U":
        raise GateError("math ABI fixture omits its independent scalar trampoline")
    for backend, prefix in (("native", ()), ("qemu", ("qemu-x86_64",))):
        result = run([*prefix, binary])
        record["runs"][backend] = result
        if result["returncode"] == 11 and not result["stdout"] and not result["stderr"] and backend == "native":
            raise CandidateFailure(f"{name}: scalar SysV register or control state changed")
        if result["returncode"] or result["stdout"] or result["stderr"]:
            raise GateError(f"{name}: {backend} scalar SysV fixture did not complete silently")
    record["outcome"] = "pass"


def check_oracles(binary, case, width, rows, directory, record, observe, applicable_shared):
    shared = [row for row in rows if applicable_shared(row)]
    if not shared:
        raise GateError("the independent oracle provided no shared hosted or Memcheck rows")
    for backend, prefix, selected, environment in (
            ("native", (), rows, True), ("qemu", ("qemu-x86_64",), rows, True),
            ("valgrind", ("valgrind", "--quiet", "--error-exitcode=99"), shared, False)):
        item = record["runs"][backend] = observe([*prefix, binary], selected, check_environment=environment)
        oracle_pass(item, f"{case.requires[0]} {backend}", candidate=backend == "native")
    directory.mkdir()
    for compiler in ("gcc", "musl-gcc"):
        log = record["commands"]
        obj, hosted = (directory / f"{compiler}{suffix}" for suffix in (".o", ""))
        checked(log, [compiler, *COMPILE_FLAGS, f"-DTEST_FORMAT={width}", "-c", case.sources[0], "-o", obj])
        checked(log, ["tools/elf-audit", "--test-object", obj])
        if nm_symbols(log, obj, ["-g", "-u"]).get(case.requires[0]) != "U":
            raise GateError(f"{compiler}: hosted fixture lacks the selected wrapper reference")
        checked(log, [compiler, *LINK_FLAGS, "-o", hosted, obj, "-lm"])
        checked(log, ["tools/elf-audit", hosted])
        if nm_symbols(log, hosted, ["-g", "--defined-only"]).get(case.requires[0]) not in {"T", "W", "i"}:
            raise GateError(f"{compiler}: hosted math executable lacks the selected wrapper")
        item = record["hosts"][compiler] = observe([hosted], shared, check_environment=False)
        item["artifacts"] = {path.name: sha256_file(path) for path in (obj, hosted)}
        oracle_pass(item, f"{compiler} {case.requires[0]}")
    record["outcome"] = "pass"


def typed_mutants(width, source):
    move, integer = ("movd", "eax") if width == 32 else ("movq", "rax")
    original = source.read_text(encoding="utf-8")
    selector = int(width == 64)
    for name, register, before, after in (("format-selector", "edi", selector, 1 - selector),
                                          ("operation-selector", "ecx", 0, 1)):
        pattern = rf"(?m)^([ \t]*mov[ \t]+{register},[ \t]*){before}([ \t]*(?:;[^\n]*)?)$"
        contents, count = re.subn(pattern, rf"\g<1>{after}\2", original)
        if count != 1:
            raise GateError(f"{source}: expected one instruction for {name} mutation")
        yield name, contents
    for opcode, name in (("add", "plus"), ("sub", "minus")):
        replacement = f"    {move} {integer}, xmm0\n    {opcode} {integer}, 2\n    {move} xmm0, {integer}\n"
        contents, count = re.subn(r"(?m)^([ \t]*ret[ \t]*(?:;[^\n]*)?)$", replacement + r"\1", original)
        if not count:
            raise GateError("typed floating return mutation requires a return instruction")
        yield f"return-{name}-two-encodings", contents


def check_mutation(name, width, source, original, case, rows, directory, runtime, record, observe):
    directory.mkdir()
    flags = (f"-DTEST_FORMAT={width}",)
    operators = (*applicable_variants(name, source, record, returns_value=False), *typed_mutants(width, source))
    for operator, contents in operators:
        work = directory / operator
        work.mkdir()
        mutant = work / f"{name}.asm"
        mutant.write_text(contents, encoding="utf-8")
        item = {"operator": operator, "source_sha256": sha256_file(mutant), "commands": []}
        record["operators"].append(item)
        obj = candidate_object(work / f"{name}.o", mutant, name, original, item["commands"])
        binary, item["artifacts"] = build_case(case, work / "linked", runtime, item["commands"],
                                              candidate=(name, obj), c_flags=flags)
        item["object_sha256"] = sha256_file(obj)
        observed = item["probe"] = observe([binary], rows)
        if observed["status"] or observed["stderr"] or observed.get("error"):
            raise GateError(f"{name} {operator}: invalid mutant packet transport")
        item["killed"] = bool(observed.get("failures")) and observed.get("passed") is False
    total = len(operators)
    killed = sum(item["killed"] for item in record["operators"])
    record.update(total=total, killed=killed, threshold_percent=90)
    if not total or 100 * killed < 90 * total:
        raise GateError(f"{name}: killed {killed}/{total} applicable wrapper mutants")
    record["outcome"] = "pass"


def timed_mpfr(operation, width, binary, record, oracle, observe):
    seed = SEED ^ width ^ oracle.OP_ID[operation] * 65537
    rng = random.Random(seed)
    fmt = oracle.FORMATS[f"f{width}"]
    record.update(seed=seed, oracle="reference:mpfr", batch_size=BATCH, requested_seconds=SECONDS)
    before = monotonic()
    while monotonic() - before < SECONDS:
        rows = []
        for index, (argument, label) in enumerate(oracle.random_inputs(fmt, rng, BATCH)):
            mode = oracle.MODES[index % len(oracle.MODES)]
            rows.append(oracle.Case(operation, argument, mode, label, oracle.expected(operation, argument, mode)))
        item = observe([binary], rows)
        if item.get("passed") is not True:
            record["failure"] = item
            oracle_pass(item, f"{operation}/f{width} seeded differential", candidate=True)
        record["batches"].append({key: item[key] for key in
                                  ("records", "input_sha256", "result_sha256", "max_finite_ulp")})
    batches = record["batches"]
    if not batches:
        raise GateError("no seeded MPFR packet batch completed")
    record.update(outcome="pass", elapsed_s=round(monotonic() - before, 6),
                  records=sum(item["records"] for item in batches),
                  max_finite_ulp=max((item["max_finite_ulp"] or 0 for item in batches), default=0))


def require_production(name, attempt):
    _, _, engine = WRAPPERS[name]
    message = f"{name}: shared implementation {engine} needs its own source-bound coverage and mutation proof"
    evidence = {"schema_version": 1, "scope": "production-function", "function": name,
                "outcome": "fail", "production_verified": False, "failure_class": "harness", "error": message,
                "checks": {"dependency_closure": {"outcome": "pending", "engine": engine}},
                "wrapper_report": str(EVIDENCE / f"{name}.math-wrapper.json")}
    print(f"gate: {message}", file=sys.stderr)
    return finish_function_gate(name, None, evidence, attempt, math_inputs)


def execute(name, only=None):
    scope = SCOPE if only is None else f"{SCOPE}-{only}"
    operation, width, engine = WRAPPERS[name]
    checks = {"dependency_closure": {"outcome": "pending", "engine": engine}}
    evidence = {"schema_version": 1, "scope": scope, "function": name, "outcome": "fail",
                "operation": operation, "format_bits": width, "production_verified": False,
                "wrapper_checks_passed": False, "checks": checks}
    try:
        sys.path.insert(0, str(ROOT / TESTS))
        import oracle
        from verify import applicable_shared, observe, stub_check
        from phase5 import mpfr_identity

        evidence["toolchain"] = identify_tools("ar", "make", "objdump", "qemu-x86_64", "musl-gcc")
        evidence["mpfr"] = mpfr_identity()
        evidence["inputs"] = verify_setup(checks, False, snapshot=math_inputs)
        spec = load_project().functions[name]
        if spec.header != "math.h" or "reference:mpfr" not in spec.oracles:
            raise GateError(f"{name}: expected a documented MPFR math interface")
        rows = list(oracle.cases(f"f{width}", operation))
        if not rows or {row.mode for row in rows} != set(oracle.MODES):
            raise GateError(f"{name}: missing complete directed MPFR input modes")
        source = RUNTIME_SRC / "math" / f"{name}.asm"
        flags = (f"-DTEST_FORMAT={width}",)
        case = bind_case("math-packets", (TESTS / "probe.c",), name, ("native", "qemu", "valgrind"))
        workspace = BUILD / "math-wrappers"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix=f"{name}-") as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            candidate = checks["candidate_build"] = {"outcome": "fail", "commands": []}
            log = candidate["commands"]
            checked(log, ["tools/lint", source])
            runtime = build_runtime(directory / "runtime", log)
            original = directory / "runtime/obj/math" / f"{name}.o"
            binary, artifacts = build_case(case, directory / "first", runtime, log, c_flags=flags)
            candidate.update(source=str(source), source_sha256=sha256_file(source),
                             object_sha256=sha256_file(original), archive_sha256=sha256_file(runtime[1]),
                             executable_artifacts=artifacts)
            if only is None:
                second = build_runtime(directory / "repeat-runtime", log)
                _, repeated = build_case(case, directory / "second", second, log, c_flags=flags)
                if runtime[3] != second[3] or artifacts != repeated:
                    raise GateError(f"{name}: repeated archive and packet artifacts differ")
            candidate["outcome"] = "pass"

            if only is None:
                abi = checks["abi"] = {"outcome": "fail", "commands": [], "runs": {}}
                check_abi(name, width, directory / "abi", runtime, abi)
                oracles = checks["native_oracles"] = {"outcome": "fail", "commands": [], "runs": {}, "hosts": {},
                                                     "valgrind_scope": VALGRIND_SCOPE}
                check_oracles(binary, case, width, rows, directory / "hosts", oracles, observe, applicable_shared)
            if only in (None, "coverage"):
                trace = checks["branch_coverage"] = {"outcome": "fail", "commands": [], "runs": []}
                work = directory / "coverage"
                work.mkdir()
                debug = debug_candidate(name, source, original, work, trace["commands"])
                traced, trace["linked_artifacts"] = build_case(case, work / "linked", runtime, trace["commands"],
                                                              candidate=(name, debug), c_flags=flags)
                trace["debug_object_sha256"] = sha256_file(debug)
                verify_coverage(trace, work, traced, name, source, [()], require_entry=True,
                                packet_oracle=partial(observe, rows=rows))
            if only in (None, "stub"):
                stub = checks["generated_stub"] = {"outcome": "fail", "commands": []}
                work = directory / "stub"
                work.mkdir()
                obj, stub["source_sha256"] = generate_stub(spec, work, stub["commands"])
                rejected, stub["artifacts"] = build_case(case, work / "linked", runtime, stub["commands"],
                                                         (name, obj), c_flags=flags)
                stub["probe"] = stub_check(rejected, rows)
                if not stub["probe"].get("stub_rejected"):
                    raise GateError(f"{name}: generated typed zero stub did not trigger the independent MPFR rejection")
                stub["outcome"] = "pass"
            if only in (None, "mutation"):
                mutation = checks["production_mutation"] = {"outcome": "fail", "operators": []}
                check_mutation(name, width, source, original, case, rows, directory / "mutation", runtime,
                               mutation, observe)
            if only is None:
                fuzz = checks["differential_fuzz"] = {"outcome": "fail", "batches": []}
                timed_mpfr(operation, width, binary, fuzz, oracle, observe)
        if evidence["inputs"] != math_inputs():
            raise GateError("math wrapper verification inputs changed during the run")
        evidence.update(outcome="pass", wrapper_checks_passed=only is None)
    except (GateError, ImportError, KeyError, OSError, SpecError, ValueError, subprocess.SubprocessError) as error:
        evidence.update(error=str(error), failure_class="semantic" if isinstance(error, CandidateFailure) else "harness")
        print(f"math-wrapper: {error}", file=sys.stderr)
    report = write_evidence(f"{name}.{only or 'math-wrapper'}", evidence)
    print(f"{evidence['outcome'].upper()} {scope} {name}: {report}", flush=True)
    return int(evidence["outcome"] != "pass")


def batch(functions, jobs):
    def child(name):
        item = {"outcome": "fail"}
        try:
            result = run([sys.executable, __file__, name], timeout=600)
            item.update(result)
            if not result["returncode"]:
                path = EVIDENCE / f"{name}.math-wrapper.json"
                record = json.loads(path.read_text(encoding="utf-8"))
                if (record.get("scope") == SCOPE and record.get("function") == name
                        and record.get("outcome") == "pass" and record.get("wrapper_checks_passed") is True
                        and record.get("production_verified") is False and record.get("inputs") == math_inputs()):
                    item.update(outcome="pass", evidence=str(path), evidence_sha256=sha256_file(path))
                else:
                    item["error"] = "missing fresh wrapper evidence"
        except (GateError, OSError, SpecError, ValueError) as error:
            item["error"] = str(error)
        print(f"{item['outcome'].upper()} {name}", flush=True)
        if item["outcome"] == "fail":
            print(item.get("error") or item.get("stderr", "").strip(), file=sys.stderr, flush=True)
        return name, item

    with ThreadPoolExecutor(max_workers=jobs) as pool:
        results = dict(pool.map(child, functions))
    passed = sum(item["outcome"] == "pass" for item in results.values())
    evidence = {"schema_version": 1, "scope": f"{SCOPE}-batch", "production_verified": False,
                "outcome": "pass" if passed == len(functions) else "fail", "functions": results,
                "full_scope": set(functions) == WRAPPERS.keys(), "passed": passed, "total": len(functions)}
    report = write_evidence("math-wrappers", evidence)
    print(f"Math wrapper checks {passed}/{len(functions)}. Evidence at {report}", flush=True)
    return int(passed != len(functions))


def main():
    os.chdir(ROOT)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("functions", nargs="*", choices=tuple(WRAPPERS))
    parser.add_argument("--only", choices=("coverage", "mutation", "stub"))
    parser.add_argument("--batch", action="store_true")
    parser.add_argument("--jobs", type=int, default=4)
    args = parser.parse_args()
    if args.jobs < 1 or len(set(args.functions)) != len(args.functions):
        parser.error("supply unique wrapper names and a positive job count")
    if args.batch and args.only is None:
        return batch(args.functions or sorted(WRAPPERS), args.jobs)
    if args.batch or len(args.functions) != 1:
        parser.error("supply one function or select the wrapper batch")
    return execute(args.functions[0], args.only)


if __name__ == "__main__":
    raise SystemExit(main())

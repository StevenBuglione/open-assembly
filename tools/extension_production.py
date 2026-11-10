"""Use the manifest production tools with an executable extension model."""

from dataclasses import dataclass
import json
from pathlib import Path
import runpy
import sys

from extension_abi import stable_abi_evidence
from gate import GateError, nm_symbols
from phase1 import build_case
from runtime_manifest_gate import mutate_function, timed_packets, trace_function
from spec import ROOT, keys, matching, read_toml, regular_file, relative_path, sha256_file, version_one

ABI_FIXTURE = Path("tests/phase2/abi.asm")
CASE = r"[a-z][a-z0-9-]*"


@dataclass(frozen=True)
class Plan:
    abi: str
    trace: str
    mutations: tuple
    fuzz: str
    model: Path
    record_sizes: tuple


def production_plans(package, probes):
    if not package.oracle.startswith("reference:"):
        raise GateError("a pinned-suite adapter for the timed extension oracle is pending")
    relative = package.tests / "production.toml"
    if not (ROOT / relative).is_file():
        raise GateError(f"coverage, mutation and timed fuzzing require {relative}")
    path = regular_file(ROOT, relative, "extension production plan")
    data = read_toml(path)
    keys(data, {"schema", "function"}, path)
    version_one(data["schema"], path)
    if type(data["function"]) is not list:
        raise GateError(f"{path}: expected an array of production plans")
    cases = {probe.case.name: probe for probe in probes}
    plans = {}
    for row in data["function"]:
        keys(row, {"symbol", "abi", "trace", "mutations", "fuzz", "model", "record_size", "result_size"}, path)
        symbol = matching(row["symbol"], r"[a-z][a-z0-9_]*", path)
        if symbol not in package.functions or symbol in plans:
            raise GateError(f"{path}: expected a unique package function, got {symbol}")

        def case(value):
            name = matching(value, CASE, path)
            if name not in cases or symbol not in cases[name].case.requires:
                raise GateError(f"{path}: {name} must directly exercise {symbol}")
            return name

        abi, trace, fuzz = (case(row[key]) for key in ("abi", "trace", "fuzz"))
        abi_probe = cases[abi].case
        if ABI_FIXTURE not in abi_probe.sources or not {"native", "qemu"} <= set(abi_probe.backends):
            raise GateError(f"{path}: ABI case must run the shared SysV probe natively and in QEMU")
        fuzz_probe = cases[fuzz]
        if (fuzz_probe.files or fuzz_probe.wraps or fuzz_probe.input_bytes or
                len(fuzz_probe.case.sources) != 1 or fuzz_probe.case.sources[0].suffix != ".c"):
            raise GateError(f"{path}: fuzz requires a single direct C packet fixture")
        mutations = row["mutations"]
        if type(mutations) is not dict or not mutations:
            raise GateError(f"{path}: mutation cases must name their semantic rejection codes")
        for codes in mutations.values():
            if (type(codes) is not list or not codes or any(type(code) is not int or not 1 <= code <= 125
                                                            for code in codes) or len(codes) != len(set(codes))):
                raise GateError(f"{path}: expected unique positive mutation rejection codes")
        widths = (row["record_size"], row["result_size"])
        if any(type(width) is not int or not 1 <= width <= 256 for width in widths):
            raise GateError(f"{path}: input and result record sizes must be 1 through 256 bytes")
        model = Path(relative_path(row["model"], path))
        if not model.is_relative_to(Path("tests/oracle") / package.name) or model.suffix != ".py":
            raise GateError(f"{path}: reference model must be Python under tests/oracle/{package.name}")
        regular_file(ROOT, model, "extension reference model")
        plans[symbol] = Plan(abi, trace, tuple((case(name), tuple(codes)) for name, codes in mutations.items()),
                             fuzz, model, widths)
    if plans.keys() != package.functions.keys():
        raise GateError(f"{path}: missing production plans for " + ", ".join(sorted(package.functions.keys() - plans.keys())))
    return plans, cases


def verify_dependencies(project, packages, current_inputs):
    for package in packages[:-1]:
        path = regular_file(ROOT, f"build/evidence/extension-{package.name}.json", "extension dependency")
        data = json.loads(path.read_text(encoding="utf-8"))
        if (data.get("schema_version") != 1 or data.get("scope") != "extension-package"
                or data.get("package") != package.name or data.get("outcome") != "pass"
                or data.get("production_verified") is not True or data.get("inputs") != current_inputs
                or data.get("checks", {}).get("full_production", {}).get("outcome") != "pass"):
            raise GateError(f"{package.name}: extension dependency lacks fresh production evidence")
        if package.stability == "stable" and not stable_abi_evidence(
                package, data["checks"].get("stable_abi"), current_inputs):
            raise GateError(f"{package.name}: stable extension dependency lacks frozen ABI evidence")
    dependencies = {name for package in packages for spec in package.functions.values() for name in spec.deps
                    if name in project.functions}
    if dependencies:
        states = runpy.run_path(str(ROOT / "tools/queue"))["states"](project)
        pending = sorted(name for name in dependencies if states[name].status != "verified")
        if pending:
            raise GateError("extension runtime dependencies lack fresh production evidence: " + ", ".join(pending))


def verify_production(package, plans, probes, directory, runtime, record):
    record["functions"] = {}
    for symbol, plan in plans.items():
        spec = package.functions[symbol]
        source = package.source(symbol)
        work = directory / f"production-{symbol}"
        work.mkdir()
        original = directory / "first" / f"{symbol}.o"
        item = record["functions"][symbol] = {"outcome": "fail", "source": str(source),
                                                "source_sha256": sha256_file(source),
                                                "object_sha256": sha256_file(original)}
        log = item["abi_commands"] = []
        abi_case = probes[plan.abi].case
        c_objects = [directory / abi_case.name / "first" / f"test-{i}.o"
                     for i, path in enumerate(abi_case.sources) if path.suffix == ".c"]
        if not any(nm_symbols(log, obj, ["-g", "-u"]).get("phase2_abi_probe") == "U" for obj in c_objects):
            raise GateError(f"{symbol}: ABI fixture omits the direct SysV trampoline call")
        trace = item["branch_coverage"] = {"outcome": "fail", "commands": [], "runs": []}
        trace_function(symbol, source, original, probes[plan.trace], work / "coverage", runtime, trace)
        mutation = item["production_mutation"] = {"outcome": "fail", "operators": []}
        mutate_function(symbol, spec, source, original, probes, plan, work / "mutation", runtime, mutation)
        fuzz = item["differential_fuzz"] = {"outcome": "fail", "commands": [],
                                            "oracle": package.oracle, "model": str(plan.model),
                                            "model_sha256": sha256_file(plan.model)}
        probe = probes[plan.fuzz]
        binary, fuzz["artifacts"] = build_case(probe.case, work / "packets", runtime, fuzz["commands"])
        commands = {"candidate": [str(binary.resolve())], "reference": [sys.executable, str(plan.model.resolve())]}
        timed_packets(symbol, probe, plan.record_sizes, work, commands, fuzz)
        item["outcome"] = "pass"
    record["outcome"] = "pass"

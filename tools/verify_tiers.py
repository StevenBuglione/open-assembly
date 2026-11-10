"""Run the nightly or tagged release matrix and validate its exact evidence."""

import argparse
from collections import Counter
import json
import math
import os
from pathlib import Path
import re
import runpy
import shutil
import signal
from statistics import median
import subprocess
import sys
import tempfile
from time import monotonic, time_ns

from extension_abi import stable_abi_evidence
from extension_build import dependency_order
from extensions import load_packages
from gate import BUILD, EVIDENCE, GateError, checked, identify_tools, verify_setup, write_evidence
from math_production import SCOPE as MATH_WRAPPER_SCOPE, SECONDS as MATH_WRAPPER_SECONDS, WRAPPERS
from math_production import math_inputs as math_wrapper_inputs
from musl_authorship import ARCHIVE_SHA256 as MUSL_ARCHIVE_SHA, POLICY as AUTHORSHIP_POLICY
from musl_authorship import inputs as authorship_inputs
from phase1 import RUNTIME_SRC, build_runtime, phase1_inputs
from phase2 import phase2_functions
from phase11_platform import SECCOMP_CASES, boot_cases, inputs as platform_inputs, verify_boot_cases, write_boot_header
from phase11_vdso_benchmark import inputs as vdso_inputs
from production import SCALAR_FUNCTIONS, source_paths
from runtime_manifest_gate import (ALLOCATOR_FUNCTIONS, FILE_MUTATION_FAILURES, IO_FUNCTIONS,
                                   FUZZ_SECONDS as PACKET_FUZZ_SECONDS, FUZZ_SEED as PACKET_FUZZ_SEED,
                                   PLANS as MANIFEST_PLANS,
                                   REQUIRED_CHECKS as MANIFEST_CHECKS, STAT_ENGINE, STREAM_FAILURES, STREAM_WRAPPER_SUFFIX,
                                   bind_descriptorless_scope, check_stat_archive, manifest_dependency_bindings,
                                   manifest_inputs, manifest_stat_binding, pending_dependency)
from upstream_conformance import PINS as UPSTREAM_PINS, inputs as upstream_inputs
from spec import ROOT, SpecError, has_runtime_entry, load_project, regular_file, relative_path, sha256_file, snapshot_inputs

PHASES = (
    "phase0", "phase1", "phase2", "production-scalars", "production-linux-files", "production-linux-io",
    "phase3", "verify-allocator-wrappers", "phase4", "verify-stream-indicators", "phase5",
    "phase6-files", "production-stat", "production-open", "production-paths", "phase6-fcntl", "phase6-compat", "phase6-busybox",
    "phase6-lua", "phase6-zlib", "phase6-sqlite", "phase6-sqlite-concurrency", "phase6-process",
    "production-process-identity", "production-pipes", "production-wait", "production-exec",
    "phase6-signal", "phase6-jump", "phase6-time", "phase6-calendar",
    "phase6-zone", "phase6-luafiles", "phase6-spawn", "phase6-shell", "phase6-path", "phase6-strftime",
    "phase7-exact", "phase7-transcendental", "phase7-complex", "verify-math-wrappers",
    "phase8-lifecycle", "phase8-fork", "phase8-sync", "phase8-c11", "phase8-openposix", "phase8-detectors",
    "phase8-compiler-atomics",
    "phase9-multibyte", "phase9-bulk", "phase9-worker", "phase9-worker-sync", "phase9-wide", "production-wide-core",
    "phase9-libc-test", "phase9-stdio", "phase9-narrow-wide", "phase9-wctype",
    "phase10-endpoints", "phase10-inet", "phase10-netdb", "phase10-dns", "phase10-addrconfig",
    "phase10-dns-failover", "phase10-dns-options",
    "phase10-http",
    "phase10-terminal", "phase10-libc-test", "phase10-glob", "phase10-regex",
    "phase10-gnulib", "phase10-native-ltp", "extension-json-upstream", "phase11-vdso",
    "phase11-static-pie", "phase11-allocator", "phase11-copy-benchmark", "phase11-allocator-benchmark",
    "phase11-vdso-benchmark", "phase11-seccomp", "phase11-old-kernel", "scan-musl-authorship",
)
EXTRA = ("fcntl-production", "extension-control", "extension-packages", "math-campaigns")
FUZZ_SECONDS = 300
DEFAULT_CAMPAIGN_ROOT = "build/phase7-campaign"
MANIFEST_PRODUCTION_GROUPS = {
    "production-process-identity": ("getpid", "getppid"),
    "production-pipes": ("pipe", "pipe2"),
    "production-open": ("open", "openat"),
    "production-paths": ("readlink", "unlink", "rmdir"),
    "production-wait": ("waitpid", "wait"),
    "production-exec": ("execve", "execv"),
    "production-stat": ("fstat", "fstatat", "stat", "lstat"),
    "production-wide-core": ("wcslen", "wcscmp", "wcsncmp", "wmemchr"),
}
SCOPED_WRAPPER_BATCHES = {
    "verify-allocator-wrappers": ("allocator-wrapper", ALLOCATOR_FUNCTIONS),
    "verify-stream-indicators": (STREAM_WRAPPER_SUFFIX, frozenset(STREAM_FAILURES)),
}


def evidence_json(path):
    def unique(pairs):
        result = {}
        for name, value in pairs:
            if name in result:
                raise GateError(f"{path}: duplicate evidence key {name}")
            result[name] = value
        return result

    def nonfinite(value):
        raise GateError(f"{path}: invalid JSON number {value}")

    with path.open(encoding="utf-8") as stream:
        return json.load(stream, object_pairs_hook=unique, parse_constant=nonfinite)


def report_file(root, filename, started):
    if Path(filename).name != filename:
        raise GateError(f"{filename}: expected a report filename")
    relative = relative_path(f"build/evidence/{filename}", "tier evidence")
    path = regular_file(root, relative, "tier evidence")
    if path.stat().st_mtime_ns < started:
        raise GateError(f"{filename}: no fresh report from this invocation")
    raw = evidence_json(path)
    if type(raw) is not dict or type(raw.get("schema_version")) is not int or raw["schema_version"] != 1:
        raise GateError(f"{filename}: invalid evidence schema")
    return path, raw


def fresh_report(root, filename, scope, started):
    path, data = report_file(root, filename, started)
    if data.get("outcome") != "pass" or data.get("scope") != scope:
        raise GateError(f"{filename}: expected a passing {scope} report")
    hashes = data.get("inputs")
    if type(hashes) is not dict or not {"Makefile", "devenv.lock"} <= hashes.keys():
        raise GateError(f"{filename}: missing source-bound identities")
    current = snapshot_inputs(root, hashes)
    if current != hashes:
        changed = [name for name in current if current[name] != hashes[name]]
        raise GateError(f"{filename}: stale evidence inputs: {', '.join(changed[:8])}")
    return path, data



def production_child(started, name, scope, item):
    report, record = fresh_report(ROOT, f"{name}.production.json", scope, started)
    if (type(item) is not dict or item.get("outcome") != "pass" or record.get("function") != name
            or item.get("evidence_sha256") != sha256_file(report)):
        raise GateError(f"invalid child production evidence for {name}")
    return record


def batch_report(started, name, functions):
    path, data = report_file(ROOT, f"{name}.json", started)
    if (data.get("outcome") != "pass" or data.get("scope") != f"{name}-batch"
            or data.get("full_scope") is not True or data.get("total") != len(functions)
            or data.get("passed") != len(functions) or set(data.get("functions", {})) != set(functions)):
        raise GateError(f"{name}.json: incomplete production batch")
    return path, data


def engine_fuzz(record, name):
    engine = record.get("checks", {}).get("engine_fuzz", {})
    if (record.get("production_verified") is not True or engine.get("outcome") != "pass"
            or engine.get("requested_seconds") != FUZZ_SECONDS
            or type(engine.get("elapsed_seconds")) is not int or engine["elapsed_seconds"] < FUZZ_SECONDS
            or type(engine.get("runs")) is not int or engine["runs"] < 1):
        raise GateError(f"missing timed libFuzzer evidence for {name}")


def packet_fuzz(record, name, *, production_verified=True):
    fuzz = record.get("checks", {}).get("differential_fuzz", {})
    if type(fuzz) is not dict:
        raise GateError(f"invalid timed packet check for {name}")
    hashes = fuzz.get("sha256")
    elapsed = fuzz.get("elapsed_s")
    if (record.get("production_verified") is not production_verified or fuzz.get("outcome") != "pass"
            or type(elapsed) not in (int, float) or elapsed < PACKET_FUZZ_SECONDS
            or (type(elapsed) is float and not math.isfinite(elapsed))
            or type(fuzz.get("records")) is not int or fuzz["records"] < 1
            or fuzz.get("runs") != ["candidate", "glibc", "musl"]
            or type(hashes) is not dict or hashes.keys() != {"candidate", "glibc", "musl", "input"}
            or any(type(value) is not str or re.fullmatch(r"[0-9a-f]{64}", value) is None
                   for value in hashes.values())
            or len({hashes[key] for key in ("candidate", "glibc", "musl")}) != 1):
        raise GateError(f"missing timed candidate/glibc/musl packet evidence for {name}")


def stat_tier_binding(started):
    binding = manifest_stat_binding()
    scopes = {STAT_ENGINE: "production-private-dependency", "__errno_location": "production-runtime-function"}
    if binding["functions"].keys() != scopes.keys():
        raise GateError("stat tier requires the exact helper and errno dependency proofs")
    for name, scope in scopes.items():
        path, _ = fresh_report(ROOT, f"{name}.production.json", scope, started)
        if binding["functions"][name]["evidence_sha256"] != sha256_file(path):
            raise GateError(f"{name}: stat tier dependency report changed after binding")
    return binding


def manifest_production_reports(started, group):
    children = {}
    sources = source_paths()
    stat_binding = stat_tier_binding(started) if group == "production-stat" else None
    for name in MANIFEST_PRODUCTION_GROUPS[group]:
        path, record = fresh_report(ROOT, f"{name}.production.json", "production-runtime-manifest-function", started)
        hashes, checks = record["inputs"], record.get("checks")
        if record.get("function") != name or hashes != manifest_inputs(name):
            raise GateError(f"{name}: incomplete manifest production identity or input snapshot")
        if (type(checks) is not dict or not MANIFEST_CHECKS <= checks.keys()
                or any(type(item) is not dict or item.get("outcome") != "pass" for item in checks.values())):
            raise GateError(f"{name}: incomplete manifest production checks")
        source = sources[name].as_posix()
        candidate = checks["candidate_build"]
        object_hash = candidate.get("object_sha256")
        if (candidate.get("source") != source or source not in hashes or candidate.get("source_sha256") != hashes[source]
                or type(object_hash) is not str or re.fullmatch(r"[0-9a-f]{64}", object_hash) is None):
            raise GateError(f"{name}: manifest production evidence does not bind the candidate source and object")
        packet_fuzz(record, name)
        if stat_binding is not None:
            if checks.get("dependency_closure") != stat_binding:
                raise GateError(f"{name}: stat tier dependency binding differs from the fresh proofs")
            builds = checks["runtime_build"].get("artifacts")
            if (type(builds) is not dict or builds.keys() != {"first", "second"}
                    or builds["first"] != builds["second"]):
                raise GateError(f"{name}: stat tier requires complete matching candidate runtime builds")
            check_stat_archive(stat_binding, builds["first"])
        if required := MANIFEST_PLANS[name].required_production:
            bindings = manifest_dependency_bindings(required)
            builds = checks["runtime_build"].get("artifacts")
            first = builds.get("first") if type(builds) is dict else None
            archive = first.get("libopenasm.a") if type(first) is dict else None
            if (checks.get("production_dependencies") != bindings
                    or any(dep not in children or item["evidence_sha256"] != children[dep]["evidence_sha256"]
                           or item["archive_sha256"] != archive for dep, item in bindings["functions"].items())):
                raise GateError(f"{name}: manifest production dependency differs from this invocation's child and archive")
        children[name] = {"outcome": "pass", "evidence": path.relative_to(ROOT).as_posix(),
                          "evidence_sha256": sha256_file(path)}
    return children


def supplemental_batch(started, name):
    scalars = name == "production-scalars"
    functions = {"production-scalars": SCALAR_FUNCTIONS, "production-linux-files": FILE_MUTATION_FAILURES,
                 "production-linux-io": IO_FUNCTIONS}[name]
    path, data = batch_report(started, name, functions)
    scope = "production-function" if scalars else "production-runtime-manifest-function"
    check = engine_fuzz if scalars else packet_fuzz
    for symbol, item in data["functions"].items():
        check(production_child(started, symbol, scope, item), symbol)
    return path, data


def scoped_wrapper_report(started, target):
    suffix, functions = SCOPED_WRAPPER_BATCHES[target]
    scope = f"{suffix}-verification"
    filename = f"{suffix}s.json"
    batch, data = report_file(ROOT, filename, started)
    children = data.get("functions")
    if (data.get("scope") != f"{scope}-batch" or data.get("outcome") != "pass"
            or data.get("production_verified") is not False or data.get("full_scope") is not True
            or any(type(data.get(key)) is not int or data[key] != len(functions) for key in ("total", "passed"))
            or type(children) is not dict or children.keys() != functions):
        raise GateError(f"{filename}: incomplete scoped wrapper batch")
    sources = source_paths()
    runtimes = set()
    for name, item in children.items():
        child, record = fresh_report(ROOT, f"{name}.{suffix}.json", scope, started)
        inputs, checks = record["inputs"], record.get("checks")
        required = MANIFEST_CHECKS - {"branch_coverage"} if name == "fileno" else MANIFEST_CHECKS
        if (type(item) is not dict or item.get("outcome") != "pass"
                or item.get("evidence") != child.relative_to(ROOT).as_posix()
                or item.get("evidence_sha256") != sha256_file(child)
                or record.get("function") != name or record.get("production_verified") is not False
                or inputs != manifest_inputs(name) or type(checks) is not dict
                or checks.get("dependency_closure") != pending_dependency(MANIFEST_PLANS[name])
                or any(type(checks.get(key)) is not dict or checks[key].get("outcome") != "pass"
                       for key in required)):
            raise GateError(f"{name}: invalid fresh scoped wrapper evidence or missing pending shared closure")
        source = sources.get(name)
        if source is None:
            raise GateError(f"{name}: missing scoped wrapper source")
        if name == "fileno":
            branch = checks.get("branch_coverage")
            edges = branch.get("edges") if type(branch) is dict else None
            if (type(edges) is not list or len(edges) != 2
                    or any(type(edge) is not dict or type(edge.get("covered")) is not bool
                           or edge.get("source") != source.as_posix()
                           or edge.get("branch") not in ("taken", "fallthrough") for edge in edges)
                    or edges[0]["branch"] == edges[1]["branch"]):
                raise GateError("fileno: missing raw descriptor branch evidence")
            expected = branch.copy()
            try:
                bind_descriptorless_scope(ROOT / source, expected, inputs)
            except (GateError, KeyError, TypeError) as error:
                raise GateError("fileno: invalid raw descriptor branch evidence") from error
            if expected != branch:
                raise GateError("fileno: descriptor branch scope differs from the current source review")
        candidate = checks["candidate_build"]
        artifacts = checks["runtime_build"].get("artifacts")
        if type(artifacts) is not dict or artifacts.keys() != {"first", "second"}:
            raise GateError(f"{name}: missing reproducible scoped runtime artifacts")
        first = artifacts["first"]
        object_path = Path("obj") / source.relative_to(RUNTIME_SRC).with_suffix(".o")
        if (type(first) is not dict or first != artifacts["second"]
                or candidate.get("source") != source.as_posix()
                or source.as_posix() not in inputs
                or candidate.get("source_sha256") != inputs.get(source.as_posix())
                or candidate.get("object_sha256") != first.get(object_path.as_posix())
                or any(type(digest) is not str or re.fullmatch(r"[0-9a-f]{64}", digest) is None
                       for digest in (first.get("crt1.o"), first.get("libopenasm.a"), candidate.get("object_sha256")))):
            raise GateError(f"{name}: scoped wrapper evidence does not bind the source, object, and runtime")
        runtimes.add((first["crt1.o"], first["libopenasm.a"]))
        packet_fuzz(record, name, production_verified=False)
        fuzz = checks["differential_fuzz"]
        if fuzz.get("seed") != PACKET_FUZZ_SEED or fuzz["records"] % 512:
            raise GateError(f"{name}: incomplete seeded packet batches")
    if len(runtimes) != 1:
        raise GateError(f"{filename}: scoped checks used different runtime artifacts")
    return batch, data


def math_wrapper_report(started):
    path, data = report_file(ROOT, "math-wrappers.json", started)
    children = data.get("functions")
    if (data.get("scope") != f"{MATH_WRAPPER_SCOPE}-batch" or data.get("outcome") != "pass"
            or data.get("production_verified") is not False or data.get("full_scope") is not True
            or data.get("total") != len(WRAPPERS) or data.get("passed") != len(WRAPPERS)
            or type(children) is not dict or children.keys() != WRAPPERS.keys()):
        raise GateError("math wrapper batch does not contain all four scoped results")
    inputs = math_wrapper_inputs()
    required = ("abi", "branch_coverage", "candidate_build", "differential_fuzz", "generated_outputs",
                "generated_stub", "native_oracles", "production_mutation")
    archives = set()
    for name, (operation, width, engine) in WRAPPERS.items():
        item = children[name]
        report, record = fresh_report(ROOT, f"{name}.math-wrapper.json", MATH_WRAPPER_SCOPE, started)
        checks = record.get("checks")
        if (type(item) is not dict or item.get("outcome") != "pass"
                or item.get("evidence") != report.relative_to(ROOT).as_posix()
                or item.get("evidence_sha256") != sha256_file(report)
                or record.get("function") != name or record.get("operation") != operation
                or record.get("format_bits") != width or record.get("inputs") != inputs
                or record.get("production_verified") is not False or record.get("wrapper_checks_passed") is not True
                or type(checks) is not dict or checks.get("dependency_closure") != {"outcome": "pending", "engine": engine}
                or any(type(checks.get(key)) is not dict or checks[key].get("outcome") != "pass" for key in required)):
            raise GateError(f"{name}: invalid fresh scoped wrapper evidence or missing pending engine closure")
        archive = checks["candidate_build"].get("archive_sha256")
        fuzz = checks["differential_fuzz"]
        if (type(archive) is not str or not re.fullmatch(r"[0-9a-f]{64}", archive)
                or fuzz.get("oracle") != "reference:mpfr" or fuzz.get("requested_seconds") != MATH_WRAPPER_SECONDS
                or type(fuzz.get("elapsed_s")) not in (int, float) or fuzz["elapsed_s"] < MATH_WRAPPER_SECONDS
                or type(fuzz.get("records")) is not int or fuzz["records"] < 1):
            raise GateError(f"{name}: missing archive identity or timed MPFR wrapper evidence")
        archives.add(archive)
    if len(archives) != 1:
        raise GateError("math wrapper checks did not use the same reproducible runtime archive")
    return path, data


def phase2_report(started):
    path, data = batch_report(started, "phase2", phase2_functions())
    for name, item in data["functions"].items():
        engine_fuzz(production_child(started, name, "production-function", item), name)
    for field, name, scope in (
        ("shared_integer_scanner", "__al_strtox", "production-private-dependency"),
        ("runtime_tls_accessor", "__errno_location", "production-runtime-function"),
        ("bulk_memcpy", "__al_memcpy_bulk", "production-private-dependency"),
    ):
        production_child(started, name, scope, data.get(field))
    return path, data


def invoke(command, record, *, timeout, environment=None):
    started = monotonic()
    with subprocess.Popen(list(map(str, command)), cwd=ROOT, env=environment,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True) as child:
        try:
            stdout, stderr = child.communicate(timeout=timeout)
        except subprocess.TimeoutExpired:
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            stdout, stderr = child.communicate()
            record["timed_out"] = True
    record.update(command=list(map(str, command)), returncode=child.returncode,
                  elapsed_seconds=round(monotonic() - started, 3),
                  stdout=stdout.decode(errors="replace"), stderr=stderr.decode(errors="replace"))
    if record.get("timed_out"):
        raise GateError(f"{command[0]} exceeded its {timeout}-second tier budget")
    if child.returncode:
        detail = (record["stderr"] or record["stdout"]).strip()
        raise GateError(f"{command[0]} exited {child.returncode}: {detail[-1200:]}")


def extension_control(commit, record):
    with tempfile.TemporaryDirectory(prefix="extension-tier-", dir=BUILD) as work:
        clone = Path(work) / "checkout"
        log = record["commands"] = []
        checked(log, ["git", "clone", "--shared", "--no-checkout", ROOT, clone], timeout=120)
        checked(log, ["git", "-C", clone, "checkout", "--detach", commit], timeout=120)
        unit = {}
        log.append(unit)
        invoke(["python3", clone / "tests/tooling/test_extension_scaffold.py"], unit, timeout=30)
        setup = {}
        log.append(setup)
        started = time_ns()
        invoke([clone / "tests/tooling/extensions/setup.sh"], setup, timeout=1200)
        path, data = fresh_report(clone, "extension-word_math.json", "extension-package", started)
        if (data.get("package") != "word_math" or data.get("production_verified") is not False
                or data.get("checks", {}).get("full_production", {}).get("outcome") != "pending"
                or data.get("checks", {}).get("stub_controls", {}).get("outcome") != "pass"):
            raise GateError("isolated extension smoke did not establish its scoped verification")
        observed = {"scoped": path}
        for name, phrase in (("unimplemented", "unimplemented extension functions:"),
                             ("required", "coverage, mutation and timed fuzzing require")):
            control = regular_file(clone, f"build/extension-controls/{name}.json", "extension tier control")
            data = evidence_json(control)
            if (control.stat().st_mtime_ns < started or data.get("outcome") != "fail"
                    or data.get("package") != "word_math" or phrase not in data.get("error", "")):
                raise GateError(f"extension {name} control did not reject the required defect")
            observed[name] = control
        evidence = record["reports"] = {}
        for name, path in observed.items():
            archived = write_evidence(f"tier-extension-{name}", evidence_json(path))
            digest = sha256_file(archived)
            if digest != sha256_file(path):
                raise GateError(f"the archived extension {name} evidence changed bytes")
            evidence[name] = {"path": archived.resolve().relative_to(ROOT).as_posix(), "sha256": digest}



def check_extension_production(data, package, inputs):
    name = package.name
    checks = data.get("checks", {})
    production = checks.get("full_production", {})
    controls = checks.get("stub_controls", {})
    functions, stubs = production.get("functions"), controls.get("symbols")
    if (data.get("package") != name or data.get("stability") != package.stability
            or data.get("oracle") != package.oracle or data.get("dependencies") != list(package.dependencies)
            or data.get("inputs") != inputs or data.get("production_verified") is not True
            or production.get("outcome") != "pass" or type(functions) is not dict
            or functions.keys() != package.functions.keys()
            or controls.get("outcome") != "pass" or type(stubs) is not dict
            or stubs.keys() != package.functions.keys()):
        raise GateError(f"{name}: incomplete current extension production evidence")
    if package.stability == "stable" and not stable_abi_evidence(package, checks.get("stable_abi"), inputs):
        raise GateError(f"{name}: incomplete stable extension ABI evidence")
    for symbol, item in functions.items():
        source = package.source(symbol).as_posix()
        edges = item.get("branch_coverage", {})
        mutants = item.get("production_mutation", {})
        fuzz = item.get("differential_fuzz", {})
        digests = fuzz.get("sha256", {})
        if (item.get("outcome") != "pass" or stubs[symbol].get("outcome") != "pass"
                or item.get("source") != source or source not in inputs
                or item.get("source_sha256") != inputs[source]
                or edges.get("outcome") != "pass" or type(edges.get("total")) is not int
                or edges.get("covered") != edges["total"] or edges["total"] < 0
                or mutants.get("outcome") != "pass" or mutants.get("threshold_percent") != 90
                or type(mutants.get("total")) is not int or type(mutants.get("killed")) is not int
                or not 0 < mutants["killed"] <= mutants["total"]
                or 100 * mutants["killed"] < 90 * mutants["total"]
                or fuzz.get("outcome") != "pass" or type(fuzz.get("elapsed_s")) not in (int, float)
                or fuzz["elapsed_s"] < 60 or type(fuzz.get("records")) is not int or fuzz["records"] < 1
                or fuzz.get("oracle") != package.oracle or fuzz.get("model") not in inputs
                or fuzz.get("model_sha256") != inputs[fuzz["model"]]
                or set(digests) != {"candidate", "reference", "input"}
                or digests["candidate"] != digests["reference"]):
            raise GateError(f"{symbol}: incomplete extension ABI, coverage, mutation or differential evidence")


def extension_packages(record, inputs):
    declared = load_packages(load_project())
    packages = {item.name: item for name in sorted(declared) for item in dependency_order(declared, name)}
    children = record["packages"] = {}
    for name, package in packages.items():
        child = children[name] = {"outcome": "pending", "dependencies": {}}
        unmet = [dependency for dependency in package.dependencies
                 if children[dependency]["outcome"] != "pass"]
        if unmet:
            child["reason"] = "Requires current passing package evidence for " + ", ".join(unmet)
            continue
        missing = [path.as_posix() for path in (package.tests / "manifest.toml", package.tests / "production.toml")
                   if not (ROOT / path).is_file()]
        if missing:
            child.update(reason="Requires an independent manifest and production plan.", missing=missing)
            continue
        started = time_ns()
        child["outcome"] = "fail"
        try:
            for dependency in package.dependencies:
                prior = children[dependency]
                path = regular_file(ROOT, prior["evidence"], f"{name} extension dependency")
                if sha256_file(path) != prior["evidence_sha256"]:
                    raise GateError(f"{name}: current {dependency} evidence was replaced")
                child["dependencies"][dependency] = prior["evidence_sha256"]
            invoke(["tools/extension-gate", name, "--require-production"], child,
                   timeout=max(1800, 300 + 180 * len(package.functions)))
            path, data = fresh_report(ROOT, f"extension-{name}.json", "extension-package", started)
            check_extension_production(data, package, inputs)
            child.update(outcome="pass", evidence=path.relative_to(ROOT).as_posix(),
                         evidence_sha256=sha256_file(path))
            print(f"PASS extension production {name}", flush=True)
        except (GateError, OSError, SpecError, ValueError) as error:
            child["error"] = str(error)
            print(f"FAIL extension production {name}: {error}", file=sys.stderr, flush=True)
    for child in children.values():
        if child["outcome"] == "pass" and sha256_file(ROOT / child["evidence"]) != child["evidence_sha256"]:
            child.update(outcome="fail", error="Extension evidence changed before the tier finished.")
    outcomes = {child["outcome"] for child in children.values()}
    return "fail" if "fail" in outcomes else "pending" if "pending" in outcomes else "pass"


def check_allocator_benchmark(data):
    workload = {"pairs": 9, "min_preflight_idle": 0.9, "geometric_mean_limit": 1.25,
                "per_workload_limit": 1.5, "max_rss_excess_kib": 8192}
    measurements = data.get("measurements")
    if data.get("workload") != workload or type(measurements) is not dict or set(measurements) != {
            "small", "mixed", "growth", "rss"}:
        raise GateError("allocator benchmark did not use the declared workload and thresholds")

    ratios = []
    for name, result in measurements.items():
        samples = result.get("samples", {}) if type(result) is dict else {}
        if type(samples) is not dict or set(samples) != {"openasm", "musl"}:
            raise GateError(f"allocator benchmark {name} is missing paired observations")
        checksums = set()
        observations = {}
        for kind, rows in samples.items():
            if type(rows) is not list or len(rows) != workload["pairs"]:
                raise GateError(f"allocator benchmark {name} is missing paired observations")
            observations[kind] = []
            for pair, row in enumerate(rows, 1):
                if type(row) is not dict or row.get("pair") != pair or type(row.get("checksum")) is not int:
                    raise GateError(f"allocator benchmark {name} has an invalid pair")
                checksums.add(row["checksum"])
                if name == "rss":
                    fields = ("baseline_kib", "peak_kib", "retained_kib", "released_kib")
                    if any(type(row.get(key)) is not int or row[key] <= 0 for key in fields):
                        raise GateError("allocator benchmark has invalid RSS samples")
                    baseline, peak, retained, released = (row[key] for key in fields)
                    if peak <= baseline:
                        raise GateError("allocator benchmark has no RSS growth")
                    observations[kind].append((retained - baseline, released - baseline))
                else:
                    elapsed, cpu = (row.get(key) for key in ("nanoseconds", "cpu_nanoseconds"))
                    if (type(elapsed) is not int or type(cpu) is not int or min(elapsed, cpu) <= 0
                            or elapsed - cpu > max(50_000, elapsed * (1 - workload["min_preflight_idle"]))):
                        raise GateError(f"allocator benchmark {name} has invalid timing samples")
                    observations[kind].append(elapsed)
        if len(checksums) != 1:
            raise GateError(f"allocator benchmark {name} checksum mismatch")
        if name == "rss":
            keys = ("retained_delta_kib", "released_delta_kib")
            excess = {key: median(point[i] for point in observations["openasm"]) -
                      median(point[i] for point in observations["musl"]) for i, key in enumerate(keys)}
            if result.get("openasm_excess_kib") != excess or max(excess.values()) > workload["max_rss_excess_kib"]:
                raise GateError("allocator benchmark exceeds or omits its RSS cap")
        else:
            ratio = median(observations["openasm"]) / median(observations["musl"])
            stated = result.get("ratio")
            if type(stated) not in (int, float) or stated != ratio or ratio > workload["per_workload_limit"]:
                raise GateError(f"allocator benchmark {name} exceeds or omits its timing cap")
            ratios.append(ratio)
    observed = data.get("geometric_mean")
    expected = math.exp(sum(math.log(ratio) for ratio in ratios) / len(ratios))
    if (type(observed) not in (int, float) or not 0 < observed <= workload["geometric_mean_limit"]
            or not math.isclose(observed, expected, rel_tol=1e-12)):
        raise GateError("allocator benchmark exceeds or omits its geometric mean cap")


OLD_KERNEL = "4.19.0-27-amd64"
OLD_KERNEL_SHA = "71947e2c7102ceb224b04b910c5761bc9f2a7986c2c8d868b5553dc8fef57747"


def check_seccomp(data):
    observations = data.get("observations")
    artifacts = data.get("artifacts", {}).get("seccomp")
    if (data.get("kernel_release") != os.uname().release or type(observations) is not dict
            or len(SECCOMP_CASES) != 9 or set(observations) != SECCOMP_CASES.keys()
            or data.get("inputs") != platform_inputs()
            or type(artifacts) is not dict or set(artifacts) != {"seccomp", "test-0.o"}
            or any(type(digest) is not str or re.fullmatch(r"[0-9a-f]{64}", digest) is None
                   for digest in artifacts.values())):
        raise GateError("seccomp evidence lacks the nine installed-filter paths and exact probe artifacts")
    binary = None
    for case, expected in SECCOMP_CASES.items():
        row = observations[case]
        command = row.get("command") if type(row) is dict else None
        if (type(command) is not list or len(command) != 2 or type(command[0]) is not str
                or Path(command[0]).name != "seccomp" or command[1] != case
                or (binary is not None and command[0] != binary)
                or row.get("returncode") != 0 or row.get("stderr") != "" or row.get("stdout") != expected):
            raise GateError(f"seccomp filter observation failed for {case}")
        binary = command[0]
    return list(SECCOMP_CASES)


def check_old_kernel(data):
    observations = data.get("observations")
    artifacts = data.get("artifacts", {})
    if (type(observations) is not dict or set(observations) != {"native", "guest"}
            or type(artifacts) is not dict or artifacts.get("kernel_sha256") != OLD_KERNEL_SHA
            or type(artifacts.get("initramfs_sha256")) is not str
            or re.fullmatch(r"[0-9a-f]{64}", artifacts["initramfs_sha256"]) is None
            or "nix/old-kernel.nix" not in data.get("inputs", {})
            or "qemu-system-x86_64" not in data.get("toolchain", {})):
        raise GateError("old-kernel evidence lacks the pinned QEMU-system boot identity")
    for label, release in (("native", os.uname().release), ("guest", OLD_KERNEL)):
        item = observations[label]
        if type(item) is not dict or type(item.get("stdout")) is not str:
            raise GateError(f"old-kernel evidence lacks complete {label} observations")
        command, append = item.get("command", []), item.get("append")
        required = ("startup-c-and-asm", "tls-thread-clone", "clock-and-allocation", "complete")
        lines = item["stdout"].splitlines()
        if (item.get("kernel_release") != release or item.get("returncode") != 0
                or item.get("stderr") != "" or type(command) is not list or not command
                or any(type(part) is not str for part in command)
                or not all(f"PASS platform {case}" in lines for case in required)
                or append not in ("append-unsupported", "append-offset")
                or f"PASS platform {append}" not in lines):
            raise GateError(f"old-kernel evidence lacks complete {label} observations")
        if label == "guest" and (Path(command[0]).name != "qemu-system-x86_64" or "-kernel" not in command
                                 or append != "append-unsupported" or item.get("clone3_raw") != -38):
            raise GateError("old-kernel evidence lacks the required boot and fallback proof")


    cases = boot_cases()
    observations = data.get("kernel_cases")
    expected = [case.name for case in cases]
    if len(expected) != 13 or type(observations) is not dict or set(observations) != set(expected):
        raise GateError("old-kernel evidence lacks the 13 paired native and guest cases")
    verify_boot_cases(data["observations"]["guest"]["stdout"], expected)
    with tempfile.TemporaryDirectory(prefix="tier-kernel-manifest-", dir=BUILD) as work:
        header = write_boot_header(cases, Path(work))
        if artifacts.get("guest_manifest_header_sha256") != sha256_file(header):
            raise GateError("old-kernel evidence does not bind the exact guest case manifest")
    silent = {"returncode": 0, "stdout": "", "stderr": ""}
    for case in cases:
        item = observations[case.name]
        if type(item) is not dict:
            raise GateError(f"old-kernel evidence lacks the paired result for {case.name}")
        hashes = item.get("artifacts")
        native = item.get("native")
        command = native.get("command") if type(native) is dict else None
        if (item.get("arguments") != case.args or item.get("environment") != case.env
                or item.get("oracle") != list(case.oracle)
                or type(hashes) is not dict or set(hashes) != {case.name, "test-0.o"}
                or any(type(digest) is not str or re.fullmatch(r"[0-9a-f]{64}", digest) is None
                       for digest in hashes.values())
                or type(command) is not list or not command or type(command[0]) is not str
                or Path(command[0]).name != case.name or command[1:] != case.args
                or any(native.get(field) != value for field, value in silent.items())
                or item.get("guest") != silent):
            raise GateError(f"old-kernel evidence lacks exact artifacts or paired results for {case.name}")
    return expected


def old_kernel(started, status, record):
    if status != 0:
        raise GateError(f"old-kernel container exited {status}")
    path, data = fresh_report(ROOT, "phase11-old-kernel.json", "phase11-old-kernel", started)
    paired_cases = check_old_kernel(data)
    record.update(evidence=path.relative_to(ROOT).as_posix(), evidence_sha256=sha256_file(path),
                  paired_cases=paired_cases)


def check_authorship(data, review, scan_hash, expected):
    classes = {"below-minimum", "clear", "no-matching-musl-symbol",
               "normalized-exact", "normalized-near", "normalized-containment"}
    rows = data.get("symbols")
    if (data.get("musl_archive_sha256") != MUSL_ARCHIVE_SHA
            or data.get("policy") != AUTHORSHIP_POLICY
            or type(data.get("candidate_archive_sha256")) is not str
            or re.fullmatch(r"[0-9a-f]{64}", data["candidate_archive_sha256"]) is None
            or type(rows) is not list or not rows
            or any(type(row) is not dict or type(row.get("symbol")) is not str
                   or type(row.get("classification")) is not str or row["classification"] not in classes
                   for row in rows)
            or {row["symbol"] for row in rows} != expected
            or data.get("counts") != dict(Counter(row["classification"] for row in rows))):
        raise GateError("musl authorship evidence lacks the pinned scan inventory")
    controls = data.get("controls", {})
    copied, distinct = controls.get("copied", {}), controls.get("distinct", {})
    if (controls.get("symbol") != "strlen" or copied.get("classification") != "normalized-exact"
            or copied.get("candidate") != copied.get("reference")
            or copied.get("similarity_per_mille") != 1000
            or copied.get("object_sha256") == controls.get("reference_member_sha256")
            or distinct.get("classification") != "clear"
            or distinct.get("reference") != copied.get("reference")):
        raise GateError("musl authorship evidence lacks the relocation and distinct controls")
    findings = [row for row in rows if row["classification"].startswith("normalized-")]
    if (review.get("scan_sha256") != scan_hash or review.get("scan_outcome") != "pass"
            or review.get("items") != findings):
        raise GateError("musl authorship review does not match the exact passing scan")
    return [row["symbol"] for row in findings]



def check_vdso_benchmark(data):
    workload = {
        "api": "time(NULL)", "calls_per_sample": 1000000, "pairs": 9,
        "median_ratio_limit": 1.5, "min_preflight_idle": 0.9,
        "raw_denial": {"time": "EACCES", "gettimeofday": "EACCES",
                       "clock_gettime": "EACCES except MONOTONIC and THREAD_CPUTIME_ID"},
    }
    if data.get("workload") != workload:
        raise GateError("vDSO benchmark differs from its predeclared workload")
    groups = {"openasm", "musl"}
    cpu = data.get("native_cpu", {})
    allowed, selected = cpu.get("allowed_cpus", []), cpu.get("cpu")
    fraction = cpu.get("idle_fractions", {}).get(str(selected))
    if (type(selected) is not int or selected not in allowed or type(fraction) not in (int, float)
            or not workload["min_preflight_idle"] <= fraction <= 1):
        raise GateError("vDSO benchmark did not use a qualified quiet CPU")
    qualification, measurements = data.get("qualification"), data.get("measurements")
    if (type(qualification) is not dict or set(qualification) != groups
            or type(measurements) is not dict or set(measurements) != groups):
        raise GateError("vDSO benchmark lacks its two qualified implementations")
    medians = {}
    for kind in sorted(groups):
        item = qualification[kind]
        command = item.get("command", [])
        if (len(command) != 2 or command[1] != "qualify" or Path(command[0]).name != f"benchmark-{kind}"
                or (item.get("returncode"), item.get("stdout"), item.get("stderr")) != (
                    0, "PASS realtime through vDSO with raw calls denied\n", "")):
            raise GateError(f"{kind} vDSO benchmark lacks actual raw-denial qualification")
        samples = measurements[kind]
        if type(samples) is not list or len(samples) != workload["pairs"]:
            raise GateError(f"{kind} vDSO benchmark lacks paired timings")
        for pair, sample in enumerate(samples, 1):
            wall, elapsed = sample.get("nanoseconds"), sample.get("cpu_nanoseconds")
            if (sample.get("pair") != pair or sample.get("valid_calls") != workload["calls_per_sample"]
                    or type(wall) is not int or type(elapsed) is not int or min(wall, elapsed) <= 0
                    or wall - elapsed > max(50000, wall * (1 - workload["min_preflight_idle"]))):
                raise GateError(f"{kind} vDSO benchmark has an invalid sample")
        medians[kind] = median(sample["nanoseconds"] for sample in samples)
    ratio = medians["openasm"] / medians["musl"]
    if (data.get("median_nanoseconds") != medians or data.get("ratio") != ratio
            or ratio > workload["median_ratio_limit"]):
        raise GateError("vDSO benchmark exceeds or omits its predeclared median ratio")


def check_addrconfig(data):
    backends = {"native", "qemu", "valgrind"}
    checks = data.get("checks", {})
    wire = checks.get("wire", {})
    observations = wire.get("backends", {})
    selection = checks.get("selection", {})
    stubs = checks.get("stubs", {})
    strata = wire.get("strata", {})
    if (wire.get("outcome") != "pass" or set(observations) != backends or set(selection) != backends
            or set(stubs) != {"__al_gai_addrconfig_parse", "getaddrinfo"}
            or any(item.get("outcome") != "pass" for item in stubs.values())
            or not strata or any(type(count) is not int or count < 1 for count in strata.values())
            or not {"seeded-data", "seeded-done", "seeded-partial", "seeded-interrupted"} <= strata.keys()
            or not {"docs/adr/0038-address-configuration.md", "tests/phase10/addrconfig/oracle.py"}
            <= data.get("inputs", {}).keys()):
        raise GateError("address-configuration evidence lacks its guarded, public or stub scope")
    records = sum(strata.values())
    digests = set()
    for backend in sorted(backends):
        edges = observations[backend]
        cases = selection[backend]
        if set(edges) != {"left", "right"} or set(cases) != {"real", "public"}:
            raise GateError(f"address-configuration evidence omits cases on {backend}")
        for edge in edges.values():
            digest = edge.get("output_sha256")
            if (edge.get("outcome") != "pass" or edge.get("records") != records
                    or type(digest) is not str or re.fullmatch(r"[0-9a-f]{64}", digest) is None):
                raise GateError(f"address-configuration guarded observations differ on {backend}")
            digests.add(digest)
        if any((row.get("status"), row.get("stdout"), row.get("stderr")) != (0, "", "")
               for row in cases.values()):
            raise GateError(f"address-configuration public observations differ on {backend}")
    if len(digests) != 1:
        raise GateError("address-configuration result bytes differ across guard edges or backends")


def check_upstream_subset(suite, data):
    _, prefix, archive, files = UPSTREAM_PINS[suite]
    if (data.get("upstream") != {"archive_root": prefix, "archive_sha256": archive, "files": files}
            or data.get("inputs") != upstream_inputs()):
        raise GateError(f"{suite} evidence omits exact upstream or project source identities")
    if suite == "gnulib":
        modes = {"lseek": ("files", "pipes", "closed"), "memchr": ("guard",)}
        labels = ("glibc", "musl", "candidate", "candidate-qemu", "candidate-memcheck")
        expected = {case: {f"{label}-{mode}": (0, "", "") for label in labels for mode in kinds}
                    for case, kinds in modes.items()}
        stubs = {"lseek": -signal.SIGABRT, "memchr": -signal.SIGABRT}
    else:
        expected = {case: {label: (0, f"LTP scoped pass={passes} fail=0 tmpdir={tmpdir}\n", "")
                           for label in ("glibc", "musl", "candidate")}
                    for case, passes, tmpdir in (("dup01", 2, 1), ("dup02", 2, 0), ("lseek01", 4, 1))}
        stubs = {"dup01": 1, "lseek01": 1}
    checks = data.get("checks", {})
    for case, required in expected.items():
        result = checks.get(case, {})
        runs = result.get("runs", {})
        if (result.get("outcome") != "pass"
                or set(runs) != set(required) | ({"stub"} if case in stubs else set())
                or any(tuple(runs[label].get(field) for field in ("status", "stdout", "stderr")) != want
                       for label, want in required.items())
                or (case in stubs and (runs["stub"].get("status") != stubs[case]
                                       or not runs["stub"].get("stderr")
                                       or not result.get("stub_source_sha256")))):
            raise GateError(f"{suite} {case} lacks its pinned conformance observations")


def gate(name, record):
    environment = {**os.environ, "LC_ALL": "C", "OPEN_ASSEMBLY_LIBFUZZER_SECONDS": str(FUZZ_SECONDS)}
    started = time_ns()
    command, timeout = ["make", "--no-print-directory", name], 1800
    filename, scope = f"{name}.json", name
    if name == "phase2":
        timeout = 7200
    elif name == "phase7-exact":
        command = ["python3", "tools/phase7_exact.py", "--exhaustive-suite", "rounding"]
        timeout = 10800
    elif name == "phase7-transcendental":
        command = ["python3", "tools/phase7_transcendental.py", "--shards"]
        timeout = 3600
    elif name == "fcntl-production":
        command = ["make", "--no-print-directory", "gate", "FUNC=fcntl"]
        filename, scope = "fcntl.production.json", "production-runtime-manifest-function"
    elif name == "phase11-copy-benchmark":
        scope = "phase11-native-hot-disjoint-memcpy-benchmark"
    elif name == "phase11-vdso-benchmark":
        scope = "phase11-native-warm-vdso-time-benchmark"
    elif name == "scan-musl-authorship":
        filename, scope = "musl-authorship.json", "nightly-same-symbol-musl-authorship-scan"
    invoke(command, record, timeout=timeout, environment=environment)
    if name == "phase2":
        path, _ = phase2_report(started)
    elif name in ("production-scalars", "production-linux-files", "production-linux-io"):
        path, _ = supplemental_batch(started, name)
    elif name in MANIFEST_PRODUCTION_GROUPS:
        record["children"] = manifest_production_reports(started, name)
        if name == "production-stat":
            record["dependencies"] = stat_tier_binding(started)["functions"]
        return
    elif name == "verify-math-wrappers":
        path, _ = math_wrapper_report(started)
    elif name in SCOPED_WRAPPER_BATCHES:
        path, data = scoped_wrapper_report(started, name)
        record.update(children=data["functions"], production_verified=False, dependency_closure={"outcome": "pending"})
    else:
        path, data = fresh_report(ROOT, filename, scope, started)
        if name == "fcntl-production" and data.get("production_verified") is not True:
            raise GateError("fcntl production evidence is incomplete")
        if name == "phase11-allocator-benchmark":
            check_allocator_benchmark(data)
        if name == "phase11-seccomp":
            record["installed_filter_cases"] = check_seccomp(data)
        if name in ("phase10-gnulib", "phase10-native-ltp"):
            check_upstream_subset(name.removeprefix("phase10-"), data)
        if name == "phase10-addrconfig":
            check_addrconfig(data)
        if name == "phase11-vdso-benchmark":
            if data["inputs"] != vdso_inputs():
                raise GateError("vDSO benchmark evidence omits the exact source snapshot")
            check_vdso_benchmark(data)
        if name == "scan-musl-authorship":
            if data["inputs"] != authorship_inputs():
                raise GateError("musl authorship evidence omits source-bound scan inputs")
            review_path, review = report_file(ROOT, "musl-authorship-review.json", started)
            symbols = load_project().functions.keys()
            expected = {source.stem for source in map(Path, data["inputs"])
                        if source.is_relative_to(RUNTIME_SRC) and source.suffix == ".asm"
                        and source.stem in symbols}
            findings = check_authorship(data, review, sha256_file(path), expected)
            record.update(review_evidence=review_path.relative_to(ROOT).as_posix(),
                          review_evidence_sha256=sha256_file(review_path),
                          review_signals=findings)
    record.update(evidence=path.relative_to(ROOT).as_posix(), evidence_sha256=sha256_file(path))


def reproducible(record):
    log = record["commands"] = []
    with tempfile.TemporaryDirectory(prefix="release-build-", dir=BUILD) as work:
        workspace = Path(work).resolve().relative_to(ROOT)
        builds = []
        for index in (1, 2):
            directory = workspace / f"run-{index}"
            _, _, _, hashes = build_runtime(directory, log)
            checked(log, ["make", "--no-print-directory", "runtime-pie", "apps",
                          f"RUNTIME_BUILD={directory}"], timeout=300)
            pie = directory / "crt1-pie.o"
            checked(log, ["tools/elf-audit", "--assembly-object", pie])
            hashes[pie.name] = sha256_file(pie)
            apps = sorted((directory / "apps").iterdir())
            if not apps:
                raise GateError("release build did not produce its applications")
            for app in apps:
                checked(log, ["tools/elf-audit", app])
                hashes[app.relative_to(directory).as_posix()] = sha256_file(app)
            builds.append(hashes)
        if builds[0] != builds[1]:
            raise GateError("isolated release build artifacts differ")
        record["artifacts"] = builds[0]


def coverage_and_deviations():
    project = load_project()
    states = runpy.run_path(str(ROOT / "tools/queue"))["states"](project)
    expected = {item.name for item in project.inventory if has_runtime_entry(item) and item.availability == "required"}
    verified = {name for name, state in states.items() if state.status == "verified"}
    coverage = {}
    for name in sorted(verified):
        path = regular_file(ROOT, f"build/evidence/{name}.production.json", "production coverage")
        data = evidence_json(path)
        selected = {}
        for key in ("branch_coverage", "production_mutation"):
            item = data["checks"].get(key, {})
            selected[key] = {field: value for field, value in item.items()
                             if field == "outcome" or type(value) is int}
        coverage[name] = {"evidence_sha256": sha256_file(path), **selected}
    missing = sorted(expected - verified)
    return {"outcome": "pending" if missing else "pass", "required": len(expected), "verified": len(verified & expected),
            "missing": missing, "coverage": coverage, "deviations": project.deviations}


def repository(record, tier, tag):
    log = record["commands"] = []
    commit = checked(log, ["git", "rev-parse", "HEAD"]).strip()
    tree = checked(log, ["git", "rev-parse", "HEAD^{tree}"]).strip()
    record.update(commit=commit, tree=tree)
    if tier == "release":
        if tag is None:
            record.update(outcome="pending", reason="Release verification requires the exact version tag.")
            return commit
        else:
            reference = checked(log, ["git", "rev-parse", "--verify", f"refs/tags/{tag}^{{commit}}"]).strip()
            if reference != commit:
                raise GateError(f"release tag {tag} does not name the checked-out commit")
            if checked(log, ["git", "status", "--porcelain"]):
                raise GateError("release verification requires a clean tagged checkout")
            record["tag"] = tag
    record["outcome"] = "pass"
    return commit


def platform_observation():
    name = os.uname()
    status = Path("/proc/self/status")
    seccomp = {}
    if status.is_file():
        for line in status.read_text().splitlines():
            field, _, value = line.partition(":")
            if field in {"Seccomp", "Seccomp_filters"}:
                seccomp[field] = value.strip()
    return {"system": name.sysname, "kernel_release": name.release, "machine": name.machine,
            "seccomp": seccomp, "qemu_system": shutil.which("qemu-system-x86_64")}



def math_campaigns(record, campaign_root):
    started = time_ns()
    command = ["python3", "tests/phase7/campaign/tier_audit.py", campaign_root]
    failed = None
    try:
        invoke(command, record, timeout=3600)
    except GateError as error:
        failed = error
    path, data = report_file(ROOT, "phase7-campaigns.json", started)
    if data.get("scope") != "phase7-binary32-campaigns":
        raise GateError("math ledger audit has the wrong scope")
    record.update(evidence=path.relative_to(ROOT).as_posix(), evidence_sha256=sha256_file(path))
    if failed:
        raise failed
    if data.get("outcome") not in ("pending", "pass"):
        raise GateError("math ledger audit did not establish its scope")
    record["unary"] = data["unary"]
    record["binary"] = data["binary"]
    return data["outcome"]


def execute(tier, only, tag, old_started, old_status, campaign_root):
    scope = f"verification-{tier}"
    choices = PHASES + EXTRA + (("reproducible",) if tier == "release" else ())
    selected = tuple(only) if only else choices
    gates = {name: {"outcome": "pending", "reason": "Omitted by the selected verification scope."}
             for name in choices if name not in selected}
    checks = {
        "gates": gates,
    }
    evidence = {"schema_version": 1, "scope": scope, "tier": tier, "outcome": "fail",
                "qualified": False, "checks": checks, "selected": selected, "full_scope": not only}
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64")
        evidence["platform"] = platform_observation()
        commit = repository(checks.setdefault("repository", {"outcome": "fail"}), tier, tag)
        evidence["inputs"] = verify_setup(checks, False, snapshot=phase1_inputs)
        for name in selected:
            print(f"RUN {scope} {name}", flush=True)
            item = gates[name] = {"outcome": "fail"}
            try:
                if name == "extension-control":
                    extension_control(commit, item)
                elif name == "extension-packages":
                    item["outcome"] = extension_packages(item, evidence["inputs"])
                    print(f"{item['outcome'].upper()} {scope} {name}", flush=True)
                    continue
                elif name == "math-campaigns":
                    item["outcome"] = math_campaigns(item, campaign_root)
                    print(f"{item['outcome'].upper()} {scope} {name}", flush=True)
                    continue
                elif name == "reproducible":
                    reproducible(item)
                elif name == "phase11-old-kernel":
                    if old_started is None:
                        item.update(outcome="pending", reason="Use the host wrapper to run the pinned old-kernel container.")
                        continue
                    old_kernel(old_started, old_status, item)
                else:
                    gate(name, item)
                item["outcome"] = "pass"
                print(f"PASS {scope} {name}", flush=True)
            except (GateError, OSError, SpecError, ValueError) as error:
                item["error"] = str(error)
                print(f"FAIL {scope} {name}: {error}", file=sys.stderr, flush=True)
        checks["production_inventory"] = coverage_and_deviations()
        if evidence["inputs"] != phase1_inputs() or checked([], ["git", "rev-parse", "HEAD"]).strip() != commit:
            raise GateError("verification inputs changed during the tier run")
        records = [checks["repository"], checks["production_inventory"], *gates.values()]
        outcomes = {record["outcome"] for record in records}
        evidence["outcome"] = "fail" if "fail" in outcomes else "pending" if "pending" in outcomes else "pass"
        evidence["qualified"] = evidence["outcome"] == "pass"
    except (GateError, OSError, SpecError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"{scope}: {error}", file=sys.stderr)
    report = write_evidence(scope, evidence)
    print(f"{evidence['outcome'].upper()} {scope} evidence {report}", flush=True)
    return 0 if evidence["qualified"] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tier", choices=("nightly", "release"))
    parser.add_argument("--only", choices=PHASES + EXTRA + ("reproducible",), action="append", default=[])
    parser.add_argument("--tag")
    parser.add_argument("--campaign-root", default=DEFAULT_CAMPAIGN_ROOT,
                        help="checkout-relative path to current campaign ledgers under build/")
    parser.add_argument("--old-kernel-started", type=int)
    parser.add_argument("--old-kernel-status", type=int)
    args = parser.parse_args()
    if len(set(args.only)) != len(args.only):
        parser.error("select each check once")
    if args.tier == "nightly" and (args.tag is not None or "reproducible" in args.only):
        parser.error("tag and isolated release builds require the release tier")
    if args.tag is not None and re.fullmatch(r"v[0-9][A-Za-z0-9._+-]*", args.tag) is None:
        parser.error("release tags must begin with v and a digit")
    if args.tier == "release" and args.tag is None and not args.only:
        parser.error("the release tier requires --tag")
    if (args.old_kernel_started is None) != (args.old_kernel_status is None):
        parser.error("old-kernel status and start time must be supplied together")
    if args.old_kernel_started is not None and not (
            0 < args.old_kernel_started <= time_ns() and 0 <= args.old_kernel_status <= 255):
        parser.error("invalid old-kernel start time or status")
    return execute(args.tier, args.only, args.tag, args.old_kernel_started,
                   args.old_kernel_status, args.campaign_root)


if __name__ == "__main__":
    raise SystemExit(main())

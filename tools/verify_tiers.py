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

from gate import BUILD, EVIDENCE, GateError, checked, identify_tools, verify_setup, write_evidence
from musl_authorship import ARCHIVE_SHA256 as MUSL_ARCHIVE_SHA, POLICY as AUTHORSHIP_POLICY
from musl_authorship import inputs as authorship_inputs
from phase1 import RUNTIME_SRC, build_runtime, phase1_inputs
from phase2 import phase2_functions
from spec import ROOT, SpecError, has_runtime_entry, load_project, regular_file, relative_path, sha256_file, snapshot_inputs

PHASES = (
    "phase0", "phase1", "phase2", "phase3", "phase4", "phase5",
    "phase6-files", "phase6-fcntl", "phase6-compat", "phase6-busybox", "phase6-lua", "phase6-zlib",
    "phase6-sqlite", "phase6-process", "phase6-signal", "phase6-jump", "phase6-time", "phase6-calendar",
    "phase6-zone", "phase6-luafiles", "phase6-spawn", "phase6-shell", "phase6-path", "phase6-strftime",
    "phase7-exact", "phase7-transcendental", "phase7-complex",
    "phase8-lifecycle", "phase8-sync", "phase8-c11", "phase8-openposix", "phase8-detectors",
    "phase8-compiler-atomics",
    "phase9-multibyte", "phase9-bulk", "phase9-worker", "phase9-worker-sync", "phase9-wide",
    "phase9-libc-test", "phase9-stdio", "phase9-narrow-wide", "phase9-wctype",
    "phase10-endpoints", "phase10-inet", "phase10-netdb", "phase10-dns", "phase10-http",
    "phase10-terminal", "phase10-libc-test", "phase10-glob", "phase10-regex", "phase11-vdso",
    "phase11-static-pie", "phase11-allocator", "phase11-copy-benchmark", "phase11-allocator-benchmark",
    "phase11-seccomp", "phase11-old-kernel", "scan-musl-authorship",
)
EXTRA = ("fcntl-production", "extension-control")
FUZZ_SECONDS = 300
GAPS = {
    "remaining_old_current_kernel_matrix": "The boot gate covers its named runtime checks. The remaining old/current kernel matrix needs its own evidence.",
    "remaining_restricted_seccomp_matrix": "Installed filters cover four named failure paths. Remaining restrictive-profile scopes need their own observations.",
    "remaining_binary32_domains": "The full remaining binary32 math campaigns need artifact-bound completion and audit.",
    "ltp_gnulib_conformance": "The roadmap's independent LTP and gnulib subsets need pinned executable gates.",
    "remaining_musl_performance": "Copy and allocator benchmarks cover their predeclared workloads. Remaining musl performance criteria need measured gates.",
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


def phase2_report(started):
    path, data = report_file(ROOT, "phase2.json", started)
    functions = phase2_functions()
    if (data.get("outcome") != "pass" or data.get("scope") != "phase2-batch"
            or data.get("full_scope") is not True or data.get("total") != len(functions)
            or data.get("passed") != len(functions) or set(data.get("functions", {})) != set(functions)):
        raise GateError("phase2.json: incomplete Phase 2 production batch")

    def check_result(name, scope, item):
        report, record = fresh_report(ROOT, f"{name}.production.json", scope, started)
        if (type(item) is not dict or item.get("outcome") != "pass" or record.get("function") != name
                or item.get("evidence_sha256") != sha256_file(report)):
            raise GateError(f"phase2.json: invalid child evidence for {name}")
        return record

    for name, item in data["functions"].items():
        record = check_result(name, "production-function", item)
        engine = record.get("checks", {}).get("engine_fuzz", {})
        if (record.get("production_verified") is not True or engine.get("outcome") != "pass"
                or engine.get("requested_seconds") != FUZZ_SECONDS
                or type(engine.get("elapsed_seconds")) is not int or engine["elapsed_seconds"] < FUZZ_SECONDS
                or type(engine.get("runs")) is not int or engine["runs"] < 1):
            raise GateError(f"phase2.json: missing timed libFuzzer evidence for {name}")
    for field, name, scope in (
        ("shared_integer_scanner", "__al_strtox", "production-private-dependency"),
        ("runtime_tls_accessor", "__errno_location", "production-runtime-function"),
        ("bulk_memcpy", "__al_memcpy_bulk", "production-private-dependency"),
    ):
        check_result(name, scope, data.get(field))
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


SECCOMP_OUTPUT = {
    "append-enosys": "PASS seccomp pwritev2 ENOSYS leaves append file unchanged\n",
    "remap-enosys": "PASS seccomp remap ENOSYS preserves and moves allocation\n",
    "remap-eperm": "PASS seccomp remap EPERM preserves and moves allocation\n",
    "vdso-eperm": "PASS seccomp vDSO EPERM uses raw clock and publishes EACCES\n",
}
OLD_KERNEL = "4.19.0-27-amd64"
OLD_KERNEL_SHA = "71947e2c7102ceb224b04b910c5761bc9f2a7986c2c8d868b5553dc8fef57747"


def check_seccomp(data):
    observations = data.get("observations")
    if (data.get("kernel_release") != os.uname().release or type(observations) is not dict
            or set(observations) != SECCOMP_OUTPUT.keys()
            or "tests/phase11/platform/seccomp.c" not in data.get("inputs", {})):
        raise GateError("seccomp evidence lacks the exact installed-filter scope")
    for case, expected in SECCOMP_OUTPUT.items():
        row = observations[case]
        if (type(row) is not dict or row.get("returncode") != 0 or row.get("stderr") != ""
                or row.get("stdout") != expected or type(row.get("command")) is not list
                or row["command"][-1:] != [case]):
            raise GateError(f"seccomp filter observation failed for {case}")


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


def old_kernel(started, status, record):
    if status != 0:
        raise GateError(f"old-kernel container exited {status}")
    path, data = fresh_report(ROOT, "phase11-old-kernel.json", "phase11-old-kernel", started)
    check_old_kernel(data)
    record.update(evidence=path.relative_to(ROOT).as_posix(), evidence_sha256=sha256_file(path))


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
    elif name == "scan-musl-authorship":
        filename, scope = "musl-authorship.json", "nightly-same-symbol-musl-authorship-scan"
    invoke(command, record, timeout=timeout, environment=environment)
    if name == "phase2":
        path, _ = phase2_report(started)
    else:
        path, data = fresh_report(ROOT, filename, scope, started)
        if name == "fcntl-production" and data.get("production_verified") is not True:
            raise GateError("fcntl production evidence is incomplete")
        if name == "phase11-allocator-benchmark":
            check_allocator_benchmark(data)
        if name == "phase11-seccomp":
            check_seccomp(data)
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


def execute(tier, only, tag, old_started, old_status):
    scope = f"verification-{tier}"
    choices = PHASES + EXTRA + (("reproducible",) if tier == "release" else ())
    selected = tuple(only) if only else choices
    gates = {name: {"outcome": "pending", "reason": "Omitted by the selected verification scope."}
             for name in choices if name not in selected}
    checks = {
        "gates": gates,
        "required_matrix_gaps": {name: {"outcome": "pending", "reason": reason}
                                 for name, reason in GAPS.items()},
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
        records = [checks["repository"], checks["production_inventory"], *gates.values(),
                   *checks["required_matrix_gaps"].values()]
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
    return execute(args.tier, args.only, args.tag, args.old_kernel_started, args.old_kernel_status)


if __name__ == "__main__":
    raise SystemExit(main())

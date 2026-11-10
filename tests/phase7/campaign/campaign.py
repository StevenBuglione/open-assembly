"""Prepare and resume a source-bound binary32 transcendental campaign."""

import argparse
from concurrent.futures import FIRST_COMPLETED, ThreadPoolExecutor, wait
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
from time import monotonic

import gmpy2

DOMAIN = 1 << 32
ARTIFACTS = ("crt1.o", "libopenasm.a", "trans-f32.o", "trans-f32")
VERIFY = Path("tests/phase7/transcendental/verify.py")
OPERATIONS = Path("tests/phase7/transcendental/operations.def")
NATIVE = Path("tests/phase7/campaign")
NATIVE_ARTIFACTS = ("native-unary", "mpfr.h", "gmp.h")
NATIVE_BACKEND = "native-mpfr-unary"
NATIVE_OPERATIONS = {"exp2", "log2", "exp", "log", "sin", "cos", "tan"}


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def json_bytes(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def identity(value):
    return hashlib.sha256(json_bytes(value)).hexdigest()


def atomic_json(path, data):
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=".checkpoint-", delete=False) as handle:
        temp = Path(handle.name)
        handle.write(json_bytes(data) + b"\n")
        handle.flush()
        os.fsync(handle.fileno())
    try:
        temp.replace(path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        temp.unlink(missing_ok=True)


def read_json(path):
    return json.loads(path.read_text())


def source_inputs(gate, root):
    if (gate.get("scope") != "phase7-transcendental" or gate.get("outcome") != "pass"
            or gate["checks"]["build"]["outcome"] != "pass" or not gate["inputs"]):
        raise ValueError("campaign requires passing source-bound transcendental evidence")
    for name, expected in gate["inputs"].items():
        path = (root / name).resolve(strict=True)
        path.relative_to(root)
        if digest(path) != expected:
            raise ValueError(f"source input changed: {name}")
    if not any(name.startswith("src/") for name in gate["inputs"]):
        raise ValueError("source evidence contains no candidate sources")
    build = gate["checks"]["build"]
    return {name: (build["runtime_artifacts"] if name in ARTIFACTS[:2] else
                   build["candidate_artifacts"])[name] for name in ARTIFACTS}


def oracle_identity(root, backend):
    library = Path(os.environ["OPEN_ASSEMBLY_MPFR"]).resolve(strict=True)
    identity = {"backend": backend, "script_sha256": digest(Path(__file__).resolve()),
            "verify_sha256": digest(root / VERIFY), "python_sha256": digest(Path(sys.executable).resolve()),
            "mpfr_sha256": digest(library), "mpfr": gmpy2.mpfr_version(), "gmpy2": gmpy2.version()}
    if backend == NATIVE_BACKEND:
        identity.update({name: digest(root / NATIVE / name)
                         for name in ("native_unary.c", "native_oracle.py")})
    elif backend != "python":
        raise ValueError(f"unknown oracle backend: {backend}")
    return identity


def build_native(folder, headers, root):
    for name in NATIVE_ARTIFACTS[1:]:
        shutil.copyfile(headers / name, folder / name)
    library = Path(os.environ["OPEN_ASSEMBLY_MPFR"]).resolve(strict=True)
    command = ["gcc", "-O2", "-Wall", "-Wextra", "-Werror", f"-I{folder}",
               root / NATIVE / "native_unary.c", library, f"-Wl,-rpath,{library.parent}"]
    helper = folder / NATIVE_ARTIFACTS[0]
    with tempfile.TemporaryDirectory(dir=folder, prefix=".native-build-") as second:
        replay = Path(second) / helper.name
        for output in (helper, replay):
            subprocess.run([*command, "-o", output], cwd=root, check=True)
        if digest(helper) != digest(replay):
            raise ValueError("isolated native oracle builds differ")
    return {name: digest(folder / name) for name in NATIVE_ARTIFACTS}



def partition(first, count, width):
    for start in range(first, first + count, width):
        yield start, min(width, first + count - start)


def checkpoint_name(start, count):
    return f"{start:08x}-{count:08x}.json"


def prepare(args, root):
    gate = read_json(args.gate)
    hashes = source_inputs(gate, root)
    declared = {match[2]: bool(match[1]) for line in (root / OPERATIONS).read_text().splitlines()
                if (match := re.fullmatch(r"OP(2?)\(([a-z0-9]+)\)", line))}
    if args.operation not in declared or declared[args.operation] != (args.second is not None):
        raise ValueError("operation and fixed second operand do not match the fixture inventory")
    if args.second is not None and not 0 <= args.second < DOMAIN:
        raise ValueError("second operand must be a binary32 representation")
    if (not 0 <= args.start < DOMAIN or not 0 < args.count <= DOMAIN - args.start
            or not 1 <= args.width <= args.count):
        raise ValueError("invalid interval or shard width")
    for name, expected in hashes.items():
        if digest(args.artifacts / name) != expected:
            raise ValueError(f"artifact differs from source-bound gate: {name}")
    backend = "python"
    if args.native_headers is not None:
        if args.operation not in NATIVE_OPERATIONS or args.second is not None:
            raise ValueError("native MPFR oracle supports only these unary operations: "
                             + ", ".join(sorted(NATIVE_OPERATIONS)))
        backend = NATIVE_BACKEND
    folder = args.campaign.resolve()
    folder.mkdir(parents=True, exist_ok=False)
    (folder / "checkpoints").mkdir()
    (folder / "attempts").mkdir()
    (folder / "artifacts").mkdir()
    for name in ARTIFACTS:
        shutil.copy2(args.artifacts / name, folder / "artifacts" / name)
    shutil.copy2(args.gate, folder / "source-gate.json")
    extras = build_native(folder / "artifacts", args.native_headers, root) if backend == NATIVE_BACKEND else {}
    settings = {
        "schema": 1, "operation": args.operation, "mode_index": args.mode,
        "start": args.start, "count": args.count, "width": args.width,
        "second_bits": args.second, "artifacts": hashes, "oracle_artifacts": extras,
        "source_gate_sha256": digest(folder / "source-gate.json"),
        "source_snapshot_sha256": identity(gate["inputs"]), "oracle": oracle_identity(root, backend),
    }
    atomic_json(folder / "campaign.json", {"id": identity(settings), "settings": settings})
    verify_campaign(folder, root)
    print(f"Prepared {folder}: {settings['operation']} mode {settings['mode_index']}", flush=True)
    return 0


def verify_campaign(folder, root):
    record = read_json(folder / "campaign.json")
    settings = record["settings"]
    if identity(settings) != record["id"] or settings["schema"] != 1:
        raise ValueError("campaign identity does not match its settings")
    gate_path = folder / "source-gate.json"
    if digest(gate_path) != settings["source_gate_sha256"]:
        raise ValueError("campaign source gate changed")
    gate = read_json(gate_path)
    if (identity(gate["inputs"]) != settings["source_snapshot_sha256"] or
            source_inputs(gate, root) != settings["artifacts"] or
            oracle_identity(root, settings["oracle"]["backend"]) != settings["oracle"]):
        raise ValueError("campaign source or oracle identity changed")
    expected_extras = set(NATIVE_ARTIFACTS) if settings["oracle"]["backend"] == NATIVE_BACKEND else set()
    if set(settings["oracle_artifacts"]) != expected_extras:
        raise ValueError("campaign oracle artifact inventory changed")
    for name, expected in (settings["artifacts"] | settings["oracle_artifacts"]).items():
        if digest(folder / "artifacts" / name) != expected:
            raise ValueError(f"campaign artifact changed: {name}")
    return record


def valid_report(report, folder, settings, start, count):
    artifacts = settings["artifacts"] | settings["oracle_artifacts"]
    artifact_paths = {str(folder / "artifacts" / name): expected for name, expected in artifacts.items()}
    backend = settings["oracle"]["backend"]
    if backend == NATIVE_BACKEND and (report.get("oracle_backend") != backend or
                                      report.get("oracle_identity") != settings["oracle"]):
        return False
    artifact_paths[str(folder / "source-gate.json")] = settings["source_gate_sha256"]
    native = report["results"]["native"]
    ulp = native.get("max_finite_ulp")
    return (
        report.get("schema") == 1 and report.get("scope") == "consecutive binary32 shard"
        and report.get("backend") == "native" and report.get("passed") is True
        and report.get("inputs_frozen") is True and report["operation"] == settings["operation"]
        and report["mode_index"] == settings["mode_index"] and report["second_bits"] == settings["second_bits"]
        and report["start"] == start and report["count"] == count
        and native["passed"] is True and native["records"] == count
        and (ulp is None or type(ulp) is int and 0 <= ulp <= 1)
        and all(report["sha256"].get(name) == value for name, value in artifact_paths.items())
    )


def checkpoints(folder, campaign, intervals):
    expected = {checkpoint_name(*interval): interval for interval in intervals}
    done = {}
    for path in (folder / "checkpoints").glob("*.json"):
        if path.name not in expected:
            raise ValueError(f"unexpected or overlapping checkpoint: {path.name}")
        start, count = expected[path.name]
        item = read_json(path)
        report = item["report"]
        if (item["campaign_id"] != campaign["id"] or item["report_sha256"] != identity(report)
                or not valid_report(report, folder, campaign["settings"], start, count)):
            raise ValueError(f"invalid checkpoint: {path.name}")
        done[start] = report
    return done


def run_python_shard(folder, root, campaign, start, count):
    settings = campaign["settings"]
    with tempfile.TemporaryDirectory(dir=folder / "attempts", prefix=f"shard-{start:08x}-") as temporary:
        target = Path(temporary) / "result.json"
        command = [sys.executable, root / VERIFY, folder / "artifacts", target,
                   "--shard", settings["operation"], start, count, settings["mode_index"]]
        if settings["second_bits"] is not None:
            command += ["--second", settings["second_bits"]]
        for path in [*(folder / "artifacts" / name for name in ARTIFACTS), folder / "source-gate.json"]:
            command += ["--input", path]
        before = monotonic()
        run = subprocess.run(list(map(str, command)), cwd=root, capture_output=True, text=True)
        elapsed = monotonic() - before
        report = read_json(target) if target.exists() else None
        if run.returncode or report is None or not valid_report(report, folder, settings, start, count):
            name = f"failure-{start:08x}-{count:08x}.json"
            atomic_json(folder / "attempts" / name, {
                "status": run.returncode, "stdout": run.stdout, "stderr": run.stderr, "report": report,
                "semantic_failure": bool(report and report["results"]["native"].get("failures_by_reason")),
            })
            return False, elapsed
        checkpoint = {"campaign_id": campaign["id"], "report_sha256": identity(report), "report": report,
                      "worker_elapsed_seconds": elapsed}
        atomic_json(folder / "checkpoints" / checkpoint_name(start, count), checkpoint)
        return True, elapsed


def run_native_shard(folder, root, campaign, start, count):
    from native_oracle import OracleMismatch, compare_native, evaluate

    settings = campaign["settings"]
    artifacts = folder / "artifacts"
    helper = artifacts / NATIVE_ARTIFACTS[0]
    candidate = artifacts / "trans-f32"
    tracked = [candidate, helper]
    before = monotonic()
    try:
        hashes = {str(path): digest(path) for path in tracked}
        with tempfile.TemporaryDirectory(dir=folder / "attempts", prefix=f"shard-{start:08x}-") as name:
            request, expected, actual = evaluate(helper, candidate, Path(name), settings["operation"],
                                                 start, count, settings["mode_index"])
        maximum = compare_native(actual, expected, settings["operation"], start, count)
        if hashes != {str(path): digest(path) for path in tracked}:
            raise ValueError("candidate or native oracle changed during shard")
        hashes.update({str(artifacts / name): expected_hash for name, expected_hash in
                       (settings["artifacts"] | settings["oracle_artifacts"]).items()
                       if artifacts / name not in tracked})
        hashes[str(folder / "source-gate.json")] = settings["source_gate_sha256"]
        report = {
            "schema": 1, "scope": "consecutive binary32 shard", "backend": "native",
            "passed": True, "inputs_frozen": True, "operation": settings["operation"],
            "mode_index": settings["mode_index"], "second_bits": None, "start": start,
            "count": count, "oracle_backend": NATIVE_BACKEND, "oracle_identity": settings["oracle"],
            "sha256": hashes,
            "results": {"native": {"passed": True, "records": count, "max_finite_ulp": maximum,
                                   "request_sha256": hashlib.sha256(request).hexdigest(),
                                   "response_sha256": hashlib.sha256(actual).hexdigest(),
                                   "expected_sha256": hashlib.sha256(expected).hexdigest()}},
        }
        if not valid_report(report, folder, settings, start, count):
            raise ValueError("native shard did not bind campaign artifacts")
    except (OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        atomic_json(folder / "attempts" / f"failure-{start:08x}-{count:08x}.json",
                    {"error": str(error), "semantic_failure": isinstance(error, OracleMismatch)})
        return False, monotonic() - before
    elapsed = monotonic() - before
    atomic_json(folder / "checkpoints" / checkpoint_name(start, count),
                {"campaign_id": campaign["id"], "report_sha256": identity(report), "report": report,
                 "worker_elapsed_seconds": elapsed})
    return True, elapsed


def summary(folder, campaign, intervals, done, attempted, elapsed, failed):
    settings = campaign["settings"]
    first = settings["start"]
    prefix = first
    covered = 0
    maximum = None
    for start, count in intervals:
        if start not in done:
            continue
        if start == prefix:
            prefix += count
        covered += count
        ulp = done[start]["results"]["native"]["max_finite_ulp"]
        if ulp is not None:
            maximum = ulp if maximum is None else max(maximum, ulp)
    interval_complete = prefix == first + settings["count"] and covered == settings["count"]
    full_axis = interval_complete and first == 0 and settings["count"] == DOMAIN
    return {"schema": 1, "campaign_id": campaign["id"], "operation": settings["operation"],
            "mode_index": settings["mode_index"], "fixed_second_operand_bits": settings["second_bits"],
            "oracle_backend": settings["oracle"]["backend"],
            "first_pattern": first, "requested_patterns": settings["count"],
            "covered_patterns": covered, "contiguous_prefix_end": prefix,
            "passed_shards": len(done), "total_shards": len(intervals),
            "new_shards_attempted": attempted, "new_worker_seconds": elapsed,
            "failed_shards_this_run": failed, "max_finite_ulp": maximum,
            "requested_interval_complete": interval_complete,
            "complete_binary32_axis": full_axis,
            "complete_domain": full_axis and settings["second_bits"] is None,
            "scope": "unary binary32 representations" if settings["second_bits"] is None else
                     "one binary32 operand axis with fixed second operand",
            "source_gate_sha256": settings["source_gate_sha256"],
            "archive_sha256": settings["artifacts"]["libopenasm.a"],
            "candidate_sha256": settings["artifacts"]["trans-f32"]}


def worker_pass(folder, root, campaign, selected, workers):
    iterator = iter(selected)
    run_shard = (run_native_shard if campaign["settings"]["oracle"]["backend"] == NATIVE_BACKEND
                 else run_python_shard)
    attempted, failed, elapsed = 0, 0, 0.0
    with ThreadPoolExecutor(max_workers=workers) as pool:
        active = {}

        def submit():
            interval = next(iterator, None)
            if interval is not None:
                future = pool.submit(run_shard, folder, root, campaign, *interval)
                active[future] = interval

        for _ in range(workers):
            submit()
        while active:
            finished, _ = wait(active, return_when=FIRST_COMPLETED)
            for future in finished:
                start, count = active.pop(future)
                passed, seconds = future.result()
                attempted += 1
                elapsed += seconds
                failed += not passed
                print(f"{start:#010x}+{count} {'PASS' if passed else 'FAIL'} {seconds:.3f}s", flush=True)
            if not failed:
                for _ in finished:
                    submit()
    return attempted, elapsed, failed


def execute(args, root):
    folder = args.campaign.resolve(strict=True)
    with (folder / ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        campaign = verify_campaign(folder, root)
        settings = campaign["settings"]
        intervals = list(partition(settings["start"], settings["count"], settings["width"]))
        done = checkpoints(folder, campaign, intervals)
        errors = sorted((folder / "attempts").glob("failure-*.json"))
        semantic = any(read_json(path)["semantic_failure"] for path in errors)
        if semantic and args.limit != 0:
            raise ValueError("an earlier shard reported a semantic failure; inspect attempts")
        remaining = [interval for interval in intervals if interval[0] not in done]
        selected = remaining[:args.limit] if args.limit is not None else remaining
        attempted, elapsed, failed = worker_pass(folder, root, campaign, selected, args.workers)
        if verify_campaign(folder, root) != campaign:
            raise ValueError("campaign changed during verification")
        done = checkpoints(folder, campaign, intervals)
        result = summary(folder, campaign, intervals, done, attempted, elapsed, failed)
        atomic_json(folder / "summary.json", result)
        print(f"{result['covered_patterns']}/{result['requested_patterns']} patterns; "
              f"{result['passed_shards']}/{result['total_shards']} shards", flush=True)
        return int(bool(failed or semantic))


def parse_int(text):
    return int(text, 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    setup = commands.add_parser("prepare", help="bind a new campaign to a passing source gate")
    setup.add_argument("campaign", type=Path)
    setup.add_argument("gate", type=Path)
    setup.add_argument("artifacts", type=Path)
    setup.add_argument("operation")
    setup.add_argument("--mode", type=int, choices=range(4), default=0)
    setup.add_argument("--start", type=parse_int, default=0)
    setup.add_argument("--count", type=parse_int, default=DOMAIN)
    setup.add_argument("--width", type=parse_int, default=65536)
    setup.add_argument("--second", type=parse_int)
    setup.add_argument("--native-headers", type=Path,
                       help="build the native binary32 oracle with pinned MPFR and GMP headers")

    run = commands.add_parser("run", help="validate completed shards and continue")
    run.add_argument("campaign", type=Path)
    run.add_argument("--workers", type=int, default=1)
    run.add_argument("--limit", type=int, help="limit new shards; zero only validates the journal")
    args = parser.parse_args()
    if args.command == "run" and (not 1 <= args.workers <= 8 or
                                  args.limit is not None and args.limit < 0):
        parser.error("workers must be 1..8 and limit must be nonnegative")
    try:
        root = Path.cwd().resolve()
        return prepare(args, root) if args.command == "prepare" else execute(args, root)
    except (KeyError, OSError, TypeError, ValueError, subprocess.SubprocessError) as error:
        print(f"campaign: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

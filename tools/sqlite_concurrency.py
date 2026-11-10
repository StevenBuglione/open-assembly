"""Qualify unchanged SQLite walthread1 on concurrent disk transactions."""

from contextlib import closing
import _sqlite3
import os
from pathlib import Path
import re
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import time
import zipfile

from gate import BUILD, GateError, checked, identify_tools, source_policy, verify_setup, write_evidence
from phase1 import build_runtime
from spec import ROOT, SpecError, sha256_file, snapshot_inputs
from sqlite import (ARCHIVES, SOURCE_ID, VERSION, compile_objects, extract_sources,
                    input_snapshot, pinned_archives, verify_link)


SCOPE = "phase6-sqlite-concurrency"
WORKLOAD = "threadtest3"
TEST = "walthread1"
HOST_REPEATS = 2
TIMEOUT = 120
DOC = Path("docs/cookbook/sqlite-concurrency.md")


def inputs():
    hashes = input_snapshot()
    hashes.update(snapshot_inputs(ROOT, [Path(__file__).relative_to(ROOT), DOC]))
    return dict(sorted(hashes.items()))


def worker_results(stdout):
    lines = stdout.splitlines()
    if (len(lines) != 13 or lines[0] != f"Running {TEST} for 20 seconds..."
            or lines[-1] != "0 errors out of 1 tests"):
        raise GateError(f"{TEST} did not finish the selected upstream workload")
    workers = {}
    for line in lines[1:-1]:
        result = re.fullmatch(r"Thread ([0-9]+) says: ([1-9][0-9]*) (iterations|checkpoints)", line)
        if result is None:
            raise GateError(f"{TEST} worker did not report positive progress")
        worker, count, operation = result.groups()
        key = int(worker)
        if key in workers or operation != ("checkpoints" if key == 11 else "iterations"):
            raise GateError(f"{TEST} reported duplicate workers or the wrong operation")
        workers[key] = int(count)
    if set(workers) != set(range(1, 12)):
        raise GateError(f"{TEST} requires ten distinct writers and one checkpoint worker")
    return workers


def verify_database(path, workers):
    if not path.is_file() or path.stat().st_size < 4096:
        raise GateError(f"{TEST} did not produce a disk-backed database")
    digest = sha256_file(path)
    with closing(sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)) as database:
        integrity = database.execute("PRAGMA integrity_check").fetchall()
        journal = database.execute("PRAGMA journal_mode").fetchone()
        rows = database.execute("SELECT count(*) FROM t1").fetchone()[0]
    expected_rows = 3 + 3 * sum(workers[index] for index in range(1, 11))
    if integrity != [("ok",)] or journal != ("wal",) or rows != expected_rows:
        raise GateError(f"{TEST} final disk state differs ({integrity!r}, {journal!r}, {rows}/{expected_rows} rows)")
    if sha256_file(path) != digest:
        raise GateError(f"{TEST} read-only verification changed the database")
    return {"integrity": "ok", "journal_mode": "wal", "rows": rows, "database_sha256": digest}


def run_workload(binary, prefix, directory, record):
    directory.mkdir()
    command = [*prefix, str(binary.resolve()), TEST]
    environment = {"LC_ALL": "C", "TZ": "UTC0", "PATH": os.environ["PATH"]}
    record.update(command=command, executable_sha256=sha256_file(binary), outcome="fail")
    start = time.monotonic()
    try:
        result = subprocess.run(command, cwd=directory, env=environment, stdin=subprocess.DEVNULL,
                                capture_output=True, timeout=TIMEOUT, text=True)
    except subprocess.TimeoutExpired as error:
        record.update(timeout_seconds=TIMEOUT, stdout=(error.stdout or b"").decode(errors="replace"),
                      stderr=(error.stderr or b"").decode(errors="replace"))
        raise GateError(f"{directory.name}: {TEST} exceeded {TIMEOUT} seconds") from error
    record.update(status=result.returncode, stdout=result.stdout, stderr=result.stderr,
                  elapsed_seconds=round(time.monotonic() - start, 6))
    if result.returncode or result.stderr:
        raise GateError(f"{directory.name}: {TEST} failed with status {result.returncode}")
    if record["elapsed_seconds"] < 19.75:
        raise GateError(f"{directory.name}: {TEST} ended before the upstream workload interval")
    workers = worker_results(result.stdout)
    record.update(workers=workers, database=verify_database(directory / "test.db", workers),
                  outcome="pass")
    print(f"PASS SQLite {VERSION} {TEST} {directory.name}", flush=True)


def checked_sources(archives, directory, compiler, candidate, record):
    hashes = record["sources"] = extract_sources(archives, directory)
    objects = compile_objects(directory, WORKLOAD, compiler, True, candidate, record["commands"])
    if any(sha256_file(directory / name) != digest for name, digest in hashes.items()):
        raise GateError("the SQLite build changed upstream sources")
    return objects


def hosted_controls(archives, directory, record):
    for host, compiler in (("glibc", "gcc"), ("musl", "musl-gcc")):
        item = record[host] = {"outcome": "fail", "commands": [], "runs": []}
        source = directory / f"source-{host}"
        engine, workload, multiplex = checked_sources(archives, source, compiler, False, item)
        binary = source / WORKLOAD
        checked(item["commands"], [compiler, "-static", "-no-pie", "-Wl,--gc-sections", "-pthread",
                                   "-o", binary, workload, engine, multiplex, "-lm"], timeout=120)
        checked(item["commands"], ["tools/elf-audit", "--hosted-test", binary])
        for index in range(1, HOST_REPEATS + 1):
            run = {}
            item["runs"].append(run)
            run_workload(binary, (), directory / f"{host}-{index}", run)
        item["outcome"] = "pass"


def candidate_controls(archives, directory, record):
    runtime_commands = record["runtime_commands"] = []
    runtimes = [build_runtime(directory / f"runtime-{index}", runtime_commands) for index in (1, 2)]
    if runtimes[0][3] != runtimes[1][3]:
        raise GateError("two isolated SQLite concurrency runtime builds differ")
    record["runtime_artifacts"] = runtimes[0][3]
    links = record["candidate_builds"] = []
    binaries = []
    for index, runtime in enumerate(runtimes, 1):
        item = {"outcome": "fail", "commands": []}
        links.append(item)
        source = directory / f"source-oa-{index}"
        objects = checked_sources(archives, source, "gcc", True, item)
        binaries.append(verify_link(objects, runtime, WORKLOAD, True, item))
    if any(links[0][key] != links[1][key] for key in ("objects", "executable_sha256")):
        raise GateError("two isolated SQLite concurrency builds differ")
    runners = {
        "native": (),
        "qemu": (shutil.which("qemu-x86_64"),),
        "memcheck": (shutil.which("valgrind"), "--quiet", "--error-exitcode=99"),
    }
    runs = record["runs"] = {}
    for name, prefix in runners.items():
        runs[name] = {}
        run_workload(binaries[0], prefix, directory / name, runs[name])
    record["outcome"] = "pass"


def execute():
    evidence = {
        "schema_version": 1, "scope": SCOPE, "version": VERSION, "source_id": SOURCE_ID,
        "production_verified": False, "outcome": "fail", "workload": TEST, "checks": {},
        "archives": {name: digest for name, digest, _ in ARCHIVES.values()},
        "scope_limits": ["Upstream twenty-second walthread1 with ten read/write workers and a checkpointer.",
                         "File-backed WAL on local storage. The upstream test sets synchronous=OFF."],
    }
    checks = evidence["checks"]
    try:
        archives = pinned_archives()
        evidence["toolchain"] = identify_tools("ar", "make", "musl-gcc", "qemu-x86_64")
        evidence["read_only_verifier"] = {
            "sqlite_version": sqlite3.sqlite_version,
            "module_sha256": sha256_file(Path(_sqlite3.__file__).resolve()),
        }
        evidence["inputs"] = verify_setup(checks, False, snapshot=inputs)
        workspace = BUILD / SCOPE
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            hosts = checks["hosted_controls"] = {"outcome": "fail"}
            hosted_controls(archives, directory, hosts)
            hosts["outcome"] = "pass"
            candidate = checks["candidate"] = {"outcome": "fail"}
            candidate_controls(archives, directory, candidate)
        if evidence["inputs"] != inputs() or archives != pinned_archives():
            raise GateError("inputs changed during SQLite concurrency verification")
        evidence["outcome"] = "pass"
    except (GateError, OSError, SpecError, KeyError, ValueError, sqlite3.Error,
            subprocess.SubprocessError, zipfile.BadZipFile) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(SCOPE, evidence)
    print(f"{SCOPE} evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute())

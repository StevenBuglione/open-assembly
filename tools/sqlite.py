"""Verify pinned upstream SQLite workloads linked with Open Assembly."""

import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import zipfile

from gate import BUILD, GateError, checked, identify_tools, nm_symbols, source_policy, verify_setup, write_evidence
from phase1 import RUNTIME_LINK, build_runtime
from phase6 import phase6_inputs
from spec import ROOT, SpecError, sha256_file, snapshot_inputs

SCOPE = "phase6-sqlite"
VERSION = "3.53.3"
SOURCE_ID = "d4c0e51e4aeb96955b99185ab9cde75c339e2c29c3f3f12428d364a10d782c62"
SQLITE_C_SHA3 = "28e484abdaa43630e34040ef6ed92be973a1ad54107803d8af5145b889c23ed7"
ARCHIVES = {
    "OPEN_ASSEMBLY_SQLITE_SOURCE": (
        "sqlite-src-3530300", "bb80bf8a3bffc19241ce8aba5a4bc74e9c3980013cb0b5f0f0976a99516942af",
        {
            "manifest.uuid": "3ec90494f84736dd7efd0f49a06b787d3f791e0d6b2b1e0bce66fa792d6107e4",
            "test/speedtest1.c": "b5eaf4bbcbb320fd8eb3f3e6c4cd5f51a64dd0cd70efe969634d1785e3419675",
            "src/test_multiplex.c": "b0029217a5bed4b1d80036d502f3adfad9cf01e95a8597a87c3771774516e40d",
            "src/test_multiplex.h": "d74e1ed0a4ad4fb1e794306ddef605438b9bdb4043e69b9c075f337dc8922c25",
            "test/threadtest3.c": "42a59be2a38dbe07fcc95cbc75c00d475f66b8144f0905d3b25a4ab3d660b829",
            "test/tt3_checkpoint.c": "753cb6ab938d631268d164c9051f465f74540fe8bca744148d4396dd19f73e2b",
            "test/tt3_index.c": "1974eda17d4a58467ca4781edc712ed48e5597c324f7006eab8be4b3e9e9c4fa",
            "test/tt3_lookaside1.c": "b41cf2e748fe44bb08ec6af334262d182531c4f5463def12525c16a65863f3ac",
            "test/tt3_shared.c": "6f78affdb079c14dde96b70807b8dadaa1dd82c9ff68f055d4a6cd153ef94014",
            "test/tt3_stress.c": "b64b507c38dac64b8a1f1683eb654c3d32f25adb8f725dc3002ab75d25be0d0f",
            "test/tt3_vacuum.c": "ca485fde486e8aed7e240943d52f7ff1633b3b168e850b7450dd029f61499595",
            "test/threadtest5.c": "e0fe5db88580e1ced451e5d69556959db9ed5d5dca0c483c692f6ea0cc8285ba",
        },
    ),
    "OPEN_ASSEMBLY_SQLITE_AMALGAMATION": (
        "sqlite-amalgamation-3530300", "646421e12aac110282ef8cc68f1a62d4bb15fc7b8f09da0b53e29ee690500431",
        {
            "sqlite3.c": "87497ab605bedd0dbee27a209c1eeff8c89b229b13f921a7efdbb81a13f779fd",
            "sqlite3.h": "4ff81af4849acabc76fc8349abb926814395072617ca18e08800abf734ab7612",
            "sqlite3ext.h": "ac9645e5c9ff0cf176efdd6e75cb5e98f46295d38e02db5c4d208826a39ab4be",
        },
    ),
}
DOC = Path("tests/external/sqlite/README.md")
COMPILE_FLAGS = (
    "-std=gnu17", "-O1", "-ffreestanding", "-fno-builtin", "-fno-pie", "-fno-lto",
    "-ffunction-sections", "-fdata-sections", "-Werror=implicit-function-declaration",
    "-Werror=int-conversion", "-DSQLITE_OMIT_LOAD_EXTENSION=1", "-DHAVE_NANOSLEEP=1", "-DNDEBUG",
)
TEST_SETS = ("main", "cte", "json", "parsenumber")
SPEED_ARGS = ("--verify", "--size", "1", "--journal", "wal", "--mmap", "1048576",
              "--checkpoint", "--testset", ",".join(TEST_SETS), "speedtest.db")
WORKLOADS = {
    "speedtest1": (False, SPEED_ARGS),
    "threadtest3": (True, ("shared1",)),
    "threadtest5": (True, ("--num-workers", "1")),
}
SPEED_HASH = "Verification Hash: 111316 5353830536d24573b658f66a0e0c93c215f76f53f4d856e2"
RUNTIME_SYMBOLS = {"__errno_location", "fcntl", "fsync", "gettimeofday", "mmap", "mremap", "munmap", "pread", "pwrite"}
THREAD_SYMBOLS = {"pthread_create", "pthread_join", "pthread_mutex_lock", "pthread_mutex_unlock"}


def input_snapshot():
    inputs = phase6_inputs()
    inputs.update(snapshot_inputs(ROOT, [Path(__file__).relative_to(ROOT), DOC, Path("nix/sqlite.nix")]))
    return dict(sorted(inputs.items()))


def pinned_archives():
    paths = {}
    for name, (_, expected, _) in ARCHIVES.items():
        value = os.environ.get(name)
        if not value or sha256_file(Path(value)) != expected:
            raise GateError(f"pinned SQLite archive {name} is unavailable or changed")
        paths[name] = Path(value)
    return paths


def extract_sources(archives, directory):
    directory.mkdir()
    hashes = {}
    for name, (stem, _, sources) in ARCHIVES.items():
        with zipfile.ZipFile(archives[name]) as release:
            for member, digest in sources.items():
                data = release.read(f"{stem}/{member}")
                if hashlib.sha256(data).hexdigest() != digest:
                    raise GateError(f"upstream SQLite source hash differs for {member}")
                filename = Path(member).name
                (directory / filename).write_bytes(data)
                hashes[filename] = digest
    if ((directory / "manifest.uuid").read_text().strip() != SOURCE_ID or
            hashlib.sha3_256((directory / "sqlite3.c").read_bytes()).hexdigest() != SQLITE_C_SHA3):
        raise GateError("SQLite source identifier or official amalgamation digest differs")
    return hashes


def compile_objects(directory, workload, compiler, threaded, candidate, log):
    flags = [*COMPILE_FLAGS, f"-DSQLITE_THREADSAFE={int(threaded)}",
             f"-ffile-prefix-map={directory}=/upstream/sqlite", "-I", directory]
    if candidate:
        flags.extend(("-I", "build/include/c"))
    objects = []
    names = ("sqlite3", workload, "test_multiplex") if workload == "threadtest3" else ("sqlite3", workload)
    for name in names:
        source, obj = directory / f"{name}.c", directory / f"{name}.o"
        extra = ("-include", "stdint.h") if name == "threadtest3" else ()
        checked(log, [compiler, *flags, *extra, "-c", source, "-o", obj], timeout=120)
        objects.append(obj)
    if candidate:
        checked(log, ["tools/elf-audit", "--test-object", *objects])
    return objects


def verify_link(objects, runtime, workload, threaded, record):
    startup, archive, exports, _ = runtime
    required = RUNTIME_SYMBOLS | (THREAD_SYMBOLS if threaded else set())
    if workload == "threadtest3":
        required.add("strerror_r")
    if any(exports.get(name) != "T" for name in required):
        raise GateError(f"Open Assembly archive is missing a required {workload} symbol")
    directory = objects[0].parent
    binary, link_map = directory / workload, directory / "link.map"
    log = record["commands"]
    checked(log, [*RUNTIME_LINK, f"-Map={link_map}", "--cref", "-o", binary, startup, objects[1], objects[0], *objects[2:], archive])
    checked(log, ["tools/elf-audit", binary])
    if nm_symbols(log, binary, ["-u"]):
        raise GateError(f"{workload} has unresolved symbols")
    engine_api = "sqlite3_open" if workload == "threadtest5" else "sqlite3_open_v2"
    expected = required | {"_start", "main", engine_api}
    if workload == "threadtest3":
        expected.add("sqlite3_multiplex_initialize")
    symbols = nm_symbols(log, binary, ["-g", "--defined-only"])
    if any(symbols.get(name) != "T" for name in expected) or {"dlopen", "dlclose", "dlsym", "dlerror"} & symbols.keys():
        raise GateError(f"{workload} omitted a required symbol or linked a dynamic loader")
    table = link_map.read_text().partition("Cross Reference Table\n")[2]
    origins = {}
    for line in table.splitlines():
        if line and not line[0].isspace():
            fields = line.split(maxsplit=1)
            if len(fields) == 2 and fields[0] in expected:
                origins.setdefault(*fields)
    if (set(origins) != expected or origins["_start"] != str(startup) or
            origins["main"] != str(objects[1]) or origins[engine_api] != str(objects[0]) or
            (workload == "threadtest3" and origins["sqlite3_multiplex_initialize"] != str(objects[2])) or
            any(not origins[name].startswith(f"{archive}(") for name in required)):
        raise GateError(f"{workload} link map did not establish archive and upstream origins")
    record.update(outcome="pass", origins=origins, map_sha256=sha256_file(link_map),
                  executable_sha256=sha256_file(binary), objects={obj.name: sha256_file(obj) for obj in objects})
    return binary


def normalize_speed(stdout):
    lines = stdout.splitlines()
    hashes = [line for line in lines if line.startswith("Verification Hash:")]
    markers = [match[1] for line in lines if (match := re.fullmatch(r'\s*Begin testset "([^"]+)"', line))]
    first_set = len(lines) > 1 and lines[0].startswith(f"-- Speedtest1 for SQLite {VERSION} ") and (
        lines[1].startswith(" 100 - 500 INSERTs into table with no index")
    )
    if not first_set or hashes != [SPEED_HASH] or markers != list(TEST_SETS[1:]):
        raise GateError("speedtest1 verification hash or test-set markers differ")
    return {"verification_hash": hashes[0], "test_sets": [TEST_SETS[0], *markers]}


def normalize_shared(stdout):
    lines = stdout.splitlines()
    if len(lines) != 7 or lines[0] != "Running shared1 for 10 seconds..." or lines[-1] != "0 errors out of 1 tests":
        raise GateError("threadtest3 shared1 did not finish its selected upstream test")
    workers = []
    for line in lines[1:-1]:
        match = re.fullmatch(r"Thread ([1-5]) says: done!", line)
        if match is None:
            raise GateError(f"threadtest3 worker report has an unexpected shape: {line}")
        workers.append(int(match[1]))
    if sorted(workers) != [1, 2, 3, 4, 5]:
        raise GateError("threadtest3 shared1 did not finish five distinct workers")
    return {"test": "shared1", "workers": sorted(workers), "errors": 0}


def normalize_tasks(stdout):
    lines = stdout.splitlines()
    if len(lines) != 2 or lines[-1] != "OK":
        raise GateError("threadtest5 did not finish the one-worker report and the upstream OK")
    match = re.fullmatch(r"W00: ([0-9]+(?:,[0-9]+)*)", lines[0])
    tasks = sorted(int(task) for task in match[1].split(",")) if match else []
    if tasks != list(range(1, 101)):
        raise GateError("threadtest5 did not finish exactly 100 distinct tasks")
    return {"workers": 1, "tasks": tasks, "upstream_ok": True}


def execute_workload(binary, wrapper, directory, workload, record):
    directory.mkdir()
    command = [*wrapper, str(binary.resolve()), *WORKLOADS[workload][1]]
    result = subprocess.run(command, cwd=directory, stdin=subprocess.DEVNULL, capture_output=True, text=True,
                            timeout=180, env={"LC_ALL": "C", "TZ": "UTC0", "PATH": os.environ["PATH"]})
    record.update(command=command, status=result.returncode, stdout=result.stdout, stderr=result.stderr,
                  executable_sha256=sha256_file(binary))
    if result.returncode or result.stderr:
        raise GateError(f"{directory.name} failed: {(result.stderr or result.stdout).strip()}")
    normalizers = {"speedtest1": normalize_speed, "threadtest3": normalize_shared, "threadtest5": normalize_tasks}
    record["normalized"] = normalizers[workload](result.stdout)
    record["outcome"] = "pass"


def check_workload(directory, workload, threaded, archives, runtimes, runners, record):
    directory.mkdir()
    links = record["candidate_builds"] = []
    candidates = []
    for index, runtime in enumerate(runtimes, 1):
        source = directory / f"candidate-{index}"
        build = {"outcome": "fail", "commands": []}
        links.append(build)
        build["sources"] = extract_sources(archives, source)
        objects = compile_objects(source, workload, "gcc", threaded, True, build["commands"])
        if any(sha256_file(source / name) != digest for name, digest in build["sources"].items()):
            raise GateError(f"{workload} build changed upstream sources")
        candidates.append(verify_link(objects, runtime, workload, threaded, build))
    if any(links[0][key] != links[1][key] for key in ("objects", "executable_sha256")):
        raise GateError(f"two isolated {workload} builds differ")
    runs = record["runs"] = {}
    for backend, wrapper in runners.items():
        runs[backend] = {"outcome": "fail"}
        execute_workload(candidates[0], wrapper, directory / backend, workload, runs[backend])
        print(f"PASS SQLite {VERSION} {workload} {backend}", flush=True)

    for compiler, host in (("gcc", "glibc"), ("musl-gcc", "musl")):
        source = directory / f"source-{host}"
        host_record = runs[host] = {"outcome": "fail", "commands": []}
        host_record["sources"] = extract_sources(archives, source)
        objects = compile_objects(source, workload, compiler, threaded, False, host_record["commands"])
        binary = source / workload
        checked(host_record["commands"], [compiler, "-no-pie", "-Wl,--gc-sections", "-pthread", "-o", binary,
                                         objects[1], objects[0], *objects[2:], "-lm"])
        execute_workload(binary, (), directory / host, workload, host_record)
        if host_record["normalized"] != runs["native"]["normalized"]:
            raise GateError(f"{workload} {host} control differs")
        print(f"PASS SQLite {VERSION} {workload} {host} control", flush=True)
    record["outcome"] = "pass"


def execute():
    evidence = {"schema_version": 1, "scope": SCOPE, "version": VERSION, "source_id": SOURCE_ID,
                "production_verified": False, "outcome": "fail", "checks": {},
                "archives": {stem: digest for stem, digest, _ in ARCHIVES.values()},
                "official_sqlite3_sha3_256": SQLITE_C_SHA3,
                "scope_limits": ["Selected single-threaded speedtest1 workloads with file-backed WAL and mmap.",
                                 "Five upstream threadtest3 shared-cache readers and zero upstream errors.",
                                 "Upstream threadtest5 memory VFS with one worker and all 100 tasks.",
                                 "Dynamic extensions and the full upstream Tcl suite are outside this gate."]}
    checks = evidence["checks"]
    try:
        archives = pinned_archives()
        evidence["toolchain"] = identify_tools("ar", "make", "musl-gcc", "qemu-x86_64")
        evidence["inputs"] = verify_setup(checks, False, snapshot=input_snapshot)
        workspace = BUILD / SCOPE
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            runtime = checks["runtime"] = {"outcome": "fail", "commands": []}
            builds = [build_runtime(directory / f"runtime-{index}", runtime["commands"]) for index in (1, 2)]
            if builds[0][3] != builds[1][3]:
                raise GateError("two isolated SQLite runtime builds differ")
            runtime.update(outcome="pass", artifacts=builds[0][3])
            runners = {"native": (), "qemu": (shutil.which("qemu-x86_64"),),
                       "memcheck": (shutil.which("valgrind"), "--quiet", "--error-exitcode=99")}
            for name, (threaded, _) in WORKLOADS.items():
                record = checks[name] = {"outcome": "fail", "threadsafe": int(threaded)}
                check_workload(directory / name, name, threaded, archives, builds, runners, record)
        if evidence["inputs"] != input_snapshot() or archives != pinned_archives():
            raise GateError("inputs changed during SQLite verification")
        evidence["outcome"] = "pass"
    except (GateError, OSError, SpecError, KeyError, ValueError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(SCOPE, evidence)
    print(f"phase6 SQLite evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute())

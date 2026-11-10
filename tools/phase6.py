"""Verify scoped Phase 6 APIs against the real runtime."""

import argparse
from functools import partial
from pathlib import Path
import shutil
import sys
import tempfile

from gate import BUILD, GateError, identify_tools, source_policy, verify_setup, write_evidence
from phase1 import build_case, build_runtime, generate_stub, phase1_inputs
from phase4 import execute_probe, host_binary, load_probes, parse_probe
from spec import ROOT, SpecError, load_project, sha256_file, snapshot_inputs

SUITE = Path("tests/phase6")
ABI_FIXTURES = (Path("tests/phase2/abi.asm"), SUITE / "abi_varargs.asm")
PUBLIC = {
    "open", "openat", "creat", "lseek", "dup", "dup2", "pipe", "mkdir", "rmdir", "unlink",
    "stat", "lstat", "fstat", "fstatat", "opendir", "fdopendir", "readdir", "closedir", "dirfd",
}
COMPAT = {
    "chmod", "dirname", "ferror_unlocked", "fputs_unlocked", "getc_unlocked", "getcwd", "getopt", "ioctl",
    "isatty", "putchar_unlocked", "readlink", "strdup", "umask", "vasprintf",
}
COMPAT_FAULT_WRAPPERS = {
    SUITE / "compat/vasprintf_fault.c": ("realloc", "free"),
    SUITE / "compat/unlocked_lock.c": ("__al_lock", "__al_unlock"),
}
PROCESS = {"execve", "fork", "getpid", "getppid", "pipe2", "wait", "waitpid"}
SIGNAL = {"kill", "raise", "sigaction", "sigaddset", "sigdelset", "sigemptyset", "sigfillset", "sigismember",
          "signal", "sigpending", "sigprocmask", "sigsuspend"}
JUMP = {"setjmp", "longjmp", "sigsetjmp", "siglongjmp"}
TIME = {"clock", "clock_gettime", "clock_getres", "clock_nanosleep", "nanosleep", "time", "timespec_get"}
CALENDAR = {"difftime", "gmtime", "gmtime_r"}
LUAFILES = {"mkstemp", "remove", "rename", "tmpfile"}
SHELL = {"system", "popen", "pclose"}
PATH_EXEC = {"execv", "execvp", "posix_spawnp"}
STRFTIME = {"strftime"}
FCNTL = {"fcntl"}
ZONE = {"localtime_r", "mktime"}
SPAWN = {
    "posix_spawn", "posix_spawn_file_actions_init", "posix_spawn_file_actions_destroy",
    "posix_spawn_file_actions_addclose", "posix_spawn_file_actions_adddup2", "posix_spawn_file_actions_addopen",
    "posix_spawnattr_init", "posix_spawnattr_destroy", "posix_spawnattr_getflags", "posix_spawnattr_setflags",
    "posix_spawnattr_getpgroup", "posix_spawnattr_setpgroup", "posix_spawnattr_getsigmask",
    "posix_spawnattr_setsigmask", "posix_spawnattr_getsigdefault", "posix_spawnattr_setsigdefault",
}


def phase6_inputs():
    hashes = phase1_inputs()
    hashes.update(snapshot_inputs(ROOT, [Path("docs/adr/0007-linux-files-process-signal-time.md")]))
    return dict(sorted(hashes.items()))


def run_cases(probes, directory, first, second, runners, checks, host_macro, *, classify_native=False):
    hosts = directory / "host"
    hosts.mkdir()
    for probe in probes:
        case = probe.case
        item = {
            "outcome": "fail", "oracle": case.oracle, "required_symbols": case.requires,
            "link_wraps": probe.wraps, "commands": [], "runs": {}, "host_runs": {},
            "host_skip": probe.host_skip, "skipped_backends": case.skip,
            "fixture_files": {name: value.hex() for name, value in probe.files.items()},
            "expected": {"status": case.status, "stdout_hex": probe.stdout.hex(), "stderr": case.stderr},
        }
        checks[case.name] = item
        work = directory / case.name
        work.mkdir()
        binary, artifacts = build_case(case, work / "first", first, item["commands"], link_wraps=probe.wraps)
        _, repeated = build_case(case, work / "second", second, item["commands"], link_wraps=probe.wraps)
        item["artifacts"] = {"first": artifacts, "second": repeated}
        if artifacts != repeated:
            raise GateError(f"{case.name}: isolated fixture builds differ")
        for backend in case.backends:
            execute_probe(probe, binary, work / backend, item["runs"], {backend: runners[backend]},
                          classify_native=classify_native)
        if probe.host_skip is None:
            macro = host_macro(probe) if callable(host_macro) else host_macro
            for compiler, oracle in (("gcc", "diff:glibc"), ("musl-gcc", "diff:musl")):
                host = host_binary(compiler, case.sources, hosts, item["commands"], host_macro=macro)
                execute_probe(probe, host, work / compiler, item["host_runs"], {oracle: []})
                item["host_runs"][oracle]["artifact_sha256"] = sha256_file(host)
        item["outcome"] = "pass"


def run_stubs(controls, project, directory, runtime, check):
    for symbol, (probe, expected) in controls.items():
        work = directory / f"stub-{symbol}"
        work.mkdir()
        item = {"outcome": "fail", "case": probe.case.name, "oracle": probe.case.oracle,
                "expected_rejection": [expected[0], expected[1].hex(), expected[2].hex()],
                "commands": [], "runs": {}}
        check["symbols"][symbol] = item
        obj, item["source_sha256"] = generate_stub(project.functions[symbol], work, item["commands"])
        binary, item["artifacts"] = build_case(probe.case, work / "probe", runtime, item["commands"],
                                                (symbol, obj), link_wraps=probe.wraps)
        execute_probe(probe, binary, work / "inputs", item["runs"], {f"stub:{symbol}": []}, expected)
        item["outcome"] = "pass"
    check["outcome"] = "pass"


def execute_phase6(suite_name):
    scope = f"phase6-{suite_name}"
    suite = SUITE if suite_name == "files" else SUITE / suite_name
    public = {"files": PUBLIC, "compat": COMPAT, "process": PROCESS, "signal": SIGNAL, "jump": JUMP,
              "time": TIME, "calendar": CALENDAR, "luafiles": LUAFILES, "spawn": SPAWN,
              "shell": SHELL, "path": PATH_EXEC, "strftime": STRFTIME, "fcntl": FCNTL, "zone": ZONE}[suite_name]
    fault_wrappers = {
        SUITE / "fault.c": ("__al_syscall",),
        **COMPAT_FAULT_WRAPPERS,
        SUITE / "time/clock_fault.c": ("__al_syscall",),
        SUITE / "luafiles/fault.c": ("__al_syscall",),
        SUITE / "spawn/lifetime.c": ("malloc", "calloc", "realloc", "free"),
        SUITE / "shell/fault.c": ("__al_syscall",),
    }
    assembly = {"files": ABI_FIXTURES, "jump": (SUITE / "jump/registers.asm",),
                "fcntl": (Path("tests/phase2/abi.asm"), SUITE / "fcntl/variadic.asm")}.get(suite_name, ())
    return execute_manifest_gate(
        scope, suite, public, fault_wrappers, assembly, phase6_inputs, "OA_PHASE6_HOST",
        {"pending_phase6": ["additional per-function mutation and coverage"]},
    )


def execute_manifest_gate(scope, suite, public, fault_wrappers, assembly, inputs, host_macro, metadata, *,
                          external=None):
    evidence = {"schema_version": 1, "scope": scope, "production_verified": False,
                "outcome": "fail", "checks": {}, **metadata}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64", "musl-gcc")
        evidence["inputs"] = verify_setup(checks, False, snapshot=inputs)
        project = load_project()
        if not public <= project.functions.keys():
            raise GateError(f"missing {scope} specifications")
        parse = partial(parse_probe, suite=suite, programs=(), asm_fixtures=assembly,
                        fault_wrappers=fault_wrappers, allow_fixture_files=True)
        probes, controls = load_probes(suite / "manifest.toml", public, parse)
        runners = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
                   "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                "--leak-check=full", "--errors-for-leak-kinds=all"]}
        workspace = BUILD / scope
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            runtime = {"outcome": "fail", "commands": []}
            checks["runtime_build"] = runtime
            first = build_runtime(directory / "first", runtime["commands"])
            second = build_runtime(directory / "second", runtime["commands"])
            runtime["artifacts"] = {"first": first[3], "second": second[3]}
            if first[3] != second[3]:
                raise GateError(f"two isolated {scope} runtime builds differ")
            runtime["outcome"] = "pass"
            checks["cases"] = {}
            run_cases(probes, directory, first, second, runners, checks["cases"], host_macro)
            checks["stub_controls"] = {"outcome": "fail", "symbols": {}}
            run_stubs(controls, project, directory, first, checks["stub_controls"])
            if external is not None:
                external(directory, first, runners, checks)
        if evidence["inputs"] != inputs():
            raise GateError(f"inputs changed during {scope} verification")
        evidence["outcome"] = "pass"
    except (GateError, KeyError, OSError, SpecError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(scope, evidence)
    print(f"{scope} evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--compat", dest="suite", action="store_const", const="compat",
                      help="run the BusyBox compatibility API probes")
    mode.add_argument("--process", dest="suite", action="store_const", const="process",
                      help="run the process API probes")
    mode.add_argument("--signal", dest="suite", action="store_const", const="signal",
                      help="run the signal API probes")
    mode.add_argument("--jump", dest="suite", action="store_const", const="jump",
                      help="run the non-local jump API probes")
    mode.add_argument("--time", dest="suite", action="store_const", const="time",
                      help="run the time64 clock API probes")
    mode.add_argument("--calendar", dest="suite", action="store_const", const="calendar",
                      help="run the UTC calendar API probes")
    mode.add_argument("--luafiles", dest="suite", action="store_const", const="luafiles",
                      help="run the pathname and temporary file API probes")
    mode.add_argument("--spawn", dest="suite", action="store_const", const="spawn",
                      help="run the process spawn API probes")
    mode.add_argument("--shell", dest="suite", action="store_const", const="shell",
                      help="run the shell and pipe-stream API probes")
    mode.add_argument("--path", dest="suite", action="store_const", const="path",
                      help="run the PATH execution and spawn probes")
    mode.add_argument("--strftime", dest="suite", action="store_const", const="strftime",
                      help="run the C-locale date-formatting probes")
    mode.add_argument("--fcntl", dest="suite", action="store_const", const="fcntl",
                      help="run the variadic descriptor-control API probes")
    mode.add_argument("--zone", dest="suite", action="store_const", const="zone",
                      help="run the local civil time and TZif probes")
    parser.set_defaults(suite="files")
    raise SystemExit(execute_phase6(parser.parse_args().suite))

"""Build and run the pinned upstream Lua portable suite against the real runtime."""

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tarfile
import tempfile
from time import monotonic

from gate import BUILD, GateError, checked, identify_tools, nm_symbols, source_policy, verify_setup, write_evidence
from phase1 import RUNTIME_LINK, build_runtime
from phase6 import phase6_inputs
from spec import ROOT, SpecError, sha256_file, snapshot_inputs

VERSION = "5.4.9"
SOURCE_SHA256 = "2335b6c582a52654f94612bf10d2f4672805d05329aa6568b1d8cd9e5c6fb8e6"
TESTS_SHA256 = "7d971845f545ffc09fbb3128a86b2c6524161c70d0fdf0154a16e8c00c343fca"
LICENSE_SHA256 = "760d00c8b494ec2f170bcdd969e36b038027b0288232c60e15ffa6b0d784e9c7"
RUNNER_SHA256 = "3e296dd2b26ac6891ccba1ebaa62d40f1816ac93c7efdeaddc05aaa064e7311c"
DOC = Path("tests/external/lua/README.md")
APP_FLAGS = ("-DLUA_USE_POSIX", "-ffreestanding", "-fno-builtin", "-fno-pie", "-fno-lto",
             "-fno-stack-protector", "-ffunction-sections", "-fdata-sections",
             "-Werror=implicit-function-declaration", "-Werror=int-conversion")
RUNTIME_SYMBOLS = {
    "__errno_location", "_setjmp", "fopen", "fwrite", "gmtime_r", "localeconv",
    "localtime_r", "longjmp", "pclose", "popen", "pow", "setlocale", "snprintf",
    "strftime", "strtod", "system",
}
LOADLIB_PROBE = """
local result, message, where = package.loadlib("/__open_assembly_missing__.so", "luaopen_probe")
assert(result == nil and where == "absent")
assert(type(message) == "string" and message:find("dynamic libraries not enabled", 1, true))
print("static loadlib scope OK")
""".strip()


def input_snapshot():
    inputs = phase6_inputs()
    inputs.update(snapshot_inputs(ROOT, [Path(__file__).relative_to(ROOT), DOC, Path("nix/lua.nix")]))
    return dict(sorted(inputs.items()))


def pinned_archive(variable, expected):
    value = os.environ.get(variable)
    if not value or sha256_file(Path(value)) != expected:
        raise GateError(f"the pinned archive {variable} is unavailable or changed")
    return Path(value)


def extract(archive, destination, name):
    destination.mkdir()
    with tarfile.open(archive, "r:gz") as source:
        source.extractall(destination, filter="data")
    children = list(destination.iterdir())
    if len(children) != 1 or children[0].name != name or not children[0].is_dir():
        raise GateError(f"unexpected upstream directory for {archive.name}")
    return children[0]


def compile_lua(archive, directory, record):
    source = extract(archive, directory, f"lua-{VERSION}")
    license_file = source / "doc/readme.html"
    if sha256_file(license_file) != LICENSE_SHA256:
        raise GateError("the upstream Lua license document changed")
    original = {path.relative_to(source): sha256_file(path) for path in source.rglob("*") if path.is_file()}
    flags = " ".join((*APP_FLAGS, f"-I{ROOT / 'build/include/c'}"))
    log = record["commands"]
    src = source / "src"
    checked(log, ["make", "--no-print-directory", "-C", src, "-j2", "CC=gcc",
                  "AR=ar crsD", f"MYCFLAGS={flags}", "lua.o", "liblua.a"], timeout=180)
    if any(sha256_file(source / path) != digest for path, digest in original.items()):
        raise GateError("the Lua build changed the upstream sources")
    objects = sorted(src.glob("*.o"))
    if not objects:
        raise GateError("the upstream build did not produce Lua objects")
    checked(log, ["tools/elf-audit", "--test-object", *objects], timeout=90)
    record.update(outcome="pass", sources={path.as_posix(): digest for path, digest in original.items()},
                  artifacts={path.name: sha256_file(path) for path in (*objects, src / "liblua.a")})
    return src / "lua.o", src / "liblua.a"


def link_lua(objects, runtime, directory, record):
    startup, archive, exports, _ = runtime
    if any(exports.get(name) != "T" for name in RUNTIME_SYMBOLS):
        raise GateError("the runtime archive is missing a required Lua dependency")
    directory.mkdir()
    binary, link_map = directory / "lua", directory / "link.map"
    log = record["commands"]
    checked(log, [*RUNTIME_LINK, f"-Map={link_map}", "--cref", "-o", binary, startup, *objects, archive])
    checked(log, ["tools/elf-audit", binary])
    if nm_symbols(log, binary, ["-u"]):
        raise GateError("the Lua executable has unresolved symbols")
    symbols = nm_symbols(log, binary, ["-g", "--defined-only"])
    needed = RUNTIME_SYMBOLS | {"_start", "main", "lua_pcallk"}
    if any(symbols.get(name) != "T" for name in needed) or {
            "dlopen", "dlsym", "dlclose", "dlerror"} & symbols.keys():
        raise GateError("the Lua executable omitted a required symbol or linked a dynamic loader")
    table = link_map.read_text().partition("Cross Reference Table\n")[2]
    origins = {}
    for line in table.splitlines():
        if not line or line[0].isspace():
            continue
        fields = line.split(maxsplit=1)
        if len(fields) == 2 and fields[0] in needed:
            origins.setdefault(*fields)
    if (set(origins) != needed or origins["_start"] != str(startup) or
            origins["main"] != str(objects[0]) or
            not origins["lua_pcallk"].startswith(f"{objects[1]}(") or
            any(not origins[name].startswith(f"{archive}(") for name in RUNTIME_SYMBOLS)):
        raise GateError("the Lua link map did not establish runtime and upstream symbol origins")
    record.update(outcome="pass", origins=origins, executable_sha256=sha256_file(binary),
                  map_sha256=sha256_file(link_map))
    return binary


def observe(command, cwd, output, timeout):
    started = monotonic()
    result = subprocess.run(list(map(str, command)), cwd=cwd, stdin=subprocess.DEVNULL,
                            capture_output=True, timeout=timeout,
                            env={"LC_ALL": "C", "TZ": "UTC0", "PATH": os.environ["PATH"]})
    output.update(command=list(map(str, command)), status=result.returncode,
                  elapsed_seconds=monotonic() - started,
                  stdout=result.stdout.decode(errors="replace"), stderr=result.stderr.decode(errors="replace"))
    return result


def portable_run(archive, binary, directory, wrapper, record):
    work = extract(archive, directory, f"lua-{VERSION}-tests")
    script = work / "all.lua"
    if sha256_file(script) != RUNNER_SHA256:
        raise GateError("the upstream all.lua runner changed")
    record.update(script_sha256=RUNNER_SHA256, binary_sha256=sha256_file(binary), version={},
                  portable={}, dynamic_loading={})
    command = [*wrapper, binary.resolve()]
    version = observe([*command, "-v"], work, record["version"], 30)
    if version.returncode or version.stderr or not version.stdout.startswith(f"Lua {VERSION} ".encode()):
        raise GateError(f"{directory.name} did not identify the exact Lua release")
    test = observe([*command, "-e", "_U=true", "all.lua"], work, record["portable"], 180)
    completed = [line for line in test.stdout.splitlines() if line.strip() == b"final OK !!!"]
    if test.returncode or len(completed) != 1:
        raise GateError(f"{directory.name} did not finish the upstream Lua portable suite")
    scope = observe([*command, "-e", LOADLIB_PROBE], work, record["dynamic_loading"], 30)
    if scope.returncode or scope.stdout != b"static loadlib scope OK\n" or scope.stderr:
        raise GateError(f"{directory.name} did not report the expected static loading scope")
    record["outcome"] = "pass"


def execute():
    evidence = {"schema_version": 1, "scope": "phase6-lua", "outcome": "fail",
                "production_verified": False, "version": VERSION, "checks": {},
                "upstream": {"source_sha256": SOURCE_SHA256, "tests_sha256": TESTS_SHA256,
                             "license_document_sha256": LICENSE_SHA256, "license": "MIT"},
                "limits": ["Upstream _U=true portable/basic suite.",
                           "Static Lua module loading scope without a dynamic C loader."]}
    checks = evidence["checks"]
    try:
        source = pinned_archive("OPEN_ASSEMBLY_LUA_SOURCE", SOURCE_SHA256)
        tests = pinned_archive("OPEN_ASSEMBLY_LUA_TESTS", TESTS_SHA256)
        evidence["toolchain"] = identify_tools("ar", "make", "ranlib", "qemu-x86_64")
        evidence["inputs"] = verify_setup(checks, False, snapshot=input_snapshot)
        workspace = BUILD / "phase6-lua"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            runtime_record = checks["runtime"] = {"outcome": "fail", "commands": []}
            runtimes = [build_runtime(directory / f"runtime-{index}", runtime_record["commands"])
                        for index in (1, 2)]
            if runtimes[0][3] != runtimes[1][3]:
                raise GateError("the two runtime builds differ")
            runtime_record.update(outcome="pass", artifacts=runtimes[0][3])

            compilations = checks["compile"] = [{"outcome": "fail", "commands": []} for _ in runtimes]
            links = checks["link"] = [{"outcome": "fail", "commands": []} for _ in runtimes]
            objects = [compile_lua(source, directory / f"source-{index}", record)
                       for index, record in enumerate(compilations, 1)]
            if compilations[0]["artifacts"] != compilations[1]["artifacts"]:
                raise GateError("the two Lua object and archive builds differ")
            binaries = [link_lua(objects[index], runtime, directory / f"link-{index + 1}", links[index])
                        for index, runtime in enumerate(runtimes)]
            if links[0]["executable_sha256"] != links[1]["executable_sha256"]:
                raise GateError("the two Lua executable links differ")

            execution = checks["execution"] = {}
            runners = {"native": (), "qemu": (shutil.which("qemu-x86_64"),),
                       "memcheck": (shutil.which("valgrind"), "--quiet", "--error-exitcode=99")}
            for backend, wrapper in runners.items():
                record = execution[backend] = {"outcome": "fail"}
                portable_run(tests, binaries[0], directory / backend, wrapper, record)
                print(f"PASS Lua {VERSION} portable suite and static loading scope under {backend}", flush=True)
        if evidence["inputs"] != input_snapshot() or (
                sha256_file(source) != SOURCE_SHA256 or sha256_file(tests) != TESTS_SHA256):
            raise GateError("inputs changed during Lua verification")
        evidence["outcome"] = "pass"
    except (GateError, OSError, SpecError, ValueError, subprocess.SubprocessError, tarfile.TarError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    path = write_evidence("phase6-lua", evidence)
    print(f"phase6 Lua evidence {path}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute())

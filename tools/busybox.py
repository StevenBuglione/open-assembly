"""Build pinned upstream BusyBox applets and run their freestanding link."""

import os
import re
from pathlib import Path
import shlex
import shutil
import stat
import sys
import tempfile

from gate import BUILD, GateError, checked, identify_tools, nm_symbols, source_policy, verify_setup, write_evidence
from phase1 import build_runtime
from phase4 import observation
from phase6 import phase6_inputs
from spec import ROOT, SpecError, relative_path, regular_file, sha256_file

PIN = "1.37.0"
SOURCE_SHA256 = "3311dff32e746499f4df0d5df04d7eb396382d7e108bb9250e7b519b837043a4"
LICENSE_SHA256 = "bbfc9843646d483c334664f651c208b9839626891d8f17604db2146962f43548"
APPLETS = ("cat", "ls", "mkdir", "pwd", "rmdir", "wc")
FEATURES = {
    **{f"CONFIG_{name.upper()}": "y" for name in APPLETS},
    "CONFIG_BUSYBOX": "y",
    "CONFIG_STATIC": "y",
    "CONFIG_SH_IS_NONE": "y",
    "CONFIG_SH_IS_ASH": "n",
    "CONFIG_EXTRA_CFLAGS": '"-ffreestanding -fno-builtin -fno-pie"',
}
LINK_ORIGINS = {
    "_start": "crt1.o", "close": "close.o", "getcwd": "getcwd.o", "getopt": "getopt.o",
    "mkdir": "mkdir.o", "open": "open.o", "opendir": "opendir.o", "optarg": "getopt.o",
    "optind": "getopt.o", "readdir": "readdir.o", "rmdir": "rmdir.o", "stat": "stat.o",
    "vasprintf": "vasprintf.o", "write": "write.o",
}


def configuration(path, write):
    lines = path.read_text().splitlines()
    if write:
        replaced = set()
        for index, line in enumerate(lines):
            option = re.match(r"(?:# )?(CONFIG_[A-Z0-9_]+)(?:=| is not set$)", line)
            if option is None or option[1] not in FEATURES:
                continue
            name = option[1]
            value = FEATURES[name]
            lines[index] = f"# {name} is not set" if value == "n" else f"{name}={value}"
            replaced.add(name)
        if replaced != FEATURES.keys():
            raise GateError("BusyBox configuration is missing a selected option")
        path.write_text("\n".join(lines) + "\n")
    else:
        wanted = {f"# {name} is not set" if value == "n" else f"{name}={value}"
                  for name, value in FEATURES.items()}
        if not wanted <= set(lines) or "CONFIG_SHELL_ASH=y" in lines:
            raise GateError("BusyBox configuration diverged from the selected applet set")


def build_upstream(directory, item):
    source_path = os.environ.get("OPEN_ASSEMBLY_BUSYBOX_SOURCE")
    if not source_path or sha256_file(source_path) != SOURCE_SHA256:
        raise GateError("the pinned BusyBox source archive is unavailable")
    directory.mkdir()
    log = item["commands"]
    checked(log, ["tar", "-xjf", source_path, "--strip-components=1", "-C", directory], timeout=60)
    license_path = directory / "LICENSE"
    if sha256_file(license_path) != LICENSE_SHA256:
        raise GateError("unexpected BusyBox license file")
    build = ["make", "--no-print-directory", "-C", directory]
    checked(log, [*build, "allnoconfig"], timeout=60)
    configuration(directory / ".config", write=True)
    checked(log, [*build, "oldconfig"], timeout=60)
    configuration(directory / ".config", write=False)
    checked(log, [*build, "-j8", "CC=musl-gcc", "HOSTCC=gcc", "busybox"], timeout=240)
    binary = directory / "busybox"
    checked(log, ["tools/elf-audit", binary])
    item.update(source_version=PIN, source_sha256=SOURCE_SHA256, license_sha256=LICENSE_SHA256,
                configuration_sha256=sha256_file(directory / ".config"),
                host_binary_sha256=sha256_file(binary), outcome="pass")
    return binary


def upstream_inputs(directory):
    command = directory / ".busybox_unstripped.cmd"
    prefix = "cmd_busybox_unstripped := "
    line = command.read_text().strip()
    if not line.startswith(prefix):
        raise GateError("unexpected BusyBox Kbuild link record")
    args = shlex.split(line.removeprefix(prefix))
    if len(args) < 9 or Path(args[0]).name != "trylink" or args[1:3] != ["busybox_unstripped", "musl-gcc"]:
        raise GateError("unexpected BusyBox Kbuild link command")
    objects = shlex.split(args[5])
    archives = shlex.split(args[6])
    paths = objects + archives
    if (objects != ["applets/built-in.o"] or "libbb/lib.a" not in archives
            or len(paths) != len(set(paths)) or any(Path(path).suffix not in {".o", ".a"} for path in paths)):
        raise GateError("unexpected BusyBox Kbuild link inputs")
    return ([regular_file(directory, relative_path(path, command), command) for path in objects],
            [regular_file(directory, relative_path(path, command), command) for path in archives])


def link_candidate(upstream, directory, runtime, item):
    startup, archive, exports, _ = runtime
    if not LINK_ORIGINS.keys() <= exports.keys():
        raise GateError("the runtime is missing a required BusyBox symbol")
    objects, archives = upstream_inputs(upstream)
    log = item["commands"]
    item["upstream_link_inputs"] = {path.relative_to(upstream).as_posix(): sha256_file(path)
                                    for path in objects + archives}
    checked(log, ["tools/elf-audit", "--test-object", *objects])
    hashes = {}
    for attempt in ("first", "second"):
        work = directory / attempt
        work.mkdir(parents=True)
        binary = work / "busybox"
        map_file = work / "link.map"
        checked(log, ["ld", "-m", "elf_x86_64", "-static", "-no-pie", "-z", "noexecstack",
                      "--gc-sections", "--fatal-warnings", "--no-undefined", "-e", "_start",
                      f"-Map={map_file}", "--cref", "-o", binary, startup, *objects,
                      "--start-group", *archives, archive, "--end-group"])
        expected = {name: str(startup) if name == "_start" else f"{archive}({member})"
                    for name, member in LINK_ORIGINS.items()}
        table = map_file.read_text().partition("Cross Reference Table\n")[2]
        origins = {fields[0]: fields[1] for line in table.splitlines() if len(fields := line.split()) == 2
                   and fields[0] in LINK_ORIGINS}
        if origins != expected:
            raise GateError("BusyBox link map does not attribute every required symbol to the runtime")
        checked(log, ["tools/elf-audit", binary])
        if nm_symbols(log, binary, ["-u"]):
            raise GateError("the BusyBox executable has unresolved symbols")
        hashes[attempt] = {"binary_sha256": sha256_file(binary), "map_sha256": sha256_file(map_file)}
    if hashes["first"]["binary_sha256"] != hashes["second"]["binary_sha256"]:
        raise GateError("two links of the BusyBox executable differ")
    item.update(artifacts=hashes, runtime_origins=origins, outcome="pass")
    return directory / "first" / "busybox"


def run_applets(binary, work, wrapper, runs):
    work.mkdir()
    (work / "tail").write_bytes(b"file\x00tail\xff\n")
    (work / "listing").mkdir()
    for name in ("beta", "alpha"):
        (work / "listing" / name).write_bytes(name.encode())
    (work / "listing" / "sym").symlink_to("alpha")

    def applet(name, args, *, stdin=b"", stdout=b"", status=0, stderr=b"", validate=None):
        observed, record = observation([*wrapper, binary.resolve(), *args], work, stdin, {"LC_ALL": "C"})
        code, output, error = observed
        record["outcome"] = "fail"
        runs[name] = record
        if (code != status or (stdout is not None and output != stdout)
                or (stderr is not None and error != stderr)
                or (validate is not None and not validate(output, error))):
            raise GateError(f"BusyBox {name} in {work.name}: observed {observed!r} or wrong file state")
        record["outcome"] = "pass"

    applet("dispatcher", ["--list"], stdout="".join(f"{name}\n" for name in APPLETS).encode())
    applet("cat", ["cat", "-", "tail"], stdin=b"stdin\xff\n", stdout=b"stdin\xff\nfile\x00tail\xff\n")
    applet("wc", ["wc", "-lwc"], stdin=b"one two\nthree\n", stdout=None,
           validate=lambda output, error: output.split() == [b"2", b"3", b"14"])
    applet("pwd", ["pwd"], stdout=f"{work.resolve()}\n".encode())
    applet("mkdir", ["mkdir", "-m", "700", "made"],
           validate=lambda output, error: (work / "made").stat().st_mode == stat.S_IFDIR | 0o700)
    # The allnoconfig build uses filesystem iteration order for ls.
    applet("ls", ["ls", "-1", "listing"], stdout=None,
           validate=lambda output, error: sorted(output.splitlines(keepends=True)) == [b"alpha\n", b"beta\n", b"sym\n"])
    applet("rmdir", ["rmdir", "made"], validate=lambda output, error: not (work / "made").exists())
    applet("missing", ["ls", "missing-file"], status=1, stderr=None,
           validate=lambda output, error: b"missing-file" in error and error.endswith(b"\n"))


def execute_busybox():
    evidence = {"schema_version": 1, "scope": "phase6-busybox", "production_verified": False,
                "outcome": "fail", "checks": {},
                "pending_phase6": ["spawn and exec search", "time and TZif"]}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "tar", "qemu-x86_64", "musl-gcc")
        bzip2 = shutil.which("bzip2")
        if not bzip2:
            raise GateError("the pinned toolchain must provide bzip2")
        evidence["toolchain"]["bzip2"] = {"sha256": sha256_file(Path(bzip2).resolve())}
        evidence["inputs"] = verify_setup(checks, False, snapshot=phase6_inputs)
        workspace = BUILD / "phase6-busybox"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            checks["runtime_build"] = {"outcome": "fail", "commands": []}
            runtime = build_runtime(directory / "runtime", checks["runtime_build"]["commands"])
            checks["runtime_build"].update(outcome="pass", artifacts=runtime[3])
            checks["upstream_build"] = {"outcome": "fail", "commands": []}
            upstream = directory / "upstream"
            host = build_upstream(upstream, checks["upstream_build"])
            checks["candidate_link"] = {"outcome": "fail", "commands": []}
            candidate = link_candidate(upstream, directory / "candidate", runtime, checks["candidate_link"])
            checks["execution"] = {"outcome": "fail", "runs": {},
                                   "oracle": ["reference:applet-output-and-filesystem", "diff:pinned-musl-BusyBox"],
                                   "directory_order": "Compare exact output line counts independent of directory iteration order.",
                                   "valgrind_leaks": "Upstream allnoconfig leaves process-lifetime allocations."
                                                      " Memcheck checks addressing and initialized reads."}
            execution = checks["execution"]
            runners = {"host-musl": (host, []), "native": (candidate, []),
                       "qemu": (candidate, [shutil.which("qemu-x86_64")]),
                       "valgrind": (candidate, [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                               "--leak-check=no"])}
            for backend, (binary, wrapper) in runners.items():
                execution["runs"][backend] = {}
                run_applets(binary, directory / f"inputs-{backend}", wrapper, execution["runs"][backend])
                print(f"PASS BusyBox {backend} ({', '.join(APPLETS)})", flush=True)
            execution["outcome"] = "pass"
        if evidence["inputs"] != phase6_inputs():
            raise GateError("inputs changed during BusyBox verification")
        evidence["outcome"] = "pass"
    except (GateError, KeyError, OSError, SpecError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence("phase6-busybox", evidence)
    print(f"phase6 BusyBox evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute_busybox())

"""Run named, unmodified gnulib and native LTP tests against assembly candidates."""

import argparse
import os
from pathlib import Path
import re
import resource
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile

from gate import BUILD, COMPILE_FLAGS, LINK_FLAGS, GateError, checked, identify_tools, nm_symbols, verify_setup, write_evidence
from phase1 import Case, build_case, build_runtime, generate_stub, phase1_inputs
from spec import ROOT, load_project, sha256_file, snapshot_inputs

COMPAT = Path("tests/tooling/upstream")
CONTRACT = Path("docs/cookbook/upstream-conformance.md")
GNULIB_FILES = {
    "tests/test-lseek.c": "80cfdca884546f4df5370ad16518875be32a36437f61924a8a2566ee06b5ac4f",
    "tests/test-memchr.c": "fe7e6aab6166fc307afbe00bcf8588b7fde43ff52aa3c7b1c94a4355890fd99d",
    "tests/signature.h": "59d8371b28c414173abf7a695a228ad3148c67289aa4ca1d539b928348eee955",
    "tests/macros.h": "6b8d5602a83af2494e6c6c8ec61396a0e1648bfb4567690b06b6e2fb79667454",
    "tests/zerosize-ptr.h": "db01f7fab443b0ec8ff075c253adf005e11adf9af96205fbfb2d31ac979b6604",
    "COPYING": "438610ba3d10f492dff9e17f7d53a5316e3f4b4adc5f79a33ac7110d5a5ee210",
}
LTP_FILES = {
    "testcases/kernel/syscalls/dup/dup01.c": "d2de9028b1131ae75696c34f64012313305fda200c365901dd002541c6842d17",
    "testcases/kernel/syscalls/dup/dup02.c": "ffc1763c5de2e8cfabdc17b146fd20aeadcf98a9477ed21a0eae05f61756bbc4",
    "testcases/kernel/syscalls/lseek/lseek01.c": "bd151b5fcf22578761e5f20ac6016f823c4f747830b418275e71eea687d66118",
    "COPYING": "8177f97513213526df2cf6184d8ff986c675afb514d4e68a404010521b880643",
}
PINS = {
    "gnulib": ("OPEN_ASSEMBLY_GNULIB", "gnulib-41bae5c2f367ca71652f3b1f98f1257035994acd",
               "1d698e7a42bf5c3b8d772932a09ad113d58c63935c0b687a0263009ce1acfe9a", GNULIB_FILES),
    "native-ltp": ("OPEN_ASSEMBLY_OPEN_POSIX", "ltp-2279d708c817db657611a30c427c7d06c4360049",
                   "35146cb1d0e82517aac8dbefbd88bd96300ce383736aae069e435fd991ea50bb", LTP_FILES),
}
HOSTS = (("glibc", "gcc"), ("musl", "musl-gcc"))
HOST_FLAGS = tuple(flag for flag in COMPILE_FLAGS if flag != "-Werror")


def inputs():
    return dict(sorted((phase1_inputs() | snapshot_inputs(ROOT, [CONTRACT])).items()))


def extract_sources(suite, directory, report):
    variable, prefix, digest, files = PINS[suite]
    path = Path(os.environ.get(variable, "/missing-pinned-source"))
    if not path.is_file() or sha256_file(path) != digest:
        raise GateError(f"missing or mismatched pinned archive from {variable}")
    report["upstream"] = {"archive_sha256": digest, "archive_root": prefix, "files": files}
    with tarfile.open(path, "r:gz") as source:
        for name, expected in files.items():
            member = source.getmember(f"{prefix}/{name}")
            if not member.isfile():
                raise GateError(f"upstream member {name} is not a regular file")
            target = directory / name
            target.parent.mkdir(parents=True, exist_ok=True)
            with source.extractfile(member) as contents:
                target.write_bytes(contents.read())
            if sha256_file(target) != expected:
                raise GateError(f"upstream member {name} differs from its byte pin")


def compiled_host(source, compiler, suite, symbol, directory, record, *, guard=False,
                  candidate=None, stub=None):
    directory.mkdir()
    log = record["commands"]
    obj, binary, map_path = (directory / name for name in ("test.o", "test", "test.map"))
    replacement = candidate or stub
    target = f"__al_upstream_{symbol}" if replacement else symbol
    rename_flag = (f"-D{symbol}={target}",) if replacement else ()
    checked(log, [compiler, *HOST_FLAGS, *rename_flag, "-I", COMPAT / suite, "-c", source, "-o", obj])
    checked(log, ["tools/elf-audit", "--test-object", obj])
    undefined = nm_symbols(log, obj, ["-g", "-u"])
    required = {target, "mmap", "mprotect"} if guard else {target}
    if any(undefined.get(name) != "U" for name in required):
        raise GateError(f"{source.name}: missing direct test reference to {sorted(required)}")
    objects, options = [obj], []
    if guard:
        guard_object = directory / "guard.o"
        checked(log, [compiler, *COMPILE_FLAGS, "-c", COMPAT / "gnulib/guard.c", "-o", guard_object])
        checked(log, ["tools/elf-audit", "--test-object", guard_object])
        objects.append(guard_object)
        options.append("-Wl,--wrap=mmap,--wrap=mprotect")
    if replacement:
        renamed = directory / "replacement.o"
        entry = f"__wrap_{symbol}" if stub else symbol
        checked(log, ["objcopy", "--redefine-sym", f"{entry}={target}", replacement, renamed])
        checked(log, ["tools/elf-audit", "--assembly-object", renamed])
        objects.append(renamed)
    checked(log, [compiler, *LINK_FLAGS, f"-Wl,-Map,{map_path},--cref", *options, "-o", binary, *objects])
    checked(log, ["tools/elf-audit", binary])
    if replacement:
        refs = map_path.read_text().split("Cross Reference Table", 1)
        found = re.search(rf"(?m)^{re.escape(target)}[ \t]+(\S+)$", refs[-1])
        defined = nm_symbols(log, binary, ["-g", "--defined-only"])
        if found is None or Path(found[1]).resolve() != renamed.resolve() or defined.get(target) != "T":
            raise GateError(f"{symbol}: linked test lacks the expected replacement")
    record["artifacts"][directory.name] = {path.name: sha256_file(path) for path in [binary, map_path, *objects]}
    return binary


def archive_case(source, name, symbol, suite, directory, runtime, record, stub=None):
    case = Case(name, (source,), (symbol,), [], {}, 0, "", "", (f"suite:{suite}",), ("native",), {})
    binary, artifacts = build_case(case, directory, runtime, record["commands"],
                                   (symbol, stub) if stub else None, c_include=(COMPAT / suite,))
    record["artifacts"][directory.name] = artifacts
    return binary


def observe(prefix, binary, args, directory, mode):
    directory.mkdir()
    command = [*prefix, str(binary.resolve()), *args]
    options = {"cwd": directory, "env": {}, "stderr": subprocess.PIPE, "timeout": 120}
    if mode == "files":
        initial = b"gnulib-offset-probe\n"
        input_file, output_file = directory / "stdin", directory / "stdout"
        input_file.write_bytes(initial)
        output_file.write_bytes(initial)
        with input_file.open("rb") as stdin, output_file.open("r+b") as stdout:
            result = subprocess.run(command, stdin=stdin, stdout=stdout, **options)
        if input_file.read_bytes() != initial or output_file.read_bytes() != initial:
            raise GateError("gnulib lseek modified a descriptor fixture")
        output = b""
    else:
        stdin = subprocess.DEVNULL if mode == "ltp" else subprocess.PIPE
        result = subprocess.run(command, stdin=stdin, stdout=subprocess.PIPE, **options)
        output = result.stdout
    return {"command": command, "status": result.returncode,
            "stdout": output.decode("utf-8", errors="surrogateescape"),
            "stderr": result.stderr.decode("utf-8", errors="surrogateescape")}


def expect_gnulib(item, target, assertion=None):
    if assertion is None:
        if (item["status"], item["stdout"], item["stderr"]) != (0, "", ""):
            raise GateError(f"{target}: unexpected gnulib status {item['status']}: {item['stderr'][:1000]}")
        return
    if (item["status"] != -signal.SIGABRT or item["stdout"] or
            not re.search(rf"(?m)test-{re.escape(target)}\.c:\d+: assertion '{assertion}' failed$", item["stderr"])):
        raise GateError(f"{target}: stub did not hit the named upstream assertion")


def gnulib(directory, source_root, runtime, project, report):
    for symbol, modes in (("lseek", (("files", ["0"]), ("pipes", ["1"]), ("closed", ["2"]))),
                          ("memchr", (("guard", []),))):
        source = source_root / f"tests/test-{symbol}.c"
        work = directory / symbol
        work.mkdir()
        record = report["checks"][symbol] = {"outcome": "fail", "commands": [], "runs": {}, "artifacts": {}}
        guard = symbol == "memchr"
        binaries = {label: compiled_host(source, compiler, "gnulib", symbol, work / label, record, guard=guard)
                    for label, compiler in HOSTS}
        candidate = runtime[0].parent / "obj/string/memchr.o"
        if guard:
            binaries["candidate"] = compiled_host(source, "musl-gcc", "gnulib", symbol, work / "candidate",
                                                   record, guard=True, candidate=candidate)
            record["link_scope"] = "renamed original archive member with static musl test support"
            record["candidate_member_sha256"] = sha256_file(candidate)
        else:
            binaries["candidate"] = archive_case(source, symbol, symbol, "gnulib", work / "candidate", runtime, record)
            record["link_scope"] = "open-assembly startup and archive only"
        runs = {label: ([], binary) for label, binary in binaries.items()}
        runs["candidate-qemu"] = ([shutil.which("qemu-x86_64")], binaries["candidate"])
        runs["candidate-memcheck"] = ([shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                      "--leak-check=full"], binaries["candidate"])
        for label, (prefix, binary) in runs.items():
            for mode, args in modes:
                name = f"{label}-{mode}"
                result = observe(prefix, binary, args, work / name, mode)
                record["runs"][name] = result
                expect_gnulib(result, symbol)
        stub_dir = work / "generated-stub"
        stub_dir.mkdir()
        stub, record["stub_source_sha256"] = generate_stub(project.functions[symbol], stub_dir, record["commands"])
        if guard:
            binary = compiled_host(source, "musl-gcc", "gnulib", symbol, work / "stub", record,
                                   guard=True, stub=stub)
            assertion = r"memchr \(input, 'a', n\) == input"
        else:
            binary = archive_case(source, symbol, symbol, "gnulib", work / "stub", runtime, record, stub)
            assertion = r"lseek \(0, \(off_t\)2, SEEK_SET\) == 2"
        mode, args = modes[0]
        result = observe([], binary, args, work / "stub-input", mode)
        record["runs"]["stub"] = result
        expect_gnulib(result, symbol, assertion)
        record["outcome"] = "pass"
        print(f"PASS gnulib {symbol}, {len(record['runs']) - 1} positives and named stub rejection", flush=True)


def native_ltp(directory, source_root, runtime, project, report):
    cases = (("dup01", "dup", 2, 1), ("dup02", "dup", 2, 0), ("lseek01", "lseek", 4, 1))
    for name, symbol, passes, tmpdir in cases:
        source = source_root / f"testcases/kernel/syscalls/{symbol}/{name}.c"
        work = directory / name
        work.mkdir()
        record = report["checks"][name] = {"outcome": "fail", "commands": [], "runs": {}, "artifacts": {}}
        binaries = {label: compiled_host(source, compiler, "ltp", symbol, work / label, record)
                    for label, compiler in HOSTS}
        binaries["candidate"] = archive_case(source, name, symbol, "ltp", work / "candidate", runtime, record)
        for label, binary in binaries.items():
            result = observe([], binary, [], work / f"{label}-input", "ltp")
            record["runs"][label] = result
            if (result["status"], result["stdout"], result["stderr"]) != (
                    0, f"LTP scoped pass={passes} fail=0 tmpdir={tmpdir}\n", ""):
                raise GateError(f"{name}: {label} did not report the exact upstream assertion count")
        if name in {"dup01", "lseek01"}:
            stub_dir = work / "generated-stub"
            stub_dir.mkdir()
            stub, record["stub_source_sha256"] = generate_stub(project.functions[symbol], stub_dir, record["commands"])
            binary = archive_case(source, name, symbol, "ltp", work / "stub", runtime, record, stub)
            result = observe([], binary, [], work / "stub-input", "ltp")
            record["runs"]["stub"] = result
            expected = (1, "LTP scoped pass=1 fail=1 tmpdir=1\n") if name == "dup01" else (
                1, "LTP scoped pass=0 fail=4 tmpdir=1\n")
            errors = result["stderr"].splitlines()
            needle = "buf1.st_ino=" if name == "dup01" else "returned 0, expected "
            if (result["status"], result["stdout"]) != expected or not errors or any(
                    not error.startswith("TFAIL ") or needle not in error for error in errors):
                raise GateError(f"{name}: stub did not fail named LTP assertions")
        record["outcome"] = "pass"
        print(f"PASS native LTP {name}, {passes} assertions per implementation", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suite", choices=PINS)
    args = parser.parse_args()
    name = f"phase10-{args.suite}"
    report = {"schema_version": 1, "scope": name, "outcome": "fail", "production_verified": False,
              "checks": {}}
    try:
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        report["toolchain"] = identify_tools("ar", "make", "musl-gcc", "qemu-x86_64")
        report["inputs"] = verify_setup(report["checks"], False, snapshot=inputs)
        with tempfile.TemporaryDirectory(dir=BUILD, prefix=f"{name}-") as temp:
            directory = Path(temp).resolve().relative_to(ROOT)
            source = directory / "upstream"
            extract_sources(args.suite, source, report)
            build = report["checks"]["runtime_build"] = {"outcome": "fail", "commands": []}
            runtime = build_runtime(directory / "runtime", build["commands"])
            build.update(outcome="pass", artifacts=runtime[3])
            runner = gnulib if args.suite == "gnulib" else native_ltp
            runner(directory, source, runtime, load_project(), report)
        if inputs() != report["inputs"]:
            raise GateError("external suite inputs changed during execution")
        report["outcome"] = "pass"
    except (GateError, KeyError, OSError, ValueError, subprocess.SubprocessError, tarfile.TarError) as error:
        report["error"] = str(error)
        print(str(error), file=sys.stderr)
    path = write_evidence(name, report)
    print(f"{report['outcome'].upper()} {name}, evidence at {path}")
    return int(report["outcome"] != "pass")


if __name__ == "__main__":
    raise SystemExit(main())

"""Build and run pinned upstream zlib test programs with the assembly runtime."""

import gzip
from hashlib import sha256
import os
from pathlib import Path
import random
import shutil
import subprocess
import sys
import tempfile
from time import monotonic

from gate import BUILD, GateError, checked, identify_tools, nm_symbols, source_policy, verify_setup, write_evidence
from lua import extract, pinned_archive
from phase1 import RUNTIME_LINK, build_runtime
from phase6 import phase6_inputs
from spec import ROOT, SpecError, sha256_file

VERSION = "1.3.2"
SOURCE_SHA256 = "bb329a0a2cd0274d05519d61c667c062e06990d72e125ee2dfa8de64f0119d16"
LICENSE_SHA256 = "e32ff4e00d9d94930537635291da39e7e612703334bf6fde8c7f1686fe8a45a2"
TARGETS = ("example", "minigzip")
UPSTREAM_REFERENCES = {
    "example": {"compress", "uncompress", "gzopen", "gzread", "gzseek", "inflate", "inflateSync"},
    "minigzip": {"gzdopen", "gzopen", "gzread", "gzwrite"},
}
COMMON_RUNTIME = {"__errno_location", "fcntl", "open", "close", "lseek", "read", "write", "malloc",
                  "free", "memcpy", "strerror"}
RUNTIME_REFERENCES = {
    "example": COMMON_RUNTIME | {"calloc", "fprintf", "printf", "vsnprintf"},
    "minigzip": COMMON_RUNTIME | {"fclose", "fileno", "fopen", "fread", "fwrite"},
}
EXAMPLE_OUTPUT = b"""zlib version 1.3.2 = 0x1320, compile flags = 0xa9
uncompress(): hello, hello!
gzread(): hello, hello!
gzgets() after gzseek:  hello!
inflate(): hello, hello!
large_inflate(): OK
after inflateSync(): hello, hello!
inflate with dictionary: hello, hello!
"""
CFLAGS = (
    "-O2", "-ffreestanding", "-fno-builtin", "-fno-pie", "-fno-lto",
    "-ffunction-sections", "-fdata-sections", "-Werror=implicit-function-declaration",
    "-Werror=int-conversion", "-fPIC", "-D_LARGEFILE64_SOURCE=1", "-DHAVE_HIDDEN",
)


def configure(source, log):
    command = ["bash", "./configure", "--static"]
    result = subprocess.run(command, cwd=source, env={**os.environ, "CC": "gcc"},
                            capture_output=True, timeout=90)
    log.append({"command": command, "cwd": str(source), "returncode": result.returncode,
                "stdout": result.stdout.decode(errors="replace"), "stderr": result.stderr.decode(errors="replace")})
    if result.returncode or f"static library libz.a version {VERSION}" not in log[-1]["stdout"]:
        raise GateError("upstream zlib configuration did not select the pinned static library")


def compile_zlib(archive, directory, record):
    source = extract(archive, directory, f"zlib-{VERSION}")
    if sha256_file(source / "LICENSE") != LICENSE_SHA256:
        raise GateError("the upstream zlib license changed")
    generated = {Path("Makefile"), Path("zconf.h")}
    original = {path.relative_to(source): sha256_file(path) for path in source.rglob("*") if path.is_file()}
    log = record["commands"]
    configure(source, log)
    flags = " ".join((*CFLAGS, f"-I{ROOT / 'build/include/c'}"))
    checked(log, ["make", "--no-print-directory", "-C", source, "-j2", "CC=gcc -std=gnu99",
                  "AR=ar", "ARFLAGS=rcD", f"CFLAGS={flags}", "libz.a", "example.o", "minigzip.o"],
            timeout=180)
    if any(sha256_file(source / path) != digest for path, digest in original.items() if path not in generated):
        raise GateError("the zlib build changed a pinned upstream source")
    objects = sorted(source.glob("*.o"))
    library = source / "libz.a"
    expected = {path.name for path in objects} - {f"{name}.o" for name in TARGETS}
    members = checked(log, ["ar", "t", library]).splitlines()
    if set(members) != expected or len(set(members)) != len(members):
        raise GateError("zlib archive members do not match the upstream object build")
    checked(log, ["tools/elf-audit", "--test-object", *objects], timeout=90)
    for name, symbols in UPSTREAM_REFERENCES.items():
        referenced = nm_symbols(log, source / f"{name}.o", ["-g", "-u"])
        needed = symbols | ({"fileno"} if name == "minigzip" else set())
        if any(referenced.get(symbol) != "U" for symbol in needed):
            raise GateError(f"upstream {name} object lacks a required library reference")
    if nm_symbols(log, source / "gzlib.o", ["-g", "-u"]).get("fcntl") != "U":
        raise GateError("the upstream gzip file layer lacks its fcntl reference")
    record.update(outcome="pass", inputs={path.as_posix(): digest for path, digest in original.items()},
                  artifacts={path.name: sha256_file(path) for path in (*objects, library)},
                  archive_members=members)
    return source


def link_zlib(source, runtime, directory, record):
    startup, archive, exports, _ = runtime
    directory.mkdir()
    result = {}
    for name in TARGETS:
        item = record[name] = {"outcome": "fail", "commands": []}
        log = item["commands"]
        runtime_symbols = RUNTIME_REFERENCES[name]
        if any(exports.get(symbol) != "T" for symbol in runtime_symbols):
            raise GateError(f"the project runtime is missing a required {name} dependency")
        binary, link_map = directory / name, directory / f"{name}.map"
        main, library = source / f"{name}.o", source / "libz.a"
        checked(log, [*RUNTIME_LINK, f"-Map={link_map}", "--cref", "-o", binary, startup, main, library, archive])
        checked(log, ["tools/elf-audit", binary])
        if nm_symbols(log, binary, ["-u"]):
            raise GateError(f"{name} has unresolved linked symbols")
        needed = UPSTREAM_REFERENCES[name] | runtime_symbols | {"_start", "main"}
        defined = nm_symbols(log, binary, ["-g", "--defined-only"])
        if any(defined.get(symbol) != "T" for symbol in needed):
            raise GateError(f"{name} did not link all required upstream and runtime symbols")
        origins = {}
        for line in link_map.read_text().partition("Cross Reference Table\n")[2].splitlines():
            if not line or line[0].isspace():
                continue
            fields = line.split(maxsplit=1)
            if len(fields) == 2 and fields[0] in needed:
                origins.setdefault(*fields)
        if (origins.keys() != needed or origins["_start"] != str(startup) or origins["main"] != str(main)
                or any(not origins[symbol].startswith(f"{archive}(") for symbol in runtime_symbols)
                or any(not origins[symbol].startswith(f"{library}(") for symbol in UPSTREAM_REFERENCES[name])):
            raise GateError(f"{name} link map did not establish the exact static symbol origins")
        item.update(outcome="pass", executable_sha256=sha256_file(binary), map_sha256=sha256_file(link_map),
                    origins=origins)
        result[name] = binary
    return result


def observe(command, work, stdin, record):
    command = list(map(str, command))
    started = monotonic()
    result = subprocess.run(command, cwd=work, input=stdin, env={"LC_ALL": "C"},
                            capture_output=True, timeout=60)
    record.update(command=command, status=result.returncode, elapsed_s=monotonic() - started,
                  input_sha256=sha256(stdin).hexdigest(), stdout_size=len(result.stdout),
                  stdout_sha256=sha256(result.stdout).hexdigest(), stderr=result.stderr.decode(errors="replace"))
    if result.returncode or result.stderr:
        raise GateError(f"{work.name} {command[-1]} exited {result.returncode}, stderr {record['stderr']!r}")
    return result.stdout


def backend_run(binaries, prefix, work, payload, host_gzip, record):
    work.mkdir()
    record.update(outcome="fail", example={}, compress={}, decompress={}, host_gzip={})
    example = observe([*prefix, binaries["example"].resolve()], work, b"", record["example"])
    if example != EXAMPLE_OUTPUT:
        raise GateError(f"{work.name} upstream example output differs")
    if gzip.decompress((work / "foo.gz").read_bytes()) != b"hello, hello!\x00":
        raise GateError(f"{work.name} upstream example file is not the expected gzip member")
    tool = [*prefix, binaries["minigzip"].resolve()]
    encoded = observe([*tool, "-c"], work, payload, record["compress"])
    if gzip.decompress(encoded) != payload:
        raise GateError(f"{work.name} minigzip output failed the pinned Python gzip oracle")
    decoded = observe([*tool, "-d", "-c"], work, encoded, record["decompress"])
    if decoded != payload:
        raise GateError(f"{work.name} minigzip round trip differs")
    decoded = observe([*tool, "-d", "-c"], work, host_gzip, record["host_gzip"])
    if decoded != payload:
        raise GateError(f"{work.name} minigzip could not decode the pinned host gzip stream")
    record.update(outcome="pass", example_gzip_sha256=sha256_file(work / "foo.gz"))
    print(f"PASS zlib {work.name} upstream example and gzip round trip", flush=True)


def main():
    name = "phase6-zlib"
    evidence = {"schema_version": 1, "scope": name, "outcome": "fail", "production_verified": False,
                "version": VERSION, "checks": {},
                "upstream": {"source_sha256": SOURCE_SHA256, "license_sha256": LICENSE_SHA256},
                "limits": ["Pinned upstream example and minigzip, static x86-64 application links."]}
    checks = evidence["checks"]
    try:
        archive = pinned_archive("OPEN_ASSEMBLY_ZLIB_SOURCE", SOURCE_SHA256)
        evidence["toolchain"] = identify_tools("ar", "make", "ranlib", "qemu-x86_64")
        evidence["inputs"] = verify_setup(checks, False, snapshot=phase6_inputs)
        workspace = BUILD / name
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temporary:
            directory = Path(temporary).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            runtime = checks["runtime"] = {"outcome": "fail", "commands": []}
            runtimes = [build_runtime(directory / f"runtime-{i}", runtime["commands"]) for i in (1, 2)]
            if runtimes[0][3] != runtimes[1][3]:
                raise GateError("the two runtime builds differ")
            runtime.update(outcome="pass", artifacts=runtimes[0][3])
            checks["compile"] = compile_records = [{"outcome": "fail", "commands": []} for _ in runtimes]
            sources = [compile_zlib(archive, directory / f"source-{i}", item)
                       for i, item in enumerate(compile_records, 1)]
            if compile_records[0]["artifacts"] != compile_records[1]["artifacts"]:
                raise GateError("the two zlib object and archive builds differ")
            checks["link"] = link_records = [{} for _ in runtimes]
            binaries = [link_zlib(source, rt, directory / f"linked-{i}", item)
                        for i, (source, rt, item) in enumerate(zip(sources, runtimes, link_records, strict=True), 1)]
            if any(link_records[0][key]["executable_sha256"] != link_records[1][key]["executable_sha256"]
                   for key in TARGETS):
                raise GateError("the two static zlib application links differ")

            seed = 0x5A4C4942
            payload = bytes(range(256)) * 1024 + random.Random(seed).randbytes(65536)
            host_gzip = gzip.compress(payload, mtime=0)
            evidence["payload"] = {"bytes": len(payload), "seed": seed, "sha256": sha256(payload).hexdigest(),
                                   "host_gzip_sha256": sha256(host_gzip).hexdigest()}
            checks["backends"] = {}
            for backend, prefix in (("native", []), ("qemu", [shutil.which("qemu-x86_64")]),
                                    ("valgrind", [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                                  "--leak-check=full", "--errors-for-leak-kinds=all"])):
                item = checks["backends"][backend] = {}
                backend_run(binaries[0], prefix, directory / backend, payload, host_gzip, item)
            if len({item["compress"]["stdout_sha256"] for item in checks["backends"].values()}) != 1:
                raise GateError("compressed streams differ across backends")
        if evidence["inputs"] != phase6_inputs():
            raise GateError("inputs changed during zlib verification")
        evidence["outcome"] = "pass"
        print(f"PASS {name}", flush=True)
    except (GateError, SpecError, OSError, ValueError, EOFError, subprocess.SubprocessError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    path = write_evidence(name, evidence)
    print(f"{name} evidence {path}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())

"""Verify the linked loopback HTTP application and its guarded parser."""

from hashlib import sha256
from pathlib import Path
import random
import shutil
import subprocess
import sys
import tempfile
import time

from gate import (BUILD, GateError, checked, identify_tools, nm_symbols, source_policy,
                  verify_setup, write_evidence)
from phase1 import NASM, RUNTIME_LINK, TEST_C_FLAGS, phase1_inputs
from spec import ROOT, SpecError, sha256_file, snapshot_inputs

SUITE = Path("tests/phase10/http")
sys.path.insert(0, str(ROOT / SUITE))
import live
from oracle import PACKET, classify, directed, fuzz_record, request

PARSER = "__al_http_parse"
PACKAGE_DEPENDENCIES = {
    "http_parse": {"http_find_header_end": "U", "http_is_token_byte": "U"},
    "http_find_header_end": {},
    "http_is_token_byte": {},
}
SEED = 0x614d47f9
FUZZ_SECONDS = 60


def inputs():
    bound = phase1_inputs()
    paths = [Path("docs/adr/0013-linux-sockets-readiness.md"),
             Path("docs/adr/0014-loopback-http.md")]
    bound.update(snapshot_inputs(ROOT, paths))
    return dict(sorted(bound.items()))


def build_app(directory, commands):
    app = directory / "apps/httpd"
    checked(commands, ["make", "--no-print-directory", "-j2", f"RUNTIME_BUILD={directory}", app],
            timeout=180)
    startup, archive = directory / "crt1.o", directory / "libopenasm.a"
    app_objects = sorted((directory / "app-obj/httpd").glob("*.o"))
    bridge = directory / "app-obj/httpd/http_parse.o"
    if nm_symbols(commands, bridge, ["-g", "--defined-only"]) != {PARSER: "T"}:
        raise GateError("app parser bridge does not define the exact parser symbol")
    if nm_symbols(commands, bridge, ["-g", "-u"]) != {"http_parse": "U"}:
        raise GateError("app parser bridge does not directly call the package parser")
    package_objects = []
    for symbol, dependencies in PACKAGE_DEPENDENCIES.items():
        obj = directory / "app-obj/http" / f"{symbol}.o"
        if nm_symbols(commands, obj, ["-g", "--defined-only"]) != {symbol: "T"}:
            raise GateError(f"HTTP package object does not define exactly {symbol}")
        if nm_symbols(commands, obj, ["-g", "-u"]) != dependencies:
            raise GateError(f"HTTP package object {symbol} has unexpected dependencies")
        package_objects.append(obj)
    hashes = {path.relative_to(directory).as_posix(): sha256_file(path)
              for path in [startup, archive, app, *app_objects, *package_objects]}
    exports = nm_symbols(commands, app, ["-g", "--defined-only"])
    if any(exports.get(symbol) != "T" for symbol in (PARSER, *PACKAGE_DEPENDENCIES)):
        raise GateError("linked HTTP server lacks the app bridge or exact package parser symbols")
    objects = [bridge, *package_objects]
    return (app, startup, archive, objects), hashes


def build_parser(directory, artifacts, commands, *, stub=False):
    directory.mkdir()
    _, startup, archive, parser_objects = artifacts
    fixture, binary = directory / "parser.o", directory / "parser-probe"
    checked(commands, ["gcc", *TEST_C_FLAGS, "-c", SUITE / "parser.c", "-o", fixture])
    checked(commands, ["tools/elf-audit", "--test-object", fixture])
    if nm_symbols(commands, fixture, ["-g", "-u"]).get(PARSER) != "U":
        raise GateError("parser fixture does not directly call the app parser")
    objects = [fixture, *parser_objects]
    options = []
    expected = PARSER
    if stub:
        source, wrapper = SUITE / "parser_stub.asm", directory / "stub.o"
        checked(commands, ["tools/lint", source])
        checked(commands, [*NASM, "-o", wrapper, source])
        checked(commands, ["tools/elf-audit", "--assembly-object", wrapper])
        expected = f"__wrap_{PARSER}"
        if nm_symbols(commands, wrapper, ["-g", "--defined-only"]) != {expected: "T"}:
            raise GateError("stub fixture does not export exactly the typed parser wrapper")
        options.append(f"--wrap={PARSER}")
        objects.append(wrapper)
    checked(commands, [*RUNTIME_LINK, *options, "-o", binary, startup, *objects, archive])
    checked(commands, ["tools/elf-audit", binary])
    if nm_symbols(commands, binary, ["-g", "--defined-only"]).get(expected) != "T":
        raise GateError(f"direct parser probe lacks {expected}")
    return binary, {path.name: sha256_file(path) for path in sorted(directory.iterdir())}


def packets(cases):
    request_bytes = b"".join(PACKET.pack(len(data)) + data for data, _ in cases)
    expected = b"".join(PACKET.pack(result) for _, result in cases)
    return request_bytes, expected


def parser_run(command, cases, *, allow_stub=False):
    payload, expected = packets(cases)
    result = subprocess.run(list(map(str, command)), input=payload, capture_output=True,
                            cwd=ROOT, env=live.ENVIRONMENT, timeout=30)
    if result.returncode or result.stderr:
        raise GateError(f"parser probe exited {result.returncode} with {result.stderr[:256]!r}")
    if allow_stub:
        if result.stdout != PACKET.pack(0) or result.stdout == expected:
            raise GateError("parser stub did not produce the independently rejected zero result")
    elif result.stdout != expected:
        if len(result.stdout) != len(expected):
            raise GateError(f"parser produced {len(result.stdout)} bytes for {len(cases)} records")
        actual = [value for value, in PACKET.iter_unpack(result.stdout)]
        index = next(i for i, (_, wanted) in enumerate(cases) if wanted != actual[i])
        data, wanted = cases[index]
        raise GateError(f"parser record {index} ({len(data)} bytes, SHA-256 {sha256(data).hexdigest()}) "
                        f"expected {wanted}, observed {actual[index]}. Prefix {data[:160].hex()}")
    return {
        "command": list(map(str, command)), "records": len(cases),
        "input_sha256": sha256(payload).hexdigest(), "expected_sha256": sha256(expected).hexdigest(),
        "output_sha256": sha256(result.stdout).hexdigest(),
    }


def fuzz(binary, known):
    bases = [data for data, _ in known if 3 <= len(data) < 160]
    rng = random.Random(SEED)
    started = time.monotonic()
    digest = {name: sha256() for name in ("input", "expected", "output")}
    batches = records = 0
    while time.monotonic() - started < FUZZ_SECONDS:
        generated = [fuzz_record(rng, bases) for _ in range(256)]
        expected = [(data, classify(data)) for data in generated]
        edge = "right" if batches % 2 else "left"
        try:
            observed = parser_run([binary, edge], expected)
        except GateError as error:
            raise GateError(f"parser fuzz seed {SEED:#x}, batch {batches}: {error}") from error
        for name, aggregate in digest.items():
            aggregate.update(bytes.fromhex(observed[f"{name}_sha256"]))
        batches += 1
        records += len(generated)
    if not records:
        raise GateError("parser fuzz campaign produced no records")
    return {"outcome": "pass", "seed": SEED, "records": records, "batches": batches,
            "elapsed_s": round(time.monotonic() - started, 6),
            **{f"{name}_batch_hashes_sha256": value.hexdigest() for name, value in digest.items()}}


def main():
    name = "phase10-http"
    evidence = {"schema_version": 1, "scope": name, "production_verified": False,
                "outcome": "fail", "checks": {},
                "limits": ["Loopback IPv4 and the published origin-server grammar.",
                           "Directed app I/O and a timed native parser differential campaign."]}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64")
        evidence["inputs"] = verify_setup(checks, False, snapshot=inputs)
        checks["timeout_controls"] = live.timeout_controls(sys.executable)
        workspace = BUILD / name
        workspace.mkdir(parents=True, exist_ok=True)
        backends = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
                    "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99"]}
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as scratch:
            run = Path(scratch).resolve().relative_to(ROOT)
            source_policy(checks, run)
            build = checks["build"] = {"outcome": "fail", "commands": []}
            first, hashes = build_app(run / "app-first", build["commands"])
            second, repeated = build_app(run / "app-second", build["commands"])
            if hashes != repeated:
                raise GateError("isolated HTTP runtime and app builds differ")
            parser, probe_hashes = build_parser(run / "probe-first", first, build["commands"])
            _, repeated_probe = build_parser(run / "probe-second", second, build["commands"])
            if probe_hashes != repeated_probe:
                raise GateError("isolated HTTP parser builds differ")
            stub, stub_hashes = build_parser(run / "stub", first, build["commands"], stub=True)
            build.update(outcome="pass", artifacts=hashes, parser=probe_hashes, stub=stub_hashes)

            vectors = directed()
            checks["parser"] = {}
            checks["live"] = {}
            for backend, prefix in backends.items():
                checks["parser"][backend] = {side: parser_run([*prefix, parser, side], vectors)
                                             for side in ("left", "right")}
                command = list(map(str, [*prefix, first[0]]))
                checks["live"][backend] = {"command": command, "startup": live.startup(command),
                                            "responses": live.server_cases(command)}
                print(f"PASS HTTP {backend}", flush=True)
            checks["stub"] = parser_run([stub, "right"], [(request(), 200)], allow_stub=True)
            checks["fuzz"] = fuzz(parser, vectors)
        if evidence["inputs"] != inputs():
            raise GateError("inputs changed during HTTP verification")
        evidence["outcome"] = "pass"
        print(f"PASS {name}", flush=True)
    except (GateError, SpecError, ValueError, OSError, subprocess.SubprocessError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    path = write_evidence(name, evidence)
    print(f"{name} evidence {path}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())

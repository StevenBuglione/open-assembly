"""Run source-bound independent DNS wire and loopback checks."""

from hashlib import sha256
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from gate import BUILD, GateError, checked, identify_tools, nm_symbols, source_policy, verify_setup, write_evidence
from phase1 import NASM, Case, build_case, build_runtime
from phase6 import phase6_inputs
from spec import ROOT, SpecError, sha256_file, snapshot_inputs

SUITE = Path("tests/phase10/dns")
sys.path.insert(0, str(ROOT / SUITE))
import loopback
from oracle import FRAME, RESULT, SEED, decoded, directed, sampled

WIRE = ("__al_dns_build", "__al_dns_parse")
TRANSPORT = ("__al_dns_query",)
SOURCE = {"dns-wire": ("wire.c", WIRE), "dns-transport": ("transport.c", TRANSPORT)}
ORACLE = ("reference:rfc1035", "reference:rfc7766", "reference:rfc5452")


def inputs():
    bound = phase6_inputs()
    contracts = [Path("docs/adr/0017-dns-forward.md")]
    bound.update(snapshot_inputs(ROOT, contracts))
    return dict(sorted(bound.items()))


def make_case(name):
    file, required = SOURCE[name]
    return Case(name, (SUITE / file,), required, [], {}, 0, "", "", ORACLE,
                ("native", "qemu", "valgrind"), {})


def wire_run(command, records):
    payload = b"".join(item[0] for item in records)
    expected = [item[1] for item in records]
    result = subprocess.run(list(map(str, command)), cwd=ROOT, input=payload, env={"LC_ALL": "C"},
                            capture_output=True, timeout=30)
    if result.returncode or result.stderr:
        raise GateError(f"DNS wire probe exited {result.returncode} with {result.stderr[:256]!r}")
    seen = decoded(result.stdout, records)
    if seen != expected:
        index = next(i for i, (left, right) in enumerate(zip(seen, expected, strict=True)) if left != right)
        packet = records[index][0]
        raise GateError(f"DNS record {index} ({len(packet)} bytes, SHA-256 {sha256(packet).hexdigest()}) "
                        f"expected {expected[index]!r}, observed {seen[index]!r}, prefix {packet[:192].hex()}")
    normalized = b"".join(RESULT.pack(status, len(data)) + data for status, data in seen)
    return {"outcome": "pass", "records": len(records), "input_sha256": sha256(payload).hexdigest(),
            "normalized_output_sha256": sha256(normalized).hexdigest()}


def stub_control(symbol, directory, runtime, vector, record):
    directory.mkdir()
    source, obj = directory / "stub.asm", directory / "stub.o"
    wrapper = f"__wrap_{symbol}"
    source.write_text(f"""bits 64
default rel
global {wrapper}:function
section .text
{wrapper}:
    xor eax, eax
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
""")
    log = record["commands"]
    checked(log, ["tools/lint", source])
    checked(log, [*NASM, "-o", obj, source])
    checked(log, ["tools/elf-audit", "--assembly-object", obj])
    if nm_symbols(log, obj, ["-g", "--defined-only"]) != {wrapper: "T"}:
        raise GateError(f"{symbol} stub exports the wrong ABI")
    case = make_case("dns-wire" if symbol in WIRE else "dns-transport")
    binary, artifacts = build_case(case, directory / "linked", runtime, log, (symbol, obj))
    command = [binary, "right"] if symbol in WIRE else [binary, "9", "A"]
    payload = vector[0] if symbol in WIRE else b""
    result = subprocess.run(list(map(str, command)), cwd=ROOT, input=payload, env={},
                            capture_output=True, timeout=5)
    expected = (0, RESULT.pack(0, 0), b"") if symbol == WIRE[0] else (92, b"", b"")
    if (result.returncode, result.stdout, result.stderr) != expected:
        raise GateError(f"{symbol} stub did not produce the expected fixture rejection")
    record.update(outcome="pass", artifact_sha256=sha256_file(obj), source_sha256=sha256_file(source),
                  artifacts=artifacts, status=result.returncode, stdout_hex=result.stdout.hex())


def main():
    name = "phase10-dns"
    evidence = {"schema_version": 1, "scope": name, "outcome": "fail", "production_verified": False,
                "checks": {}, "limits": ["Direct private wire ABI and IPv4 loopback transport.",
                                         "Directed and seeded packet samples."]}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64")
        evidence["inputs"] = verify_setup(checks, False, snapshot=inputs)
        workspace = BUILD / name
        workspace.mkdir(parents=True, exist_ok=True)
        backends = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
                    "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                 "--leak-check=full", "--errors-for-leak-kinds=all"]}
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as scratch:
            directory = Path(scratch).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            build = checks["runtime"] = {"outcome": "fail", "commands": []}
            runtimes = [build_runtime(directory / f"runtime-{i}", build["commands"]) for i in (1, 2)]
            if runtimes[0][3] != runtimes[1][3]:
                raise GateError("two isolated DNS runtime artifacts differ")
            build.update(outcome="pass", artifacts=runtimes[0][3])
            checks["fixtures"] = {}
            binaries = {}
            for name_ in SOURCE:
                fixture = checks["fixtures"][name_] = {"outcome": "fail", "commands": []}
                artifacts = [build_case(make_case(name_), directory / f"{name_}-{i}", runtime, fixture["commands"])
                             for i, runtime in enumerate(runtimes, 1)]
                if artifacts[0][1] != artifacts[1][1]:
                    raise GateError(f"two isolated {name_} probe links differ")
                binaries[name_] = artifacts[0][0]
                fixture.update(outcome="pass", artifacts=artifacts[0][1])

            fixed = directed()
            corpus = fixed + sampled(2048)
            checks["wire"] = {"directed": len(fixed), "seed": SEED, "sampled": len(corpus) - len(fixed),
                              "backends": {}}
            checks["transport"] = {}
            for backend, prefix in backends.items():
                binary = binaries["dns-wire"]
                checks["wire"]["backends"][backend] = {
                    side: wire_run([*prefix, binary, side], corpus) for side in ("left", "right")
                }
                command = list(map(str, [*prefix, binaries["dns-transport"]]))
                checks["transport"][backend] = loopback.run(command)
                print(f"PASS DNS {backend} packet and loopback cases", flush=True)
            checks["wire"]["outcome"] = "pass"
            checks["stubs"] = {}
            for symbol in WIRE + TRANSPORT:
                vector = next(row for row in fixed if FRAME.unpack_from(row[0])[0] == int(symbol == WIRE[1])
                              and (row[1][0] == 0 if symbol == WIRE[1] else row[1][0] > 0))
                record = checks["stubs"][symbol] = {"outcome": "fail", "commands": []}
                stub_control(symbol, directory / f"stub-{symbol}", runtimes[0], vector, record)
        if evidence["inputs"] != inputs():
            raise GateError("inputs changed during DNS verification")
        evidence["outcome"] = "pass"
        print(f"PASS {name}", flush=True)
    except (GateError, SpecError, OSError, ValueError, subprocess.SubprocessError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(name, evidence)
    print(f"{name} evidence {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())

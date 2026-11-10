"""Run independent Linux address snapshot and resolver family-selection checks."""

from collections import Counter
from hashlib import sha256
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from gate import BUILD, GateError, checked, identify_tools, nm_symbols, source_policy, verify_setup, write_evidence
from phase1 import NASM, Case, build_case, build_runtime, generate_stub
from phase6 import phase6_inputs
from spec import ROOT, SpecError, load_project, sha256_file, snapshot_inputs

SUITE = Path("tests/phase10/addrconfig")
sys.path.insert(0, str(ROOT / SUITE))
from oracle import RESULT, SEED, directed, sampled

SCOPE = "phase10-addrconfig"
PARSE = "__al_gai_addrconfig_parse"
SNAPSHOT = "__al_gai_addrconfig"
WRAPS = (SNAPSHOT, "__al_dns_query", "fopen")
REQUIRED = {"wire": (PARSE,), "public": ("getaddrinfo",), "real": (SNAPSHOT, "getaddrinfo")}


def inputs():
    paths = [Path("docs/adr/0038-address-configuration.md"), Path("docs/adr/0017-dns-forward.md")]
    return dict(sorted((phase6_inputs() | snapshot_inputs(ROOT, paths)).items()))


def case(mode):
    return Case(f"addrconfig-{mode}", (SUITE / f"{mode}.c",), REQUIRED[mode], [], {}, 0, "", "",
                ("reference:linux-netlink", "reference:rfc3493"), ("native", "qemu", "valgrind"), {})


def observe(command, payload=b""):
    return subprocess.run(list(map(str, command)), cwd=ROOT, input=payload, env={"LC_ALL": "C"},
                          capture_output=True, timeout=20)


def wire_results(command, rows):
    packets = b"".join(row[0] for row in rows)
    wanted = b"".join(row[1] for row in rows)
    result = observe(command, packets)
    if result.returncode or result.stderr or len(result.stdout) != len(wanted):
        raise GateError(f"address decoder exited {result.returncode}, output length {len(result.stdout)}, "
                        f"stderr {result.stderr[:200]!r}")
    if result.stdout != wanted:
        expected = list(RESULT.iter_unpack(wanted))
        actual = list(RESULT.iter_unpack(result.stdout))
        index = next(i for i, (left, right) in enumerate(zip(actual, expected, strict=True)) if left != right)
        raise GateError(f"address decoder {rows[index][2]} row {index} expected {expected[index]} "
                        f"observed {actual[index]}, packet {rows[index][0][:96].hex()}")
    return {"outcome": "pass", "records": len(rows), "input_sha256": sha256(packets).hexdigest(),
            "output_sha256": sha256(result.stdout).hexdigest()}


def private_stub(directory, log):
    wrapper = f"__wrap_{PARSE}"
    source, obj = directory / "zero.asm", directory / "zero.o"
    source.write_text(f"""bits 64
default rel
global {wrapper}:function
section .text
{wrapper}:
    xor eax, eax
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
""")
    checked(log, ["tools/lint", source])
    checked(log, [*NASM, "-o", obj, source])
    checked(log, ["tools/elf-audit", "--assembly-object", obj])
    if nm_symbols(log, obj, ["-g", "--defined-only"]) != {wrapper: "T"}:
        raise GateError("address parser stub has unexpected exports")
    return obj, sha256_file(source)


def controls(directory, runtime, row):
    directory.mkdir()
    parse = directory / "parse"
    parse.mkdir()
    log = []
    obj, source = private_stub(parse, log)
    binary, artifacts = build_case(case("wire"), parse / "linked", runtime, log, (PARSE, obj))
    result = observe([binary, "right"], row[0])
    if (result.returncode, result.stdout, result.stderr) != (0, RESULT.pack(0, 0), b""):
        raise GateError("private address parser stub did not leave the IPv4 mask unchanged")
    records = {PARSE: {"outcome": "pass", "commands": log, "artifacts": artifacts, "source_sha256": source}}
    public = directory / "public"
    public.mkdir()
    log = []
    spec = load_project().functions["getaddrinfo"]
    obj, source = generate_stub(spec, public, log)
    binary, artifacts = build_case(case("real"), public / "linked", runtime, log, ("getaddrinfo", obj))
    result = observe([binary])
    if (result.returncode, result.stdout, result.stderr) != (12, b"", b""):
        raise GateError("public resolver stub did not reject loopback-only family filtering")
    records[spec.name] = {"outcome": "pass", "commands": log, "artifacts": artifacts,
                          "source_sha256": source, "status": result.returncode}
    return records


def main():
    evidence = {"schema_version": 1, "scope": SCOPE, "outcome": "fail", "production_verified": False,
                "limits": ["Actual snapshot uses the pinned loopback-only network namespace.",
                           "Injected snapshots and DNS answers check public family selection."], "checks": {}}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64")
        evidence["inputs"] = verify_setup(checks, False, snapshot=inputs)
        with tempfile.TemporaryDirectory(dir=BUILD, prefix="addrconfig-") as work:
            directory = Path(work).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            log = []
            builds = [build_runtime(directory / f"runtime-{i}", log) for i in range(2)]
            if builds[0][3] != builds[1][3]:
                raise GateError("isolated address-config runtime builds differ")
            checks["runtime"] = {"outcome": "pass", "commands": log, "artifacts": builds[0][3]}
            binaries = {}
            fixtures = checks["fixtures"] = {}
            for mode in REQUIRED:
                log = []
                wraps = WRAPS if mode == "public" else ()
                probes = [build_case(case(mode), directory / f"{mode}-{i}", runtime, log, link_wraps=wraps)
                          for i, runtime in enumerate(builds)]
                if probes[0][1] != probes[1][1]:
                    raise GateError(f"isolated {mode} address-config probes differ")
                binaries[mode], artifacts = probes[0]
                fixtures[mode] = {"outcome": "pass", "commands": log, "artifacts": artifacts}

            rows = directed() + sampled(1024)
            checks["wire"] = {"seed": SEED, "strata": dict(Counter(row[2] for row in rows)), "backends": {}}
            checks["selection"] = {}
            backends = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
                        "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                     "--leak-check=full", "--errors-for-leak-kinds=all"]}
            for backend, prefix in backends.items():
                checks["wire"]["backends"][backend] = {
                    edge: wire_results([*prefix, binaries["wire"], edge], rows) for edge in ("left", "right")
                }
                checks["selection"][backend] = selection = {}
                for mode in ("real", "public"):
                    command = [*prefix, binaries[mode]]
                    result = observe(command)
                    selection[mode] = {"command": list(map(str, command)), "status": result.returncode,
                                       "stdout": result.stdout.decode(errors="replace"),
                                       "stderr": result.stderr.decode(errors="replace")}
                    if result.returncode or result.stdout or result.stderr:
                        raise GateError(f"{mode} {backend} address-config check exited {result.returncode}: "
                                        f"{result.stderr[:200]!r}")
                print(f"PASS {SCOPE} {backend} wire and public family selection", flush=True)
            checks["wire"]["outcome"] = "pass"
            checks["stubs"] = controls(directory / "stubs", builds[0], rows[0])
        if evidence["inputs"] != inputs():
            raise GateError("address-config inputs changed during verification")
        evidence["outcome"] = "pass"
    except (GateError, SpecError, OSError, ValueError, subprocess.SubprocessError) as error:
        evidence["error"] = str(error)
        print(f"{SCOPE}: {error}", file=sys.stderr, flush=True)
    report = write_evidence(SCOPE, evidence)
    print(f"{evidence['outcome'].upper()} {SCOPE}, evidence {report}", flush=True)
    return int(evidence["outcome"] != "pass")


if __name__ == "__main__":
    raise SystemExit(main())

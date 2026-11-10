"""Verify configured DNS failover and options against independent loopback peers."""

import argparse
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from gate import BUILD, GateError, checked, identify_tools, nm_symbols, source_policy, verify_setup, write_evidence
from phase1 import NASM, Case, build_case, build_runtime, generate_stub
from phase6 import phase6_inputs
from spec import ROOT, SpecError, load_project, sha256_file, snapshot_inputs

SUITE = Path("tests/phase10/resolver")
sys.path.insert(0, str(ROOT / SUITE))
from resolver_oracle import run

WRAPS = ("fopen", "__al_dns_config", "__al_dns_server")
TIMEOUT = "__al_dns_query_timeout"
CASE = Case("resolver-policy", (SUITE / "policy.c",),
            ("__al_dns_config", "getaddrinfo", "getnameinfo", TIMEOUT), [], {}, 0, "", "",
            ("reference:rfc1035", "reference:linux-resolver-policy"), ("native", "qemu", "valgrind"), {})


def inputs():
    contracts = [Path("docs/adr") / name for name in ("0017-dns-forward.md", "0039-resolver-search.md",
                                                      "0041-resolver-failover.md", "0042-resolver-options.md")]
    return dict(sorted((phase6_inputs() | snapshot_inputs(ROOT, contracts)).items()))


def timeout_stub(directory, log):
    source, obj = directory / "timeout.asm", directory / "timeout.o"
    wrapper = f"__wrap_{TIMEOUT}"
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
        raise GateError("the private timeout stub has unexpected exports")
    return obj, sha256_file(source)


def stub(suite, directory, runtime, record):
    directory.mkdir()
    log = record["commands"] = []
    if suite == "options":
        name, args, status = TIMEOUT, ["invalid-budget", "9"], 41
        obj, source = timeout_stub(directory, log)
    else:
        name, status = "getaddrinfo", 21
        config, hosts = directory / "resolv.conf", directory / "hosts"
        config.write_text("nameserver 127.0.0.1\n", encoding="ascii")
        hosts.write_text("", encoding="ascii")
        args = ["forward", config, hosts, "9", "2", "0", "1"]
        obj, source = generate_stub(load_project().functions[name], directory, log)
    binary, artifacts = build_case(CASE, directory / "probe", runtime, log, (name, obj), link_wraps=WRAPS)
    result = subprocess.run(list(map(str, [binary, *args])), cwd=ROOT, env={"LC_ALL": "C"},
                            capture_output=True, timeout=5)
    if (result.returncode, result.stdout, result.stderr) != (status, b"", b""):
        raise GateError(f"{name} stub did not produce the expected rejection")
    record.update(outcome="pass", symbol=name, source_sha256=source, artifacts=artifacts, status=status)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("suite", choices=("failover", "options"))
    suite = parser.parse_args().suite
    name = f"phase10-dns-{suite}"
    checks = {}
    report = {"schema_version": 1, "scope": name, "outcome": "fail",
              "production_verified": False, "checks": checks}
    try:
        report["toolchain"] = identify_tools("ar", "make", "qemu-x86_64")
        report["inputs"] = verify_setup(checks, False, snapshot=inputs)
        with tempfile.TemporaryDirectory(dir=BUILD, prefix=f"resolver-{suite}-") as scratch:
            directory = Path(scratch).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            log = []
            runtimes = [build_runtime(directory / f"runtime-{i}", log) for i in range(2)]
            probes = [build_case(CASE, directory / f"fixture-{i}", runtime, log, link_wraps=WRAPS)
                      for i, runtime in enumerate(runtimes)]
            if runtimes[0][3] != runtimes[1][3] or probes[0][1] != probes[1][1]:
                raise GateError("two isolated resolver builds differ")
            checks["build"] = {"outcome": "pass", "commands": log, "runtime": runtimes[0][3],
                               "artifacts": probes[0][1]}
            backends = {"native": [], "qemu": [shutil.which("qemu-x86_64")],
                        "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                                     "--leak-check=full", "--errors-for-leak-kinds=all"]}
            checks["backends"] = {}
            for backend, prefix in backends.items():
                command = list(map(str, [*prefix, probes[0][0]]))
                checks["backends"][backend] = run(suite, command, directory / backend)
                print(f"PASS {name} {backend}", flush=True)
            checks["stub"] = {"outcome": "fail"}
            stub(suite, directory / "stub", runtimes[0], checks["stub"])
        if inputs() != report["inputs"]:
            raise GateError("resolver inputs changed during independent verification")
        report["outcome"] = "pass"
    except (GateError, SpecError, OSError, ValueError, subprocess.SubprocessError) as error:
        report["error"] = str(error)
        print(f"{name}: {error}", file=sys.stderr, flush=True)
    path = write_evidence(name, report)
    print(f"{report['outcome'].upper()} {name} evidence {path}", flush=True)
    return int(report["outcome"] != "pass")


if __name__ == "__main__":
    raise SystemExit(main())

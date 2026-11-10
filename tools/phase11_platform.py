"""Exercise real Linux seccomp and a separately booted pinned older kernel."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

from gate import BUILD, GateError, identify_tools, run, verify_setup, write_evidence
from phase1 import Case, build_case, build_runtime, load_manifest
from phase4 import parse_probe
from phase6 import phase6_inputs
from spec import ROOT, read_toml, sha256_file, snapshot_inputs

SUITE = Path("tests/phase11/platform")
OLD_RELEASE = "4.19.0-27-amd64"
OLD_KERNEL_SHA256 = "71947e2c7102ceb224b04b910c5761bc9f2a7986c2c8d868b5553dc8fef57747"
BOOT_CASES = (
    (Path("tests/phase6"), ("directory-readdir", "directory-refill")),
    (Path("tests/phase6/signal"), ("signal-sigaction", "signal-sigsuspend")),
    (Path("tests/phase6/spawn"), ("spawn-success", "spawn-failures")),
    (Path("tests/phase10/endpoints"), ("net-sockets-tcp", "net-readiness-poll", "net-readiness-epoll")),
    (Path("tests/phase10/terminal"), ("terminal-tcsetattr", "terminal-tcgetsid", "terminal-errors")),
)
LOOPBACK_CASE = "loopback-socket-readiness"
SECCOMP_CASES = {
    "remap-enosys": "PASS seccomp remap ENOSYS preserves and moves allocation\n",
    "remap-eperm": "PASS seccomp remap EPERM preserves and moves allocation\n",
    "vdso-eperm": "PASS seccomp vDSO EPERM uses raw clock and publishes EACCES\n",
    "append-enosys": "PASS seccomp pwritev2 ENOSYS leaves append file unchanged\n",
}


class PlatformUnavailable(Exception):
    pass


def inputs():
    documents = [Path("docs/cookbook/platform-matrix.md"), Path("docs/adr/0022-vdso-realtime.md"),
                 Path("docs/adr/0036-direct-allocation-remap.md")]
    return dict(sorted((phase6_inputs() | snapshot_inputs(ROOT, documents)).items()))


def platform_case(name, filename, required):
    return Case(name, (SUITE / filename,), required, [], {}, 0, "", "", ("reference:linux-platform",),
                ("native",), {})


def seccomp(directory, runtime, report):
    case = platform_case("seccomp", "seccomp.c", ("__al_syscall", "malloc", "realloc", "free",
                         "pwrite", "pread", "time", "write", "fcntl"))
    binary, artifacts = build_case(case, directory / "seccomp", runtime, report["commands"])
    report["artifacts"][case.name] = artifacts
    report["kernel_release"] = os.uname().release
    for name, stdout in SECCOMP_CASES.items():
        result = run([binary, name], environment={})
        report["observations"][name] = result
        if result["returncode"] in {10, 11}:
            raise PlatformUnavailable(f"{name}: unprivileged no-new-privileges or seccomp installation unavailable")
        if (result["returncode"], result["stdout"], result["stderr"]) != (0, stdout, ""):
            raise GateError(f"{name}: unexpected kernel probe result {result['returncode']}")
        print(stdout.strip(), flush=True)


def append_entry(cpio, inode, name, mode, data=b"", device=(0, 0)):
    encoded = name.encode("ascii") + b"\x00"
    # newc uses hexadecimal ASCII fields and pads names and data to four bytes.
    fields = (inode, mode, 0, 0, 1, 0, len(data), 0, 0, *device, len(encoded), 0)
    cpio.extend(("070701" + "".join(f"{field:08x}" for field in fields)).encode("ascii"))
    cpio.extend(encoded)
    cpio.extend(b"\x00" * (-len(cpio) % 4))
    cpio.extend(data)
    cpio.extend(b"\x00" * (-len(cpio) % 4))


def build_initramfs(directory, init, hellos, probes):
    cpio = bytearray()
    entries = [("dev", 0o040755, b"", (0, 0)), ("dev/console", 0o020600, b"", (5, 1)),
               ("dev/null", 0o020666, b"", (1, 3)), ("dev/pts", 0o040755, b"", (0, 0)),
               ("dev/ptmx", 0o120777, b"pts/ptmx", (0, 0)), ("cases", 0o040755, b"", (0, 0)),
               ("probes", 0o040755, b"", (0, 0)), ("init", 0o100755, init.read_bytes(), (0, 0))]
    entries.extend((name, 0o100755, path.read_bytes(), (0, 0)) for name, path in hellos.items())
    entries.extend((f"probes/{name}", 0o100755, path.read_bytes(), (0, 0)) for name, path in probes.items())
    for inode, (name, mode, data, device) in enumerate(entries, 1):
        append_entry(cpio, inode, name, mode, data, device)
    append_entry(cpio, len(entries) + 1, "TRAILER!!!", 0)
    archive = directory / "initramfs.cpio"
    archive.write_bytes(cpio)
    return archive


def boot_cases():
    cases = []
    for suite, names in BOOT_CASES:
        manifest = suite / "manifest.toml"
        tables = {row["name"]: row for row in read_toml(manifest)["case"]}
        for name in names:
            probe = parse_probe(tables[name], f"{manifest}: {name}", suite=suite, programs=(), fault_wrappers={})
            if (probe.case.status or probe.stdout or probe.stderr or probe.input_bytes or probe.files or probe.wraps
                    or "native" not in probe.case.backends):
                raise GateError(f"{name}: boot probes require direct silent successful cases")
            cases.append(probe.case)
    cases.append(platform_case(LOOPBACK_CASE, "loopback.c", (
        "socket", "bind", "listen", "getsockname", "connect", "accept4", "send", "recv", "shutdown",
        "poll", "epoll_create1", "epoll_ctl", "epoll_wait", "close",
    )))
    return cases


def write_boot_header(cases, directory):
    def values(strings):
        if any(re.fullmatch(r"[ -~]*", value) is None for value in strings):
            raise GateError("boot probe metadata must be printable ASCII")
        return ", ".join([*(json.dumps(value) for value in strings), "NULL"])

    rows = ["static const struct platform_case platform_cases[] = {"]
    for case in cases:
        args = values([f"/probes/{case.name}", *case.args])
        env = values([f"{key}={value}" for key, value in sorted(case.env.items())])
        rows.append(f'    {{ "{case.name}", (char *const[]){{ {args} }}, (char *const[]){{ {env} }} }},')
    header = directory / "platform-cases.h"
    header.write_text("\n".join([*rows, "};", ""]), encoding="ascii")
    return header


def verify_boot_cases(stdout, expected):
    # Every case expects both child streams to be empty. A successful child
    # therefore produces exactly two consecutive console lines from PID 1.
    lines = stdout.splitlines()
    markers = [(index, row) for index, row in enumerate(lines)
               if row.startswith(("BEGIN platform case ", "END platform case "))]
    if [row for _, row in markers] != [f"{edge} platform case {name}"
                                      for name in expected for edge in ("BEGIN", "END")]:
        raise GateError("guest case markers are missing, duplicated, or out of order")
    if any(markers[index + 1][0] != markers[index][0] + 1 for index in range(0, len(markers), 2)):
        raise GateError("a booted guest case produced unexpected output")


def verify_kernel_result(result, release, hello_outputs, *, guest):
    stdout = result["stdout"]
    if result["returncode"] or result["stderr"] or "FAIL platform" in stdout:
        raise GateError(f"{'guest' if guest else 'native'} kernel probe failed (status {result['returncode']})")
    rows = stdout.splitlines()
    if guest:
        rows = [row for row in rows if row.startswith(("PLATFORM ", "PASS platform ", "Hello "))]
    if len(rows) != 8:
        raise GateError("kernel probe did not emit all expected observations")
    identity = re.fullmatch(rf"PLATFORM linux {re.escape(release)} x86_64 clone3=(-?\d+)", rows[0])
    if identity is None or (guest and int(identity[1]) != -38):
        raise GateError("unexpected kernel release or missing clone3 ENOSYS observation")
    if rows[1:6] != [*hello_outputs, "PASS platform startup-c-and-asm",
                     "PASS platform tls-thread-clone", "PASS platform clock-and-allocation"]:
        raise GateError("startup, worker TLS, clock or allocation observation differs")
    valid_append = {"PASS platform append-unsupported"}
    if not guest:
        valid_append.add("PASS platform append-offset")
    if rows[6] not in valid_append or rows[7] != "PASS platform complete":
        raise GateError("append behavior or guest completion differs")
    return {"kernel_release": release, "clone3_raw": int(identity[1]), "append": rows[6].split()[-1]}


def old_kernel(directory, runtime, report, kernel):
    cases, _ = load_manifest()
    cases = {case.name: case for case in cases}
    hellos, expected = {}, []
    for name in ("hello-asm", "hello-c"):
        case = cases[name]
        binary, artifacts = build_case(case, directory / name, runtime, report["commands"])
        hellos[name] = binary
        expected.append(case.stdout.removesuffix("\n"))
        report["artifacts"][name] = artifacts
    cases = boot_cases()
    probes = {}
    records = report["kernel_cases"] = {}
    for probe in cases:
        binary, artifacts = build_case(probe, directory / probe.name, runtime, report["commands"])
        probes[probe.name] = binary
        records[probe.name] = {"artifacts": artifacts, "oracle": probe.oracle,
                               "arguments": probe.args, "environment": probe.env}
    header = write_boot_header(cases, directory)
    report["artifacts"]["guest_manifest_header_sha256"] = sha256_file(header)
    case = platform_case("kernel-probe", "kernel.c", ("__al_syscall", "pthread_create", "pthread_join",
                         "fork", "execve", "waitpid", "clock_gettime", "malloc", "realloc", "free",
                         "pwrite", "pread", "fcntl"))
    init, artifacts = build_case(case, directory / "probe", runtime, report["commands"], c_include=(directory,))
    report["artifacts"][case.name] = artifacts
    archive = build_initramfs(directory, init, hellos, probes)
    report["artifacts"].update(kernel_sha256=sha256_file(kernel), initramfs_sha256=sha256_file(archive))

    native = run([init, *hellos.values()], environment={})
    report["observations"]["native"] = native
    native.update(verify_kernel_result(native, os.uname().release, expected, guest=False))
    print(f"PASS native Linux {native['kernel_release']} {native['append']}", flush=True)
    for probe in cases:
        work = directory / f"{probe.name}-native"
        work.mkdir()
        result = run([probes[probe.name].resolve(), *probe.args], environment=probe.env,
                     cwd=work.resolve(), timeout=30)
        records[probe.name]["native"] = result
        if (result["returncode"], result["stdout"], result["stderr"]) != (0, "", ""):
            raise GateError(f"{probe.name}: native fixture failed at status {result['returncode']}")
        print(f"PASS native Linux {probe.name}", flush=True)

    guest = run(["qemu-system-x86_64", "-machine", "pc,accel=tcg", "-cpu", "qemu64", "-smp", "2",
                 "-m", "192M", "-nodefaults", "-display", "none", "-serial", "stdio", "-monitor", "none",
                 "-nic", "none", "-no-reboot", "-kernel", kernel, "-initrd", archive,
                 "-append", "console=ttyS0,115200 quiet panic=-1 rdinit=/init"], timeout=120)
    report["observations"]["guest"] = guest
    guest.update(verify_kernel_result(guest, OLD_RELEASE, expected, guest=True))
    verify_boot_cases(guest["stdout"], probes)
    for name in probes:
        records[name]["guest"] = {"returncode": 0, "stdout": "", "stderr": ""}
        print(f"PASS booted Linux {name}", flush=True)
    print(f"PASS booted Linux {guest['kernel_release']} clone3={guest['clone3_raw']} {guest['append']}", flush=True)


def kernel_image():
    if not shutil.which("qemu-system-x86_64") or not os.environ.get("OPEN_ASSEMBLY_OLD_KERNEL"):
        raise PlatformUnavailable("use tools/container --old-kernel for the pinned QEMU system and guest kernel")
    kernel = Path(os.environ["OPEN_ASSEMBLY_OLD_KERNEL"])
    if not kernel.is_file():
        raise PlatformUnavailable("pinned guest kernel is unavailable")
    if sha256_file(kernel) != OLD_KERNEL_SHA256:
        raise GateError("guest kernel differs from its pinned byte hash")
    return kernel


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("scope", choices=("seccomp", "old-kernel"))
    args = parser.parse_args()
    name = f"phase11-{args.scope}"
    report = {"schema_version": 1, "scope": name, "outcome": "fail", "production_verified": False,
              "commands": [], "checks": {}, "artifacts": {}, "observations": {}}
    try:
        kernel = kernel_image() if args.scope == "old-kernel" else None
        report["toolchain"] = identify_tools("make", "ar", *(("qemu-system-x86_64",) if kernel else ()))
        report["inputs"] = verify_setup(report["checks"], False, snapshot=inputs)
        with tempfile.TemporaryDirectory(dir=BUILD, prefix=f"platform-{args.scope}-") as temp:
            directory = Path(temp).resolve().relative_to(ROOT)
            runtime = build_runtime(directory / "runtime", report["commands"])
            report["artifacts"]["runtime"] = runtime[3]
            if kernel:
                old_kernel(directory, runtime, report, kernel)
            else:
                seccomp(directory, runtime, report)
        if inputs() != report["inputs"]:
            raise GateError("platform inputs changed during the run")
        report["outcome"] = "pass"
    except PlatformUnavailable as error:
        report.update(outcome="incomplete", reason=str(error))
    except (GateError, OSError, ValueError) as error:
        report.update(outcome="fail", reason=str(error))
    path = write_evidence(name, report)
    print(f"{report['outcome'].upper()} {name}, evidence at {path}")
    if "reason" in report:
        print(report["reason"], file=sys.stderr)
    return int(report["outcome"] != "pass")


if __name__ == "__main__":
    raise SystemExit(main())

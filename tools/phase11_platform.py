"""Exercise real Linux seccomp and a separately booted pinned older kernel."""

import argparse
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

from gate import BUILD, GateError, identify_tools, run, verify_setup, write_evidence
from phase1 import Case, build_case, build_runtime, load_manifest
from phase6 import phase6_inputs
from spec import ROOT, sha256_file, snapshot_inputs

SUITE = Path("tests/phase11/platform")
OLD_RELEASE = "4.19.0-27-amd64"
OLD_KERNEL_SHA256 = "71947e2c7102ceb224b04b910c5761bc9f2a7986c2c8d868b5553dc8fef57747"
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


def build_initramfs(directory, init, hellos):
    cpio = bytearray()
    append_entry(cpio, 1, "dev", 0o040755)
    append_entry(cpio, 2, "dev/console", 0o020600, device=(5, 1))
    append_entry(cpio, 3, "init", 0o100755, init.read_bytes())
    for inode, (name, path) in enumerate(hellos.items(), 4):
        append_entry(cpio, inode, name, 0o100755, path.read_bytes())
    append_entry(cpio, len(hellos) + 4, "TRAILER!!!", 0)
    archive = directory / "initramfs.cpio"
    archive.write_bytes(cpio)
    return archive


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
    case = platform_case("kernel-probe", "kernel.c", ("__al_syscall", "pthread_create", "pthread_join",
                         "fork", "execve", "waitpid", "clock_gettime", "malloc", "realloc", "free",
                         "pwrite", "pread", "fcntl"))
    init, artifacts = build_case(case, directory / "probe", runtime, report["commands"])
    report["artifacts"][case.name] = artifacts
    archive = build_initramfs(directory, init, hellos)
    report["artifacts"].update(kernel_sha256=sha256_file(kernel), initramfs_sha256=sha256_file(archive))

    native = run([init, *hellos.values()], environment={})
    report["observations"]["native"] = native
    native.update(verify_kernel_result(native, os.uname().release, expected, guest=False))
    print(f"PASS native Linux {native['kernel_release']} {native['append']}", flush=True)

    guest = run(["qemu-system-x86_64", "-machine", "pc,accel=tcg", "-cpu", "qemu64", "-smp", "2",
                 "-m", "192M", "-nodefaults", "-display", "none", "-serial", "stdio", "-monitor", "none",
                 "-nic", "none", "-no-reboot", "-kernel", kernel, "-initrd", archive,
                 "-append", "console=ttyS0,115200 quiet panic=-1 rdinit=/init"], timeout=120)
    report["observations"]["guest"] = guest
    guest.update(verify_kernel_result(guest, OLD_RELEASE, expected, guest=True))
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

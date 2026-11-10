"""Verify the optional self-relocating static PIE and its default control."""

import os
from pathlib import Path
import select
import shutil
import subprocess
import sys
import tempfile

from gate import BUILD, GateError, checked, identify_tools, nm_symbols, run, source_policy, verify_setup, write_evidence
from phase1 import NASM, RUNTIME_LINK, TEST_C_FLAGS, build_runtime, phase1_inputs
from pie_elf import DYNAMIC, EHDR, PHDR, RELA, PT_DYNAMIC, PT_TLS
from spec import ROOT, SpecError, sha256_file, snapshot_inputs

SCOPE = "phase11-static-pie"
FIXTURES = Path("tests/phase11/pie")
CONTRACT = Path("docs/adr/0028-static-pie.md")
STATIC_PIE_LINK = (*[flag for flag in RUNTIME_LINK[:-2] if flag != "-no-pie"],
                   "-pie", "--no-dynamic-linker", "-e", "__al_pie_entry",
                   "-z", "separate-code", "-z", "relro", "-z", "now", "-z", "text")
POINTER_OUTPUT = "static-pie pointers ok\n"
REJECT_OUTPUT = "open-assembly: invalid static PIE relocation\n"
DATA_SLOTS = ("oa_pie_relro_pointer", "oa_pie_data_pointer")


def input_snapshot():
    bound = phase1_inputs()
    bound.update(snapshot_inputs(ROOT, [CONTRACT, *sorted(FIXTURES.rglob("*.*"))]))
    return dict(sorted(bound.items()))


def candidate_runtime(directory, log):
    startup, archive, _, hashes = build_runtime(directory, log)
    pie_startup = directory / "crt1-pie.o"
    checked(log, ["make", "--no-print-directory", f"RUNTIME_BUILD={directory}", pie_startup])
    checked(log, ["tools/elf-audit", "--assembly-object", pie_startup])
    pie_symbols = nm_symbols(log, pie_startup, ["-g", "--defined-only"])
    if {name for name, kind in pie_symbols.items() if kind == "T"} != {"_start", "__al_pie_entry"}:
        raise GateError("static PIE CRT object must contain both entry points")
    hashes[pie_startup.name] = sha256_file(pie_startup)
    return startup, pie_startup, archive, hashes


def link_case(name, directory, runtime, log, *, pie, plain=False):
    startup, pie_startup, archive, _ = runtime
    directory.mkdir()
    obj, binary, link_map = directory / f"{name}.o", directory / name, directory / f"{name}.map"
    if plain:
        checked(log, [*NASM, "-o", obj, FIXTURES / "plain.asm"])
        checked(log, ["tools/elf-audit", "--assembly-object", obj])
    else:
        flags = [flag for flag in TEST_C_FLAGS if not pie or flag != "-fno-pie"]
        if pie:
            flags.extend(("-fPIE", "-ftls-model=local-exec"))
        checked(log, ["gcc", *flags, "-c", FIXTURES / "pointers.c", "-o", obj])
        checked(log, ["tools/elf-audit", "--test-object", obj])
    entry = pie_startup if pie else startup
    checked(log, [*(STATIC_PIE_LINK if pie else RUNTIME_LINK), f"-Map={link_map}", "--cref",
                  "-o", binary, entry, obj, archive])
    checked(log, ["tools/elf-audit", *(["--static-pie"] if pie else []), binary])

    expected = {"_start": entry, "main": obj, "__al_tls_init": f"{archive}(__al_tls_init.o)"}
    if pie:
        expected.update(__al_pie_entry=entry, __al_pie_relocate=f"{archive}(__al_pie_relocate.o)")
    if not plain:
        expected.update({name: f"{archive}({name}.o)" for name in ("pthread_create", "pthread_join")})
    table = link_map.read_text().partition("Cross Reference Table\n")[2]
    origins = {}
    for line in table.splitlines():
        if line and not line[0].isspace():
            fields = line.split(maxsplit=1)
            if len(fields) == 2 and fields[0] in expected:
                origins.setdefault(*fields)
    if origins != {name: str(origin) for name, origin in expected.items()}:
        raise GateError(f"{name} did not establish startup, archive, and fixture symbol origins")
    symbols = nm_symbols(log, binary, ["-g", "--defined-only"])
    if any(symbols.get(symbol) != "T" for symbol in expected) or (
            not pie and {"__al_pie_entry", "__al_pie_relocate"} & symbols.keys()):
        raise GateError(f"{name} has incorrect linked entry or runtime symbols")
    return binary, {"object_sha256": sha256_file(obj), "binary_sha256": sha256_file(binary), "origins": origins}


def elf_records(binary):
    image = binary.read_bytes()
    _, _, _, _, entry, phoff, _, _, _, phsize, phnum, *_ = EHDR.unpack_from(image)
    headers = [(offset, PHDR.unpack_from(image, offset)) for offset in range(phoff, phoff + phsize * phnum, phsize)]
    dynamic = next(ph for _, ph in headers if ph[0] == PT_DYNAMIC)
    offset, size = dynamic[2], dynamic[5]
    tags = dict(DYNAMIC.iter_unpack(image[offset:offset + size]))
    rela = tags.get(7, 0)
    limit = rela + tags.get(8, 0)
    entries = [(offset, *RELA.unpack_from(image, offset)) for offset in range(rela, limit, RELA.size)]
    tls = next(((offset, ph) for offset, ph in headers if ph[0] == PT_TLS), None)
    return image, entry, entries, tls


def slot_symbols(binary, log):
    raw = checked(log, ["nm", "-g", "--defined-only", binary])
    values = {}
    for line in raw.splitlines():
        fields = line.split()
        if len(fields) == 3 and fields[2] in DATA_SLOTS and fields[1] in {"D", "R"}:
            values[fields[2]] = int(fields[0], 16)
    if set(values) != set(DATA_SLOTS):
        raise GateError("PIE pointer fixture is missing the two exported relocation slots")
    return values


def check_observation(command, expected, record):
    result = run(command, timeout=60)
    record.update(result)
    actual = (result["returncode"], result["stdout"], result["stderr"])
    if actual != expected:
        raise GateError(f"unexpected static PIE observation {actual!r} for {command}")
    record["outcome"] = "pass"


def mapped_ranges(pid, binary):
    pathname = str(binary.resolve())
    mappings = []
    for line in Path(f"/proc/{pid}/maps").read_text().splitlines():
        fields = line.split(maxsplit=5)
        if len(fields) != 6 or fields[-1] != pathname:
            continue
        lo, hi = (int(value, 16) for value in fields[0].split("-"))
        mappings.append((lo, hi, fields[1], int(fields[2], 16)))
    return mappings


def observe_aslr(binary, symbols):
    with subprocess.Popen([binary, "pie", "hold"], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE) as child:
        try:
            ready, _, _ = select.select([child.stdout], [], [], 30)
            expected = POINTER_OUTPUT.encode()
            if not ready or os.read(child.stdout.fileno(), len(expected) + 1) != expected:
                raise GateError("PIE fixture did not reach the ASLR observation")
            mappings = mapped_ranges(child.pid, binary)
            bases = [lo for lo, _, mode, offset in mappings if mode == "r--p" and offset == 0]
            if len(bases) != 1 or not bases[0]:
                raise GateError("expected one nonzero executable load bias")
            bias = bases[0]
            permissions = {}
            for name, offset in symbols.items():
                address = bias + offset
                permissions[name] = next((mode for lo, hi, mode, _ in mappings if lo <= address < hi), None)
            if permissions != {DATA_SLOTS[0]: "r--p", DATA_SLOTS[1]: "rw-p"}:
                raise GateError("PIE GNU RELRO or writable data mapping has incorrect permissions")
            out, err = child.communicate(b"q", timeout=30)
            if (child.returncode, out, err) != (0, b"", b""):
                raise GateError("PIE fixture failed to exit after mapping observation")
            return {"bias": hex(bias), "permissions": permissions, "outcome": "pass"}
        finally:
            if child.poll() is None:
                child.kill()
                child.wait()


def controls(binary, plain, directory, qemu, log, record):
    image, entry, relocs, tls = elf_records(binary)
    slots = slot_symbols(binary, log)
    targets = {target for _, target, kind, _ in relocs if kind == 8}
    if (tls is None or not set(slots.values()) <= targets or
            not any(tls[1][3] <= target < tls[1][3] + tls[1][5] for target in targets) or
            elf_records(plain)[2]):
        raise GateError("expected relative relocations in TLS, RELRO and data, and a zero-relocation control")
    record["relocations"] = [{"target": target, "type": kind, "addend": addend}
                             for _, target, kind, addend in relocs]
    record["native_aslr"] = [observe_aslr(binary, slots) for _ in range(2)]
    if len({item["bias"] for item in record["native_aslr"]}) != 2:
        raise GateError("two native static PIE runs had the same load bias")

    offset = relocs[0][0]
    cases = (
        ("relocation-type", offset + 8, 37, "unsupported PIE relocation type"),
        ("text-write", offset, entry & -8, "outside an allowed writable slot"),
        ("invalid-addend", offset + 16, (1 << 64) - 1, "addend is outside the mapped image"),
        ("invalid-tls", tls[0] + 16, 0x7FFFFFF0, "invalid PIE TLS template"),
    )
    rejected = record["rejected"] = {}
    for name, where, value, diagnostic in cases:
        mutated = directory / name
        raw = bytearray(image)
        raw[where:where + 8] = value.to_bytes(8, "little")
        mutated.write_bytes(raw)
        mutated.chmod(0o755)
        audit = run(["tools/elf-audit", "--static-pie", mutated])
        item = rejected[name] = {"outcome": "fail", "sha256": sha256_file(mutated), "audit": audit}
        if audit["returncode"] != 1 or diagnostic not in audit["stderr"]:
            raise GateError(f"static PIE audit failed to identify the {name} defect")
        item["native"], item["qemu"] = {}, {}
        expected = (127, "", REJECT_OUTPUT)
        check_observation([mutated, "pie"], expected, item["native"])
        check_observation([qemu, mutated, "pie"], expected, item["qemu"])
        item["outcome"] = "pass"
        print(f"PASS static PIE rejects {name}", flush=True)


def execute():
    evidence = {"schema_version": 1, "scope": SCOPE, "outcome": "fail", "production_verified": False,
                "checks": {}, "limits": ["GNU ld unpacked RELATIVE relocations only.",
                                         "ASLR and mapping permissions observed on native Linux."]}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64")
        evidence["inputs"] = verify_setup(checks, False, snapshot=input_snapshot)
        workspace = BUILD / SCOPE
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as work:
            directory = Path(work).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            log = checks["commands"] = []
            runtimes = [candidate_runtime(directory / f"runtime-{n}", log) for n in (1, 2)]
            if runtimes[0][3] != runtimes[1][3]:
                raise GateError("two isolated static PIE runtime builds differ")
            checks["runtime"] = runtimes[0][3]
            binaries = {}
            checks["artifacts"] = {}
            for name, pie, plain in (("pointers-pie", True, False), ("pointers-exec", False, False),
                                     ("plain-pie", True, True)):
                builds = [link_case(name, directory / f"{name}-{n}", runtime, log, pie=pie, plain=plain)
                          for n, runtime in enumerate(runtimes, 1)]
                first, second = (item[1] for item in builds)
                if any(first[key] != second[key] for key in ("object_sha256", "binary_sha256")):
                    raise GateError(f"two isolated {name} executables differ")
                binaries[name] = builds[0][0]
                checks["artifacts"][name] = [first, second]
            qemu = shutil.which("qemu-x86_64")
            valgrind = shutil.which("valgrind")
            runners = {"native": (), "qemu": (qemu,), "memcheck": (
                valgrind, "--quiet", "--error-exitcode=99", "--leak-check=full", "--errors-for-leak-kinds=all")}
            checks["runs"] = {}
            for name, binary in binaries.items():
                expected = (0, "" if name == "plain-pie" else POINTER_OUTPUT, "")
                arguments = [] if name == "plain-pie" else ["pie" if name == "pointers-pie" else "exec"]
                observations = checks["runs"][name] = {}
                for backend, runner in runners.items():
                    observations[backend] = {"outcome": "fail"}
                    check_observation([*runner, binary, *arguments], expected, observations[backend])
                    print(f"PASS static PIE {name} {backend}", flush=True)
            controls(binaries["pointers-pie"], binaries["plain-pie"], directory, qemu, log, checks)
        if input_snapshot() != evidence["inputs"]:
            raise GateError("inputs changed during static PIE verification")
        evidence["outcome"] = "pass"
    except (GateError, OSError, SpecError, ValueError, subprocess.SubprocessError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(SCOPE, evidence)
    print(f"static PIE evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute())

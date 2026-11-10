"""Verify the private SIMD memcpy dependency with the Phase 2 oracle."""

import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

from branch_coverage import INSTRUCTION, compile_plugin, describe_branches, read_edges
from gate import BUILD, COMPILE_FLAGS, GateError, checked, identify_tools, nm_symbols, verify_setup, write_evidence
from lint import Violation, parse, verify, verify_optional_memcpy
from phase1 import NASM
from production import (assemble_candidate, build_checks, candidate_symbol, link_checks,
                        phase2_inputs, probe, read_plan, source_paths)
from spec import ROOT, sha256_file

HELPER = "__al_memcpy_bulk"
PLUGIN = Path("tests/tooling/qemu_copy_state.c")
FEATURE_MASK = 0x1C000000
AVX = 1 << 28
PROFILE = (
    ("baseline", "qemu64", False, False, False),
    ("avx-no-os-state", "max,avx=on,xsave=off", True, False, False),
    ("avx", "max", True, True, False),
    ("avx-without-ymm", "max", True, True, True),
)


def copy_object(source, directory, log, *, original=None):
    obj = original
    if obj is None:
        obj = directory / f"{HELPER}.o"
        checked(log, [*NASM, "-o", obj, source])
        checked(log, ["tools/elf-audit", "--assembly-object", obj])
    if (nm_symbols(log, obj, ["-g", "--defined-only"]) != {HELPER: "T"}
            or nm_symbols(log, obj, ["-g", "-u"])):
        raise GateError("copy dependency must define one self-contained text symbol")
    alias = directory / f"{HELPER}.renamed.o"
    checked(log, ["objcopy", "--redefine-sym", f"{HELPER}={candidate_symbol('memcpy')}", obj, alias])
    checked(log, ["tools/elf-audit", "--assembly-object", alias])
    return alias


def coverage(directory, plan, binary, source, record):
    log = record["commands"]
    addresses, branches = describe_branches(binary, HELPER, source, log)
    assembly = checked(log, ["objdump", "-d", "--no-show-raw-insn", "-j", f".text.{HELPER}", binary])
    opcodes = {int(match[1], 16): match[2] for line in assembly.splitlines()
               if (match := INSTRUCTION.fullmatch(line))}

    def following(opcode):
        sites = [index for index, pc in enumerate(addresses) if opcodes[pc] == opcode]
        if len(sites) != 1 or sites[0] == len(addresses) - 1:
            raise GateError(f"expected a single CPU probe instruction {opcode}")
        return addresses[sites[0] + 1]

    qemu = shutil.which("qemu-x86_64")
    trace, sdk_hash = compile_plugin(directory, log)
    sdk = Path(qemu).resolve().parent.parent / "include"
    state_plugin = directory / "copy-state.so"
    checked(log, ["gcc", *COMPILE_FLAGS, "-fPIC", "-fvisibility=hidden", "-shared", "-I", sdk,
                  "-I", os.environ["OPEN_ASSEMBLY_GLIB_HEADERS"], "-I", os.environ["OPEN_ASSEMBLY_GLIB_CONFIG"],
                  "-o", state_plugin, PLUGIN])
    record["artifacts"] = {"qemu_header_sha256": sdk_hash, "edge_plugin_sha256": sha256_file(trace),
                           "state_plugin_sha256": sha256_file(state_plugin),
                           "binary_sha256": sha256_file(binary)}

    observed = set()
    for name, cpu, advertised, os_state, clear in PROFILE:
        edge_file, state_file = directory / f"{name}.edges", directory / f"{name}.state"
        prefix = [qemu, "-cpu", cpu, "-plugin",
                  f"{trace},start={addresses[0]:x},end={addresses[-1] + 1:x},output={edge_file}", "-plugin",
                  f"{state_plugin},cpuid={following('cpuid'):x},xstate={following('xgetbv'):x},"
                  f"clear={int(clear)},output={state_file}"]
        item = probe(plan, binary, "unit", prefix=prefix)
        record["profiles"][name] = item
        if item["outcome"] != "pass":
            raise GateError(f"{name}: instrumented copy oracle failed")
        values = re.fullmatch(r"(\d+) ([a-f0-9]{8}) (\d+) ([a-f0-9]{8}) (\d+)\n",
                              state_file.read_text(encoding="ascii"))
        if values is None:
            raise GateError(f"{name}: invalid CPU observation")
        feature_count, flags, xstate_count, xstate, changes = (
            int(value, 16 if index in {1, 3} else 10) for index, value in enumerate(values.groups()))
        if (feature_count != 1 or bool(flags & AVX) != advertised or ((flags & FEATURE_MASK) == FEATURE_MASK) != os_state
                or xstate_count != int(os_state) or bool((xstate & 6) == 6) != os_state or changes != int(clear)):
            raise GateError(f"{name}: CPU and OS feature observation differs")
        instructions, edges = read_edges(edge_file, addresses)
        executed = {opcodes[pc] for edge in edges for pc in edge}
        accelerated = os_state and not clear
        if (("vmovdqu" in executed) != accelerated or ("vzeroupper" in executed) != accelerated
                or ("xgetbv" in executed) != os_state or "movdqu" not in executed):
            raise GateError(f"{name}: execution trace disagrees with the measured CPU and OS state")
        item.update(cpuid1_ecx=hex(flags), original_xcr0=hex(xstate), cleared_ymm=clear,
                    accelerated=accelerated, instructions=instructions,
                    trace_sha256=sha256_file(edge_file), state_sha256=sha256_file(state_file))
        observed.update(edges)
        print(f"PASS {HELPER} {name}", flush=True)

    expected = {(pc, target) for pc, (_, _, taken, fallthrough) in branches.items() for target in (taken, fallthrough)}
    missing = sorted(expected - observed)
    record.update(covered=len(expected) - len(missing), total=len(expected),
                  missing=[[hex(pc), hex(target)] for pc, target in missing])
    if not expected or missing:
        raise GateError(f"{HELPER}: incomplete conditional-edge coverage")
    record["outcome"] = "pass"
    print(f"PASS {HELPER} QEMU branch coverage {len(expected)}/{len(expected)} edges", flush=True)


def mutation(directory, plan, objects, source, record):
    original = source.read_text()
    cases = (
        ("missing-osxsave", "0x1c000000", "0x14000000", "ISA_BASELINE"),
        ("missing-ymm-check", "cmp eax, 6", "cmp eax, 2", "ISA_BASELINE"),
        ("allow-unchecked-cache", "cmp eax, 2", "cmp eax, 1", "ISA_BASELINE"),
        ("undersized-vector", "cmp r8, 128", "cmp r8, 127", "ISA_BASELINE"),
        ("missing-vzeroupper", "    vzeroupper", "    nop", "ISA_BASELINE"),
        ("wrong-sse-source", "movdqu xmm1, [rsi + 16]", "movdqu xmm1, [rsi]", None),
        ("wrong-tail-byte", "mov [rdi], cl", "mov [rdi], al", None),
        ("wrong-return", "mov rax, r9", "lea rax, [r9 + 1]", None),
    )
    qemu = shutil.which("qemu-x86_64")
    for name, original_text, replacement, rule in cases:
        if original_text not in original:
            raise GateError(f"copy control no longer matches {name}")
        contents = original.replace(original_text, replacement, 2 if name == "missing-osxsave" else 1)
        case = directory / name
        case.mkdir()
        path = case / source.name
        path.write_text(contents)
        item = {"name": name, "source_sha256": sha256_file(path), "killed": False}
        record["operators"].append(item)
        program = parse(contents, {}, set(), False)
        try:
            verify_optional_memcpy(program, contents)
            verify(program, False, 0)
        except Violation as error:
            if error.rule != rule:
                raise GateError(f"{name}: unexpected checker diagnostic {error.rule}")
            item.update(killed=True, checker_rule=error.rule)
        else:
            if rule is not None:
                raise GateError(f"{name}: unsafe optional instruction control passed the checker")
            log = item["commands"] = []
            obj = copy_object(path, case, log)
            binary = link_checks(plan, "gcc", objects, [obj], case / "checks", log)
            result = item["probe"] = probe(plan, binary, "unit", prefix=(qemu, "-cpu", "qemu64"))
            if result["outcome"] != "fail":
                raise GateError(f"{name}: independent copy oracle did not identify the mutation")
            item["killed"] = True
    record.update(outcome="pass", killed=len(cases), total=len(cases))
    print(f"PASS {HELPER} policy and semantic mutation controls {len(cases)}/{len(cases)}", flush=True)


def execute():
    evidence = {"schema_version": 1, "scope": "production-private-dependency", "function": HELPER,
                "outcome": "fail", "checks": {}}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("objdump", "qemu-x86_64")
        evidence["inputs"] = verify_setup(checks, False, snapshot=phase2_inputs)
        sources = source_paths()
        source = sources[HELPER]
        evidence["source_sha256"] = sha256_file(source)
        workspace = BUILD / "production"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="memcpy-bulk-") as work:
            directory = Path(work).resolve().relative_to(ROOT)
            setup = checks["candidate"] = {"outcome": "fail", "commands": []}
            log = setup["commands"]
            candidate = directory / "candidate"
            _, metadata = assemble_candidate("memcpy", sources["memcpy"], candidate, log)
            if metadata["dependencies"] != {HELPER: str(source)}:
                raise GateError("memcpy production closure did not contain the expected bulk dependency")
            alias = copy_object(source, directory, log, original=candidate / f"{HELPER}.o")
            plan = read_plan("memcpy")
            objects = build_checks(plan, "gcc", directory / "tests", log)
            binary = link_checks(plan, "gcc", objects, [alias], directory / "checks", log)
            setup.update(outcome="pass", closure=metadata, direct_binary_sha256=sha256_file(binary))
            branch = checks["branch_coverage"] = {"outcome": "fail", "commands": [], "profiles": {}}
            coverage(directory, plan, binary, source, branch)
            mutations = checks["production_mutation"] = {"outcome": "fail", "operators": []}
            mutation(directory, plan, objects, source, mutations)
        if evidence["inputs"] != phase2_inputs():
            raise GateError("inputs changed during copy dependency verification")
        evidence["outcome"] = "pass"
    except (GateError, OSError, KeyError, ValueError, Violation) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(f"{HELPER}.production", evidence)
    print(f"copy dependency evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(execute())

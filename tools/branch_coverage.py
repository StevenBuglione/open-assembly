"""Map QEMU execution edges to conditional branches in a NASM function."""

import os
from pathlib import Path
import re
import shutil

from gate import COMPILE_FLAGS, GateError, checked, run
from lint import JCC
from spec import sha256_file

PLUGIN_SOURCE = Path("tests/tooling/qemu_branch_edges.c")
INSTRUCTION = re.compile(r"^\s*([0-9a-f]+):\s+([a-z0-9]+)(?:\s+(.*))?$")
LINE = re.compile(r"^\s*(\S+)\s+(\d+)\s+0x([0-9a-f]+)\b")


def describe_branches(binary, function, source, log):
    section = f".text.{function}"
    disassembly = checked(log, ["objdump", "-d", "--no-show-raw-insn", "-j", section, binary])
    instructions = {}
    for line in disassembly.splitlines():
        match = INSTRUCTION.fullmatch(line)
        if match:
            pc, mnemonic, operands = match.groups()
            instructions[int(pc, 16)] = (mnemonic, operands or "")
    if not instructions:
        raise GateError(f"{binary}: no disassembled instructions in {section}")

    decoded = checked(log, ["readelf", "--debug-dump=decodedline", binary])
    lines = {}
    for line in decoded.splitlines():
        if match := LINE.match(line):
            file, number, pc = match.groups()
            if Path(file).name == source.name:
                lines[int(pc, 16)] = int(number)
    addresses = sorted(instructions)
    branches = {}
    for index, pc in enumerate(addresses):
        mnemonic, operands = instructions[pc]
        if mnemonic not in JCC:
            continue
        target = re.match(r"([0-9a-f]+)\b", operands)
        if not target or index + 1 == len(addresses) or pc not in lines:
            raise GateError(f"{binary}: cannot resolve {mnemonic} at {pc:#x} to both edges and source")
        taken, fallthrough = int(target[1], 16), addresses[index + 1]
        if taken == fallthrough or taken not in instructions:
            raise GateError(f"{binary}: conditional branch at {pc:#x} lacks two distinct local outcomes")
        branches[pc] = (lines[pc], mnemonic, taken, fallthrough)
    return addresses, branches


def compile_plugin(directory, log):
    qemu = shutil.which("qemu-x86_64")
    glib_headers = os.environ.get("OPEN_ASSEMBLY_GLIB_HEADERS")
    glib_config = os.environ.get("OPEN_ASSEMBLY_GLIB_CONFIG")
    if not qemu or not glib_headers or not glib_config:
        raise GateError("QEMU coverage needs the pinned plugin SDK and GLib header paths")
    sdk = Path(qemu).resolve().parent.parent / "include"
    header = sdk / "qemu-plugin.h"
    if not header.is_file():
        raise GateError(f"missing QEMU plugin header {header}")
    plugin = directory / "branch-edges.so"
    checked(log, ["gcc", *COMPILE_FLAGS, "-fPIC", "-fvisibility=hidden", "-shared",
                  "-I", sdk, "-I", glib_headers, "-I", glib_config, "-o", plugin, PLUGIN_SOURCE])
    return plugin, sha256_file(header)


def read_edges(report, addresses):
    if not report.is_file():
        raise GateError(f"QEMU plugin did not write {report}")
    rows = report.read_text(encoding="ascii").splitlines()
    if (len(rows) < 2 or not re.fullmatch(r"instructions [1-9][0-9]*", rows[0])
            or rows[-1] != "complete"):
        raise GateError(f"{report}: plugin did not record a complete execution of the candidate")
    valid = set(addresses)
    observed = set()
    for row in rows[1:-1]:
        match = re.fullmatch(r"edge ([0-9a-f]+) ([0-9a-f]+)", row)
        if not match:
            raise GateError(f"{report}: invalid QEMU edge record {row!r}")
        edge = tuple(int(pc, 16) for pc in match.groups())
        if edge in observed or not set(edge) <= valid:
            raise GateError(f"{report}: duplicate or non-instruction edge {edge}")
        observed.add(edge)
    return int(rows[0].split()[1]), observed


def verify_coverage(record, directory, binary, function, source, commands, *, require_complete=True,
                    exact_case=None):
    log = record["commands"]
    addresses, branches = describe_branches(binary, function, source, log)
    plugin, header_hash = compile_plugin(directory, log)
    record["artifacts"] = {"plugin_sha256": sha256_file(plugin), "qemu_header_sha256": header_hash,
                           "binary_sha256": sha256_file(binary), "source_sha256": sha256_file(source)}
    coverage = set()
    for index, args in enumerate(commands):
        mode = exact_case.name if exact_case else args[0]
        report = directory / f"edges-{index}.txt"
        options = f"{plugin},start={addresses[0]:x},end={addresses[-1] + 1:x},output={report}"
        command = [shutil.which("qemu-x86_64"), "-plugin", options, binary, *args]
        if exact_case:
            result = run(command, environment=exact_case.env, timeout=90)
            log.append(result)
            passed = ((result["returncode"], result["stdout"], result["stderr"]) ==
                      (exact_case.status, exact_case.stdout, exact_case.stderr))
        else:
            stdout = checked(log, command, timeout=90)
            passed = stdout.startswith(f"PASS {mode} ")
        if not passed:
            raise GateError(f"instrumented {mode} did not pass the intended oracle")
        executions, observed = read_edges(report, addresses)
        record["runs"].append({"mode": mode, "instructions": executions,
                               "trace_sha256": sha256_file(report)})
        coverage.update(observed)

    edges = []
    for pc, (line, mnemonic, taken, fallthrough) in branches.items():
        for outcome, target in (("taken", taken), ("fallthrough", fallthrough)):
            edges.append({"source": str(source), "line": line, "instruction": mnemonic,
                          "pc": hex(pc), "target": hex(target), "branch": outcome,
                          "covered": (pc, target) in coverage})
    record["edges"] = edges
    covered = sum(edge["covered"] for edge in edges)
    record.update(covered=covered, total=len(edges))
    if covered != len(edges):
        record["outcome"] = "partial"
        if require_complete:
            raise GateError(f"{function}: QEMU covered {covered}/{len(edges)} conditional edges")
        return
    record["outcome"] = "pass"
    print(f"PASS {function} QEMU branch coverage {covered}/{len(edges)} edges", flush=True)

"""Flag same-symbol machine-code resemblance to pinned musl for human review."""

from collections import Counter, defaultdict
from dataclasses import dataclass
from difflib import SequenceMatcher
import hashlib
from pathlib import Path
import re
import sys
import tempfile

from gate import BUILD, GateError, checked, identify_tools, verify_setup, write_evidence
from phase1 import NASM, RUNTIME_SRC, build_runtime, phase1_inputs
from spec import ROOT, load_project, sha256_file, snapshot_inputs

ARCHIVE_SHA256 = "e8f8d0ea6cf704032c6d0b036e5157083190da84cc926d4289595d0653f7f89b"
CONTRACT = Path("docs/cookbook/musl-authorship.md")
DISTINCT = Path("tests/tooling/authorship/distinct.asm")
DISASSEMBLE = ("objdump", "-d", "-w", "-M", "intel", "--no-show-raw-insn")
TEXT_SYMBOL = re.compile(r"^([0-9a-f]+)\s+[gw]\s+(?:F\s+)?(\S+)\s+[0-9a-f]+\s+"
                         r"(?:\.(?:hidden|protected|internal)\s+)?(\S+)$")
INSTRUCTION = re.compile(r"^\s*([0-9a-f]+):\s+(\S+)(?:\s+(.*?))?\s*$")
PADDING = re.compile(r"(?:^|\s)nop(?:[wlq])?(?:\s|$)")
DIRECT_TARGET = re.compile(r"^([0-9a-f]+)(?:\s+<[^>]*>)?$")
RIP_DISPLACEMENT = re.compile(r"\brip(?:[-+]0x[0-9a-f]+)?\b")
PREFIXES = {"lock", "rep", "repe", "repz", "repne", "repnz", "bnd", "notrack"}
POLICY = {"minimum_instructions": 12, "near_per_mille": 900, "near_contiguous": 8,
          "contained_per_mille": 650, "contained_contiguous": 20, "contained_percent_shorter": 75}


@dataclass(frozen=True)
class Member:
    name: str
    occurrence: int
    path: Path


def registers():
    groups = [("rax", "eax", "ax", "al", "ah"), ("rbx", "ebx", "bx", "bl", "bh"),
              ("rcx", "ecx", "cx", "cl", "ch"), ("rdx", "edx", "dx", "dl", "dh"),
              ("rsi", "esi", "si", "sil"), ("rdi", "edi", "di", "dil"),
              ("rbp", "ebp", "bp", "bpl"), ("rsp", "esp", "sp", "spl")]
    groups.extend((f"r{i}", f"r{i}d", f"r{i}w", f"r{i}b") for i in range(8, 16))
    result = {reg: (group[0], width) for group in groups
              for reg, width in zip(group, ("64", "32", "16", "8l", "8h"))}
    for i in range(32):
        for prefix, width in (("xmm", 128), ("ymm", 256), ("zmm", 512)):
            result[f"{prefix}{i}"] = (f"vector{i}", str(width))
    return result


REGISTERS = registers()
REGISTER_TOKEN = re.compile(r"(?<!\w)(?:" + "|".join(sorted(REGISTERS, key=lambda token: (-len(token), token))) + r")(?!\w)")


def inputs():
    return dict(sorted((phase1_inputs() | snapshot_inputs(ROOT, [CONTRACT])).items()))


def musl_archive():
    path = Path(checked([], ["musl-gcc", "-print-file-name=libc.a"]).strip()).resolve()
    if not path.is_file() or sha256_file(path) != ARCHIVE_SHA256:
        raise GateError("musl static archive does not match its reviewed byte hash")
    return path


def musl_members(archive, workspace, names):
    members = checked([], ["ar", "t", archive]).splitlines()
    if not members or any(not re.fullmatch(r"[A-Za-z0-9_+.\-]+", name) or name in {".", ".."}
                          for name in members):
        raise GateError("musl archive contains an unsupported member name")
    counts = Counter(members)
    workspace.mkdir()
    checked([], ["ar", "x", f"--output={workspace}", archive])
    extracted = {}
    for name, count in counts.items():
        for occurrence in range(1, count + 1):
            directory = workspace
            if count > 1:
                directory = workspace / f"duplicate-{name}-{occurrence}"
                directory.mkdir()
                checked([], ["ar", "xN", occurrence, f"--output={directory}", archive, name])
            member = Member(name, occurrence, directory / name)
            extracted[str(member.path)] = member
    symbol_map = defaultdict(list)
    output = checked([], ["nm", "-P", "-A", "-g", "--defined-only", *extracted], timeout=60)
    for line in output.splitlines():
        origin, _, description = line.partition(": ")
        fields = description.split()
        if len(fields) >= 2 and fields[0] in names and fields[1] in {"T", "W"}:
            if origin not in extracted:
                raise GateError("unrecognized extracted musl object in symbol table")
            symbol_map[fields[0]].append(extracted[origin])
    return symbol_map, {name: count for name, count in sorted(counts.items()) if count > 1}


def disassemble(path, name):
    output = checked([], [*DISASSEMBLE, f"--disassemble={name}", path])
    if f"<{name}>:" in output:
        return name, output
    # GNU objdump may only decode the preferred label at an aliased address.
    table = checked([], ["objdump", "-t", "-w", path])
    locations = {row[3]: (row[1], row[2]) for line in table.splitlines()
                 if (row := TEXT_SYMBOL.fullmatch(line))}
    for alias, location in sorted(locations.items()):
        if alias == name or location != locations.get(name):
            continue
        output = checked([], [*DISASSEMBLE, f"--disassemble={alias}", path])
        if f"<{alias}>:" in output:
            return alias, output
    raise GateError(f"{path.name} cannot disassemble the exported {name} text")


def decoded(path, name):
    label, output = disassemble(path, name)
    result = []
    for row in output.splitlines():
        match = INSTRUCTION.fullmatch(row)
        if match is None:
            continue
        address, opcode, operands = match[1], match[2], (match[3] or "").partition("#")[0].strip().lower()
        if opcode in {"endbr64", "endbr32"} or PADDING.search(f"{opcode} {operands}"):
            continue
        if opcode in {"(bad)", ".byte"}:
            raise GateError(f"{path.name} contains undecoded {name} text")
        if opcode in PREFIXES and operands:
            following = operands.split(None, 1)
            opcode = f"{opcode}:{following[0]}"
            operands = following[1] if len(following) > 1 else ""
        if opcode == "xchg":
            left, _, right = operands.partition(",")
            if left.strip() == right.strip():
                continue
        result.append((int(address, 16), opcode, operands))
    if not result:
        raise GateError(f"{path.name} has no decoded instructions for {name}")
    return label, result


def normalize(instructions):
    aliases = {}
    first, last = instructions[0][0], instructions[-1][0]
    tokens = []

    def rename(match):
        register, width = REGISTERS[match[0]]
        if register in {"rsp", "rbp"}:
            return f"{register}:{width}"
        label = aliases.setdefault(register, len(aliases))
        register_class = "vec" if register.startswith("vector") else "gp"
        return f"{register_class}{label}:{width}"

    for address, opcode, operands in instructions:
        if (opcode.startswith(("j", "loop")) or opcode == "call") and (target := DIRECT_TARGET.fullmatch(operands)):
            destination = int(target[1], 16)
            if not first <= destination <= last:
                operands = "direct:external"
            else:
                operands = "direct:back" if destination <= address else "direct:forward"
        else:
            operands = re.sub(r"\s*<[^>]*>", "", operands)
            operands = RIP_DISPLACEMENT.sub("rip+disp", operands)
            operands = "".join(REGISTER_TOKEN.sub(rename, operands).split())
        tokens.append(f"{opcode} {operands}".rstrip())
    return tokens


def fingerprint(tokens):
    return {"instructions": len(tokens), "sha256": hashlib.sha256("\n".join(tokens).encode("ascii")).hexdigest()}


def compare(candidate, reference):
    shorter = min(len(candidate), len(reference))
    matches = SequenceMatcher(None, candidate, reference, autojunk=False).get_matching_blocks()
    longest = max(block.size for block in matches)
    similarity = 2000 * sum(block.size for block in matches) // (len(candidate) + len(reference))
    if shorter < POLICY["minimum_instructions"]:
        reason = "below-minimum"
    elif candidate == reference:
        reason = "normalized-exact"
    elif similarity >= POLICY["near_per_mille"] and longest >= POLICY["near_contiguous"]:
        reason = "normalized-near"
    elif (similarity >= POLICY["contained_per_mille"] and longest >= POLICY["contained_contiguous"]
          and 100 * longest >= POLICY["contained_percent_shorter"] * shorter):
        reason = "normalized-containment"
    else:
        reason = "clear"
    return {"classification": reason, "similarity_per_mille": similarity, "longest_contiguous": longest,
            "candidate": fingerprint(candidate), "reference": fingerprint(reference)}


def verify_controls(directory, member):
    symbol = "strlen"
    copied = directory / "relocated-musl-control.o"
    distinct = directory / "distinct-control.o"
    checked([], ["objcopy", "--change-section-vma", ".text.strlen=0x10000", member.path, copied])
    checked([], [*NASM, "-o", distinct, DISTINCT])
    checked([], ["tools/elf-audit", "--assembly-object", distinct])
    _, original = decoded(member.path, symbol)
    _, relocated = decoded(copied, symbol)
    if original[0][0] == relocated[0][0] or sha256_file(member.path) == sha256_file(copied):
        raise GateError("copied control did not change the disassembly addresses")
    reference = normalize(original)
    negative = compare(normalize(relocated), reference)
    _, different = decoded(distinct, symbol)
    positive = compare(normalize(different), reference)
    if negative["classification"] != "normalized-exact" or positive["classification"] != "clear":
        raise GateError("copied and distinct controls did not receive their expected classifications")
    return {"symbol": symbol, "reference_member_sha256": sha256_file(member.path),
            "copied": {"object_sha256": sha256_file(copied), **negative},
            "distinct": {"object_sha256": sha256_file(distinct), **positive}}


def scan(directory, archive, report):
    runtime_directory = directory / "runtime"
    _, library, exports, hashes = build_runtime(runtime_directory, [])
    report["candidate_archive_sha256"] = sha256_file(library)
    project = load_project()
    sources = {path.stem: path for path in sorted(RUNTIME_SRC.rglob("*.asm")) if path.stem in project.functions}
    if not sources or any(exports.get(symbol) != "T" for symbol in sources):
        raise GateError("runtime symbol and public source sets differ")
    references, duplicates = musl_members(archive, directory / "musl", sources)
    report["duplicate_archive_members"] = duplicates
    if len(references["strlen"]) != 1:
        raise GateError("copied control must use the unique pinned strlen object")
    report["controls"] = verify_controls(directory, references["strlen"][0])
    for name, source in sorted(sources.items()):
        obj = Path("obj") / source.relative_to(RUNTIME_SRC).with_suffix(".o")
        record = {"symbol": name, "source": source.as_posix(), "candidate_object_sha256": hashes[obj.as_posix()]}
        if name not in references:
            record["classification"] = "no-matching-musl-symbol"
            report["symbols"].append(record)
            continue
        _, candidate_code = decoded(runtime_directory / obj, name)
        candidate = normalize(candidate_code)
        for member in references[name]:
            label, reference = decoded(member.path, name)
            report["symbols"].append({**record, "musl_member": member.name, "musl_occurrence": member.occurrence,
                                      "musl_entry_label": label, "musl_object_sha256": sha256_file(member.path),
                                      **compare(candidate, normalize(reference))})


def main():
    name = "musl-authorship"
    report = {"schema_version": 1, "scope": "nightly-same-symbol-musl-authorship-scan",
              "outcome": "fail", "production_verified": False, "policy": POLICY, "symbols": []}
    try:
        report["toolchain"] = identify_tools("musl-gcc", "objdump", "make", "ar")
        report["inputs"] = verify_setup({}, False, snapshot=inputs)
        archive = musl_archive()
        report["musl_archive_sha256"] = sha256_file(archive)
        with tempfile.TemporaryDirectory(dir=BUILD, prefix=f"{name}-") as temp:
            scan(Path(temp).resolve().relative_to(ROOT), archive, report)
        if inputs() != report["inputs"]:
            raise GateError("authorship inputs changed during the scan")
        report["outcome"] = "pass"
    except (GateError, OSError, ValueError) as error:
        report["reason"] = str(error)
    report["counts"] = dict(Counter(row["classification"] for row in report["symbols"]))
    reviews = [row for row in report["symbols"] if row["classification"].startswith("normalized-")]
    path = write_evidence(name, report)
    queue = write_evidence(f"{name}-review", {"schema_version": 1, "scan_sha256": sha256_file(path),
                          "scan_outcome": report["outcome"], "items": reviews})
    print(f"{report['outcome'].upper()} musl authorship scan, {len(reviews)} review item(s), evidence at {path} and {queue}")
    if "reason" in report:
        print(report["reason"], file=sys.stderr)
    return int(report["outcome"] != "pass")


if __name__ == "__main__":
    raise SystemExit(main())

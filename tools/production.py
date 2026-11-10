"""Run the local per-function gate on an actual Phase 2 candidate."""

from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import sys
import tempfile

from branch_coverage import verify_coverage
from gate import (BUILD, COMPILE_FLAGS, CandidateFailure, GateError, LINK_FLAGS, check_strlen_prototype, checked, identify_tools,
                  finish_function_gate, inputs, nm_symbols, run, verify_setup)
from lint import JCC
from phase1 import NASM
from spec import (IDENTIFIER, ROOT, comment_header, keys, load_project, matching, read_toml,
                  nasm_name, regular_file, relative_path, sha256_file, snapshot_inputs, string_list,
                  version_one)

MANIFEST = Path("tests/phase2/manifest.toml")
LEGACY_ORACLES = {"gcc": Path("tests/external/strlen_glibc.c"),
                  "musl-gcc": Path("tests/external/strlen_musl.c")}
CANDIDATE_ROOT = Path("src/x86_64-linux")
MODES = ("abi", "unit", "guard", "differential", "fuzz")
SCALAR_FUNCTIONS = ("abs", "labs", "llabs", "div", "ldiv", "lldiv", "imaxabs", "imaxdiv")
TWO_REGISTER_RETURNS = {"ldiv_t", "lldiv_t", "imaxdiv_t"}
REQUIRED_CHECKS = {
    "generated_outputs", "candidate_build", "branch_coverage", "native_oracles",
    "musl_differential", "platform_matrix", "generated_stub", "production_mutation",
    "engine_fuzz", "external_conformance",
}
SUITE_CASES = {
    "strlen": ("string_memmem", "snprintf"),
    "memcpy": ("string", "string_memcpy"),
    "memset": ("string", "string_memset"),
    "memcmp": ("string",),
    "strcpy": ("string",), "strncpy": ("string",), "strcmp": ("string",),
    "strncmp": ("string",), "strncat": ("string",), "strchr": ("string", "string_strchr"),
    "strrchr": ("string",), "strspn": ("string",),
    "strcspn": ("string", "string_strcspn"), "strpbrk": ("string",), "strtok": ("string",),
    "strstr": ("string_strstr",), "qsort": ("qsort",),
    "strtol": ("strtol",), "strtoll": ("strtol",), "strtoul": ("strtol",), "strtoull": ("strtol",),
}
CONDITIONS = (
    ("je jz", "jne jnz"), ("ja jnbe", "jbe jna"), ("jae jnb jnc", "jb jnae jc"),
    ("jg jnle", "jle jng"), ("jge jnl", "jl jnge"), ("jo", "jno"),
    ("js", "jns"), ("jp jpe", "jnp jpo"),
)
INVERSE = {}
for left, right in CONDITIONS:
    INVERSE.update({mnemonic: right.split()[0] for mnemonic in left.split()})
    INVERSE.update({mnemonic: left.split()[0] for mnemonic in right.split()})
SIGNED = dict(zip(("ja", "jae", "jb", "jbe", "jg", "jge", "jl", "jle"),
                  ("jg", "jge", "jl", "jle", "ja", "jae", "jb", "jbe"), strict=True))
MUTATION_EQUIVALENCES = {
    "aligned_alloc": ("54018c8232eb79be972248c95639918d735b662e6dba1073313da6db617fe58a", {
        "comparison-plus-one-38": "Only alignment 16 changes path. The fallback writes the same alignment 16.",
        "comparison-minus-one-38": "Only alignment 15 changes path. The prior power-of-two check rejects 15.",
    }),
    "posix_memalign": ("f9e673ae0de30af7ef9277d1dec68ef1ec664b561fe0616eedc0cff5c1b81554", {
        "comparison-minus-one-28": "Only alignment 7 reaches the power-of-two check instead of returning EINVAL immediately. It fails that check with the same result and effects.",
        "comparison-plus-one-39": "Only alignment 16 changes path. The fallback writes the same alignment 16.",
        "comparison-minus-one-39": "Only alignment 15 changes path. The prior power-of-two check rejects 15.",
    }),
    "http_find_header_end": ("ce3be959f11603bdd7a026a55e8522d88c1dbd7ec6da758b79eaa5ce5a34e807", {
        "comparison-signedness-25": "A readable x86-64 Linux user byte span has length below 2^63. The length and threshold four have bit 63 clear.",
        "comparison-signedness-33": "The remaining-start limit is the valid length minus three. The counter starts at zero and cannot exceed that limit. Both operands have bit 63 clear.",
    }),
    "http_is_token_byte": ("55dfcc73455cbfbef2c144e28ee3dac2da8661a0e1f97e2f9ca36f88d4183226", {
        "comparison-minus-one-25": "The change reroutes only ASCII DEL, 127. Bit seven of the last in-bounds bitmap byte is zero, so both paths return zero.",
        "comparison-signedness-26": "The ABI byte is zero-extended to 0 through 255 before comparing against 128. Both operands have bit 31 clear.",
    }),
    "json_scan_string": ("2b9d722dd0a6ed8d547b36f021327c7ba60ba3e4dde5ef8be5d76e9c77eda92e", {
        "comparison-signedness-53": "The zero-extended input byte and the ASCII control boundary both have bit 31 clear.",
        "comparison-signedness-55": "The zero-extended input byte and the ASCII high boundary both have bit 31 clear.",
        "comparison-signedness-59": "The zero-extended UTF-8 lead byte and the lead lower bound both have bit 31 clear.",
        "comparison-signedness-61": "The zero-extended UTF-8 lead byte and the lead upper bound both have bit 31 clear.",
        "comparison-signedness-66": "The zero-extended UTF-8 lead byte and the three-byte lead boundary both have bit 31 clear.",
        "comparison-signedness-79": "The zero-extended UTF-8 lead byte and the four-byte lead boundary both have bit 31 clear.",
        "comparison-signedness-93": "The offset is at most the validated length at most LONG_MAX. The required continuation count is 1 through 3.",
        "comparison-signedness-96": "The zero-extended first continuation byte and its lower bound, 0x80 through 0xa0, have bit 31 clear.",
        "comparison-signedness-98": "The zero-extended first continuation byte and its upper bound, 0x8f through 0xbf, have bit 31 clear.",
        "comparison-plus-one-139": "Exactly four bytes remain after the Unicode escape introducer on the changed path. Invalid hex rejects, and valid hex consumes all four bytes with no closing quote or required following surrogate left. Both paths return EILSEQ without writing.",
        "comparison-signedness-140": "The offset is at most the validated length at most LONG_MAX. Its remaining length and the four-byte threshold have bit 63 clear.",
        "comparison-signedness-162": "The parsed four hex digits give an integer from 0 through 65535. The surrogate boundary also has bit 31 clear.",
        "comparison-signedness-164": "The parsed four hex digits give an integer from 0 through 65535. The surrogate boundary also has bit 31 clear.",
        "comparison-signedness-166": "The parsed four hex digits give an integer from 0 through 65535. The surrogate boundary also has bit 31 clear.",
        "comparison-plus-one-169": "Exactly two bytes remain after the high surrogate on the changed path. A wrong escape introducer rejects, and a correct introducer consumes both bytes with no hex digits left. Both paths return EILSEQ without writing.",
        "comparison-signedness-170": "The offset is at most the validated length at most LONG_MAX. Its remaining length and the two-byte threshold have bit 63 clear.",
    }),
    "memcpy": ("74ee3ddf94d9634b2f7997471965faa1adec9158e14bbe13babd8f2463554969", {
        "comparison-plus-one-29": "The one rerouted length 256 is copied byte for byte by the original baseline.",
        "comparison-minus-one-29": "The one rerouted length 255 is within the bulk helper's valid range and is copied byte for byte.",
        "invert-branch-30": "The baseline and bulk paths copy the same positive disjoint range. The unchanged zero test returns before selection.",
        "comparison-signedness-30": "Any disjoint valid user object extent has bit 63 clear, so the dispatch comparison is unchanged.",
    }),
    "__al_strtox": ("a5631fe7518c5ad2f1f484da046b77afd56621dc4cbc07e45e3aefa125155ba9", {
        "comparison-signedness-29": "A negative base reaches .zero_result through one of the two range checks with either comparison.",
        "comparison-signedness-139": "Code units below ASCII '0' remain invalid. The later unsigned digit/base comparison rejects the negative offset before accumulation.",
        "comparison-signedness-143": "A negative alphabet offset takes .end_digits either here or at the immediately following unsigned upper bound.",
        "comparison-plus-one-144": "The added digit 36 is rejected by the next comparison for every radix from 2 through 36.",
        "comparison-signedness-145": "A negative alphabet offset still reaches .end_digits through the following unsigned digit/base comparison.",
        "comparison-signedness-148": "For a possible digit both the digit and radix have bit 63 clear. A negative offset has already been excluded.",
        "comparison-signedness-154": "The preceding unsigned jump excludes values above the cutoff. The cutoff is at most UINT64_MAX divided by two.",
        "comparison-signedness-156": "Both the digit and remainder are below the radix and have bit 63 clear.",
    }),
    "bsearch": ("8926356d54c6fcadadc308330b7ab3505233037957b45361b01088fd03135ce7", {
        "comparison-signedness-49": "Both indices are bounded by the readable Linux user array.",
    }),
    "memmove": ("0d280e67a9e08a4acfc70222ce1b14e27e7225ccb0a38ed46936db51486ea54f", {
        "comparison-signedness-30": "Valid x86-64 Linux user pointers have bit 63 clear.",
        "comparison-signedness-36": "This path has dest > src. Their difference and the valid object extent have bit 63 clear.",
    }),
    "pwrite": ("d308e3ac36e5b338ded35ea90b4d98ca3c6bfb10d536e90a6cdb4d19001f473e", {
        "comparison-minus-one-46": "The only changed F_GETFL result is -4096. Successful file flags are unsigned and Linux errors range from -4095 to -1.",
        "comparison-minus-one-59": "The only changed fstatfs result is -4096. fstatfs returns zero on success and Linux errors range from -4095 to -1.",
    }),
    "qsort": ("d10adef9dc4ba66ed9084390813a257af587ab3c88763090f32ce0b801707a8c", {
        "comparison-minus-one-27": "The added one-element path reaches .done without comparing or writing any element.",
        "comparison-signedness-28": "A valid array with nonzero element width has a count below 2^63. Zero width returns independently.",
        "comparison-signedness-81": "The heap index and the count divided by two are bounded by the valid array.",
        "comparison-signedness-86": "The right-child index and heap count have bit 63 clear for the valid array.",
    }),
}


@dataclass(frozen=True)
class Plan:
    name: str
    id: int
    sources: tuple
    host_symbols: tuple
    coverage_modes: tuple
    oracle: tuple
    fuzz_sources: tuple
    guard_skip: str
    fuzz_host: bool = False

    @property
    def legacy_strlen(self):
        return self.name == "strlen" and Path("tests/unit/strlen.c") in self.sources

    @property
    def defines(self):
        return (f"-DTEST_NAME={self.name}", f"-DTEST_FUNCTION_ID={self.id}")


def test_paths(table, key, where, *, required):
    values = string_list(table.get(key, []), r".+", where, nonempty=required)
    result = tuple(Path(relative_path(value, where)) for value in values)
    for path in result:
        if path.parts[0] != "tests" or path.suffix not in {".c", ".asm"}:
            raise GateError(f"{where}: unsupported fixture path {path}")
        regular_file(ROOT, path, where)
    return result


def read_plan(function):
    document = read_toml(regular_file(ROOT, MANIFEST, "Phase 2 manifest"))
    keys(document, {"schema", "function"}, MANIFEST)
    version_one(document["schema"], MANIFEST)
    if type(document["function"]) is not list or not document["function"]:
        raise GateError(f"{MANIFEST}: expected a nonempty [[function]] array")
    names, ids = {}, set()
    for table in document["function"]:
        keys(table, {"name", "id", "sources", "host_symbols", "coverage_modes", "oracle"}, MANIFEST,
             ("fuzz_sources", "guard_skip", "fuzz_host"))
        name = matching(table["name"], IDENTIFIER, MANIFEST)
        id_ = table["id"]
        if type(id_) is not int or id_ <= 0 or id_ in ids or name in names:
            raise GateError(f"{MANIFEST}: missing or duplicate identity for {name}")
        ids.add(id_)
        where = f"{MANIFEST}: {name}"
        host_symbols = string_list(table["host_symbols"], IDENTIFIER, where, nonempty=True)
        modes = string_list(table["coverage_modes"], r"abi|unit|guard|differential|fuzz",
                            where, nonempty=True)
        oracle = string_list(table["oracle"], r"[a-z][a-z0-9_-]*:[A-Za-z0-9_./+-]+",
                             where, nonempty=True)
        skip = table.get("guard_skip", "")
        if type(skip) is not str or (skip and (not skip.strip() or "guard" in modes)):
            raise GateError(f"{where}: an inapplicable guard requires a reason and no guard mode")
        fuzz_host = table.get("fuzz_host", False)
        if type(fuzz_host) is not bool or (fuzz_host and "diff:glibc" not in oracle):
            raise GateError(f"{where}: hosted fuzz requires a boolean and the glibc oracle")
        names[name] = Plan(name, id_, test_paths(table, "sources", where, required=True),
                           host_symbols, modes, oracle,
                           test_paths(table, "fuzz_sources", where, required=False), skip, fuzz_host)
    if function not in names:
        raise GateError(f"{function}: independent production test manifest is pending")
    return names[function]


def phase2_inputs():
    bound = inputs()
    headers = sorted(path.relative_to(ROOT) for path in (ROOT / BUILD / "include/c").rglob("*.h"))
    contracts = [Path("docs/adr/0002-runtime-abi.md"), Path("docs/adr/0035-memcpy-dispatch.md"),
                 Path("docs/cookbook/scalar-verification.md")]
    bound.update(snapshot_inputs(ROOT, [*headers, *contracts]))
    return dict(sorted(bound.items()))


def candidate_symbol(name):
    return f"__al_test_{name}"


def source_paths():
    sources = {}
    for path in sorted(CANDIDATE_ROOT.rglob("*.asm")):
        if path.stem in sources:
            raise GateError(f"multiple runtime sources define {path.stem}")
        sources[path.stem] = path
    return sources


def assemble_candidate(function, source, directory, log):
    directory.mkdir()
    sources = source_paths()
    pending = [(function, source)]
    objects, definitions = {}, {}
    host_dependencies = set()
    while pending:
        name, path = pending.pop()
        if name in objects:
            continue
        command = ["tools/lint"]
        if name == function:
            command.extend(("--function", function))
        checked(log, [*command, path])
        obj = directory / f"{name}.o"
        checked(log, [*NASM, "-g", "-F", "dwarf", "-o", obj, path])
        checked(log, ["tools/elf-audit", "--assembly-object", obj])
        exported = nm_symbols(log, obj, ["-g", "--defined-only"])
        if exported != {name: "T"}:
            raise GateError(f"{path}: expected exactly the text export {name}")
        objects[name] = obj
        definitions.update(exported)
        for dependency, kind in nm_symbols(log, obj, ["-g", "-u"]).items():
            if kind != "U":
                raise GateError(f"{path}: unsupported weak reference {dependency}")
            if dependency == "__errno_location":
                # Hosted differentials deliberately use the active host TLS errno.
                host_dependencies.add(dependency)
            elif dependency in sources and dependency != "_start":
                pending.append((dependency, sources[dependency]))
            else:
                raise GateError(f"{path}: no candidate dependency for {dependency}")
    renamed = []
    options = [option for name in definitions
               for option in ("--redefine-sym", f"{name}={candidate_symbol(name)}")]
    for name, obj in objects.items():
        destination = directory / f"{name}.renamed.o"
        checked(log, ["objcopy", *options, obj, destination])
        checked(log, ["tools/elf-audit", "--assembly-object", destination])
        if nm_symbols(log, destination, ["-g", "--defined-only"]) != {candidate_symbol(name): "T"}:
            raise GateError(f"{destination}: candidate symbol rename failed")
        renamed.append(destination)
    paths = [*objects.values(), *renamed]
    return renamed, {"artifacts": {path.name: sha256_file(path) for path in paths},
                     "dependencies": {name: str(sources[name]) for name in objects if name != function},
                     "host_dependencies": sorted(host_dependencies)}


def build_checks(plan, compiler, directory, log):
    directory.mkdir()
    objects, refs = [], set()
    target = candidate_symbol(plan.name)
    for index, source in enumerate(plan.sources):
        path = directory / f"checks-{index}.o"
        if source.suffix == ".c":
            flags = ["-DTEST_HOST_MUSL=1"] if compiler == "musl-gcc" else []
            checked(log, [compiler, *COMPILE_FLAGS, *plan.defines, *flags, "-c", source, "-o", path])
            checked(log, ["tools/elf-audit", "--test-object", path])
            refs.update(name for name, kind in nm_symbols(log, path, ["-g", "-u"]).items() if kind == "U")
        else:
            checked(log, [*NASM, "-o", path, source])
            checked(log, ["tools/elf-audit", "--assembly-object", path])
        objects.append(path)
    needed = {target}
    if not plan.legacy_strlen:
        needed.update(plan.host_symbols)
    if needed - refs:
        raise GateError(f"{compiler} {plan.name}: missing C test references {sorted(needed - refs)}")
    return objects


def link_checks(plan, compiler, objects, candidate, binary, log):
    sections = [f"-Wl,--unique=.text.{path.name.removesuffix('.renamed.o')}" for path in candidate]
    checked(log, [compiler, *LINK_FLAGS, *sections,
                  "-o", binary, *objects, *candidate])
    checked(log, ["tools/elf-audit", binary])
    if nm_symbols(log, binary, ["-g", "--defined-only"]).get(candidate_symbol(plan.name)) != "T":
        raise GateError(f"{binary}: missing linked candidate symbol")
    return binary


def legacy_oracle(compiler, directory, log):
    obj = directory / f"oracle-{compiler}.o"
    binary = directory / f"oracle-{compiler}"
    check_strlen_prototype(log, compiler)
    checked(log, [compiler, *COMPILE_FLAGS, "-c", LEGACY_ORACLES[compiler], "-o", obj])
    checked(log, ["tools/elf-audit", "--test-object", obj])
    if nm_symbols(log, obj, ["-g", "-u"]).get("strlen") != "U":
        raise GateError(f"{compiler}: strlen oracle lacks its host reference")
    checked(log, [compiler, *LINK_FLAGS, "-o", binary, obj])
    checked(log, ["tools/elf-audit", binary])
    return binary


def arguments(plan, mode, oracle=None, seconds=0):
    args = [mode]
    if plan.legacy_strlen and mode in {"differential", "fuzz"}:
        args.append(oracle)
    if mode == "fuzz":
        args.append(seconds)
    return args


def probe(plan, binary, mode, oracle=None, *, seconds=0, musl=False, prefix=()):
    environment = {**os.environ, "LC_ALL": "C",
                   "OPEN_ASSEMBLY_STRLEN_ORACLE": "musl" if musl else "glibc"}
    result = run([*prefix, binary, *arguments(plan, mode, oracle, seconds)],
                 environment=environment, timeout=seconds + 30)
    oracle_pattern = "|".join(re.escape(identity) for identity in plan.oracle)
    if (result["returncode"] == 0 and not result["stderr"]
            and re.match(rf"PASS {mode} (?:{oracle_pattern})(?:\s|$)", result["stdout"])):
        return {**result, "outcome": "pass"}
    if (result["returncode"] == 1 and
            re.search(rf"^FAIL {mode} (?:{oracle_pattern}): ", result["stderr"], re.M)
            and "ERROR " not in result["stderr"]):
        return {**result, "outcome": "fail"}
    return {**result, "outcome": "error"}


def expect_probe(plan, record, binary, mode, oracle=None, *, expected="pass", candidate=False, **options):
    item = probe(plan, binary, mode, oracle, **options)
    record["probes"].append(item)
    if item["outcome"] != expected:
        detail = (item["stderr"] or item["stdout"]).strip()
        error = CandidateFailure if candidate and expected == "pass" and item["outcome"] == "fail" else GateError
        raise error(f"{plan.name} {mode}: expected {expected}, got {item['outcome']}. {detail}")
    print((item["stdout"] or item["stderr"]).strip(), flush=True)


def result_type(spec):
    return spec.prototype.split("(", 1)[0].removesuffix(spec.name).strip()


def stub_source(spec, directory):
    path = directory / f"{spec.name}.stub.asm"
    remainder = "    xor edx, edx\n" if result_type(spec) in TWO_REGISTER_RETURNS else ""
    symbol = nasm_name(spec.name)
    path.write_text(comment_header(spec) + f"""
bits 64
default rel
global {symbol}:function
section .text.{spec.name} progbits alloc exec nowrite
{symbol}:
    xor eax, eax
{remainder}    ret
section .note.GNU-stack noalloc noexec nowrite progbits
""", encoding="utf-8")
    return path


def variants(source, *, returns_value=True, result_pair=None):
    lines = source.read_text(encoding="utf-8").splitlines(keepends=True)
    for index, line in enumerate(lines):
        statement, comment, remainder = line.rstrip("\n").partition(";")
        if match := re.fullmatch(r"(\s*)([a-z]+)(\s+\S+)\s*", statement):
            indent, opcode, args = match.groups()
            if opcode in JCC and opcode in INVERSE:
                operators = [("invert-branch", INVERSE[opcode])]
                if opcode in SIGNED:
                    operators.append(("comparison-signedness", SIGNED[opcode]))
                for name, replacement in operators:
                    yield f"{name}-{index + 1}", "".join(
                        [*lines[:index], f"{indent}{replacement}{args} {comment}{remainder}\n",
                         *lines[index + 1:]])
        if match := re.fullmatch(r"(\s*cmp\s+[^,]+,\s*)(-?(?:[0-9]+|0x[0-9a-f]+))\s*", statement):
            operand, value = match.groups()
            base = 16 if "0x" in value else 10
            for offset, suffix in ((1, "plus"), (-1, "minus")):
                yield f"comparison-{suffix}-one-{index + 1}", "".join(
                    [*lines[:index], f"{operand}{int(value, base) + offset} {comment}{remainder}\n",
                     *lines[index + 1:]])
    if returns_value:
        mutations = {"return-plus-one": "inc rax", "return-minus-one": "dec rax"}
        if result_pair == "rdx":
            mutations.update({"remainder-plus-one": "inc rdx", "remainder-minus-one": "dec rdx"})
        elif result_pair == "packed32":
            mutations.update({"remainder-plus-one": "mov rcx, 0x100000000\n    add rax, rcx",
                              "remainder-minus-one": "mov rcx, 0x100000000\n    sub rax, rcx"})
        for name, instruction in mutations.items():
            mutated = [f"    {instruction}\n{line}" if re.match(r"^\s*ret\s*(?:;.*)?$", line) else line
                       for line in lines]
            if mutated != lines:
                yield name, "".join(mutated)


def applicable_variants(function, source, record, *, returns_value=True, result_pair=None, run_equivalent=False):
    proof_hash, exclusions = MUTATION_EQUIVALENCES.get(function, ("", {}))
    if exclusions and sha256_file(source) != proof_hash:
        raise GateError(f"{function}: source changed since its reviewed mutation equivalence proofs")
    applied_exclusions = set()
    record["equivalent"] = []
    for name, contents in variants(source, returns_value=returns_value, result_pair=result_pair):
        if name in exclusions:
            record["equivalent"].append({"operator": name, "source_sha256": proof_hash,
                                         "reason": exclusions[name]})
            applied_exclusions.add(name)
            if not run_equivalent:
                continue
        yield name, contents
    if applied_exclusions != exclusions.keys():
        raise GateError(f"{function}: mutation equivalence proofs do not match generated operators")


def mutation_campaign(plan, spec, source, directory, test_objects, oracle, record):
    directory.mkdir()
    returns_void = re.match(rf"(?:_Noreturn )?void +{re.escape(spec.name)}\s*\(", spec.prototype) is not None
    type_name = result_type(spec)
    result_pair = "rdx" if type_name in TWO_REGISTER_RETURNS else "packed32" if type_name == "div_t" else None
    for name, contents in applicable_variants(plan.name, source, record, returns_value=not returns_void,
                                              result_pair=result_pair):
        work = directory / name
        work.mkdir()
        mutant = work / f"{plan.name}.asm"
        mutant.write_text(contents, encoding="utf-8")
        item = {"operator": name, "source_sha256": sha256_file(mutant), "commands": [], "probes": [],
                "killed": False}
        record["operators"].append(item)
        objects, item["candidate"] = assemble_candidate(plan.name, mutant, work / "candidate", item["commands"])
        binary = link_checks(plan, "gcc", test_objects, objects, work / "checks", item["commands"])
        item["binary_sha256"] = sha256_file(binary)
        modes = ("unit", "differential") if plan.guard_skip else ("guard", "unit", "differential")
        for mode in modes:
            result = probe(plan, binary, mode, oracle)
            item["probes"].append(result)
            if result["outcome"] == "fail":
                item["killed"] = True
                break
            if result["outcome"] != "pass":
                raise GateError(f"{name}: unclassified {mode} result in mutation campaign")
    total = len(record["operators"])
    killed = sum(item["killed"] for item in record["operators"])
    record.update(total=total, killed=killed, threshold_percent=90)
    if total == 0 or 100 * killed < 90 * total:
        raise GateError(f"{plan.name}: mutation campaign killed {killed}/{total}, below 90%")
    record["outcome"] = "pass"
    print(f"PASS {plan.name} mutation {killed}/{total} killed", flush=True)


def dependency_evidence(dependencies, inputs_snapshot):
    result = {"outcome": "pass", "dependencies": {}}
    for name, source in dependencies.items():
        path = BUILD / "evidence" / f"{name}.production.json"
        item = {"source": source, "outcome": "pending"}
        result["dependencies"][name] = item
        try:
            record = json.loads(path.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            record = {}
        if type(record) is not dict or type(record.get("checks", {})) is not dict:
            record = {}
        checks = record.get("checks", {})
        candidate = checks.get("candidate_build", {})
        scope = "production-runtime-function" if name == "__errno_location" else "production-function"
        if (record.get("scope") == scope and record.get("function") == name
                and record.get("outcome") == "pass" and record.get("production_verified") is True
                and record.get("inputs") == inputs_snapshot
                and type(candidate) is dict
                and candidate.get("source") == source
                and candidate.get("source_sha256") == inputs_snapshot.get(source)):
            item.update(outcome="pass", evidence=str(path), evidence_sha256=sha256_file(path))
        elif (name in {"__al_strtox", "__al_memcpy_bulk"} and record.get("scope") == "production-private-dependency"
              and record.get("function") == name and record.get("outcome") == "pass"
              and record.get("inputs") == inputs_snapshot
              and record.get("source_sha256") == inputs_snapshot.get(source)
              and record.get("checks", {}).get("branch_coverage", {}).get("outcome") == "pass"
              and record.get("checks", {}).get("production_mutation", {}).get("outcome") == "pass"):
            item.update(outcome="pass", evidence=str(path), evidence_sha256=sha256_file(path))
        else:
            result["outcome"] = "pending"
            item["reason"] = "linked implementation lacks a fresh independent coverage and mutation result"
    return result


def libfuzzer_seconds():
    value = os.environ.get("OPEN_ASSEMBLY_LIBFUZZER_SECONDS", "60")
    if re.fullmatch(r"[0-9]{2,4}", value) is None or not 60 <= int(value) <= 3600:
        raise GateError("OPEN_ASSEMBLY_LIBFUZZER_SECONDS must be an integer from 60 to 3600")
    return int(value)


def run_libfuzzer(plan, objects, directory, record):
    duration = libfuzzer_seconds()
    directory.mkdir()
    log = record["commands"]
    if not plan.fuzz_sources:
        record.update(outcome="pending", reason="independent libFuzzer source is pending")
        return
    fixture_objects = []
    refs = set()
    host_flag = ("-DTEST_FUZZ_HOST=1",) if plan.fuzz_host else ()
    for index, source in enumerate(plan.fuzz_sources):
        path = directory / f"fuzz-{index}.o"
        if source.suffix == ".c":
            checked(log, ["al-clang", *COMPILE_FLAGS, *plan.defines, "-DTEST_LIBFUZZER=1",
                          *host_flag, "-fsanitize=fuzzer-no-link", "-c", source, "-o", path])
            checked(log, ["tools/elf-audit", "--test-object", path])
            refs.update(nm_symbols(log, path, ["-g", "-u"]))
        else:
            checked(log, [*NASM, "-o", path, source])
            checked(log, ["tools/elf-audit", "--assembly-object", path])
        fixture_objects.append(path)
    required = {candidate_symbol(plan.name)} | (set(plan.host_symbols) if plan.fuzz_host else set())
    if required - refs:
        raise GateError(f"{plan.name}: libFuzzer fixture lacks required references {sorted(required - refs)}")
    binary = directory / "libfuzzer"
    checked(log, ["al-clang", "-no-pie", "-fsanitize=fuzzer", "-o", binary,
                  *fixture_objects, *objects], timeout=60)
    checked(log, ["tools/elf-audit", "--hosted-test", binary])
    defined = nm_symbols(log, binary, ["-g", "--defined-only"])
    if not {"LLVMFuzzerTestOneInput", candidate_symbol(plan.name)} <= defined.keys():
        raise GateError("libFuzzer executable is missing fixture or candidate entry")
    record["artifacts"] = {path.name: sha256_file(path) for path in (binary, *fixture_objects)}
    stdout = checked(log, [binary, "-seed=1634488114", f"-max_total_time={duration}", "-max_len=8192",
                           "-print_final_stats=1"], timeout=duration + 30)
    done = re.search(r"(?m)^Done ([1-9][0-9]*) runs in (\d+) second\(s\)$", log[-1]["stderr"])
    if stdout or done is None or int(done[2]) < duration:
        raise GateError(f"{plan.name}: libFuzzer did not report the required completed execution")
    record.update(outcome="pass", requested_seconds=duration, elapsed_seconds=int(done[2]), runs=int(done[1]),
                  seed=1634488114)
    if plan.fuzz_host:
        record["differential_oracle"] = "diff:glibc"
    print(f"PASS {plan.name} {duration}-second libFuzzer campaign", flush=True)


def run_external(plan, candidate, stub, directory, record):
    log = record["commands"]
    names = SUITE_CASES.get(plan.name, ())
    if not names:
        record.update(outcome="not_applicable", reason="no mapped libc-test functional case at this pin")
        return
    package = os.environ.get("OPEN_ASSEMBLY_LIBC_TEST")
    if not package:
        raise GateError("missing pinned libc-test source path")
    root = Path(package)
    directory.mkdir()
    flags = [flag for flag in COMPILE_FLAGS if flag not in ("-Wall", "-Wextra", "-Werror")]
    support = []
    license_file = root / "COPYRIGHT"
    if "licensed under the following standard MIT license" not in license_file.read_text(encoding="utf-8"):
        raise GateError("unexpected libc-test licensing metadata at selected pin")
    record["license_sha256"] = sha256_file(license_file)
    record["support"] = {}
    for helper in ("print", "rand") if plan.name == "qsort" else ("print",):
        source = root / f"src/common/{helper}.c"
        obj = directory / f"{helper}.o"
        checked(log, ["musl-gcc", *flags, "-c", source, "-o", obj])
        checked(log, ["tools/elf-audit", "--test-object", obj])
        record["support"][helper] = sha256_file(source)
        support.append(obj)
    for name in names:
        source = root / f"src/functional/{name}.c"
        obj = directory / f"{name}.o"
        binary = directory / name
        item = {"source": str(source), "source_sha256": sha256_file(source), "outcome": "fail"}
        record["cases"][name] = item
        target = candidate_symbol(plan.name)
        checked(log, ["musl-gcc", *flags, "-I", root / "src/common",
                      f"-D{plan.name}={target}", "-c", source, "-o", obj])
        checked(log, ["tools/elf-audit", "--test-object", obj])
        if nm_symbols(log, obj, ["-g", "-u"]).get(target) != "U":
            raise GateError(f"libc-test {name} does not exercise the candidate {plan.name}")
        checked(log, ["musl-gcc", *LINK_FLAGS, "-o", binary, obj, *support, *candidate])
        checked(log, ["tools/elf-audit", binary])
        if nm_symbols(log, binary, ["-g", "--defined-only"]).get(target) != "T":
            raise GateError(f"libc-test {name} is missing linked {plan.name}")
        checked(log, [binary], timeout=60)
        item["artifacts"] = {path.name: sha256_file(path) for path in (obj, binary)}
        item["outcome"] = "pass"
        print(f"PASS {plan.name} libc-test {name}", flush=True)
        if plan.name == "strlen":
            stub_binary = directory / f"{name}-stub"
            checked(log, ["musl-gcc", *LINK_FLAGS, "-o", stub_binary, obj, *support, *stub])
            checked(log, ["tools/elf-audit", stub_binary])
            rejected = run([stub_binary])
            log.append(rejected)
            if (rejected["returncode"] != 1 or
                    not rejected["stdout"].startswith(f"{source}:") or rejected["stderr"]):
                raise GateError(f"libc-test {name} did not reject the generated stub as an oracle mismatch")
            item["stub_outcome"] = "rejected"
    record["outcome"] = "pass"


def production(function, only=None, *, attempt=None):
    scope = "production-function" if only is None else f"production-{only}"
    evidence = {"schema_version": 1, "scope": scope, "function": function, "outcome": "fail",
                "production_verified": False, "checks": {}}
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("objdump", "qemu-x86_64", "musl-gcc", "al-clang")
        evidence["inputs"] = verify_setup(checks, False, snapshot=phase2_inputs)
        project = load_project()
        spec = project.functions.get(function)
        source = source_paths().get(function)
        if spec is None or source is None:
            raise GateError(f"{function}: no production assembly matching a function specification")
        plan = read_plan(function)
        workspace = BUILD / "production"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix=f"{function}-") as temp:
            directory = Path(temp).resolve().relative_to(ROOT)
            candidate_check = {"outcome": "fail", "commands": []}
            checks["candidate_build"] = candidate_check
            log = candidate_check["commands"]
            candidate, candidate_info = assemble_candidate(function, source, directory / "candidate", log)
            objects = build_checks(plan, "gcc", directory / "glibc", log)
            binary = link_checks(plan, "gcc", objects, candidate, directory / "glibc" / "checks", log)
            oracle = legacy_oracle("gcc", directory, log) if plan.legacy_strlen else None
            candidate_check.update(**candidate_info, outcome="pass", source=str(source),
                                   source_sha256=sha256_file(source), binary_sha256=sha256_file(binary))
            dependencies = dict(candidate_info["dependencies"])
            for name in candidate_info["host_dependencies"]:
                dependencies[name] = str(source_paths()[name])
            if only is None and dependencies:
                checks["dependency_coverage_mutation"] = dependency_evidence(
                    dependencies, evidence["inputs"])

            if only is None:
                behavior = {"outcome": "fail", "probes": [], "oracle": plan.oracle}
                checks["native_oracles"] = behavior
                for mode in MODES:
                    if mode != "guard" or not plan.guard_skip:
                        expect_probe(plan, behavior, binary, mode, oracle, candidate=True)
                behavior["outcome"] = "pass"

                musl = {"outcome": "fail", "probes": [], "commands": []}
                checks["musl_differential"] = musl
                if plan.legacy_strlen:
                    musl_binary = binary
                    musl_oracle = legacy_oracle("musl-gcc", directory, musl["commands"])
                else:
                    musl_directory = directory / "musl"
                    musl_objects = build_checks(plan, "musl-gcc", musl_directory, musl["commands"])
                    musl_binary = link_checks(plan, "musl-gcc", musl_objects, candidate,
                                              musl_directory / "checks", musl["commands"])
                    musl_oracle = None
                expect_probe(plan, musl, musl_binary, "differential", musl_oracle, musl=True, candidate=True)
                if ("diff:musl" in plan.oracle and
                        not musl["probes"][-1]["stdout"].startswith("PASS differential diff:musl ")):
                    raise GateError("musl differential did not name its oracle")
                musl["binary_sha256"] = sha256_file(musl_oracle or musl_binary)
                musl["outcome"] = "pass"

                platform = {"outcome": "fail", "probes": []}
                checks["platform_matrix"] = platform
                mode = "unit" if plan.guard_skip else "guard"
                if function in SCALAR_FUNCTIONS:
                    mode = "differential"
                expect_probe(plan, platform, binary, mode, candidate=True,
                             prefix=("valgrind", "--quiet", "--error-exitcode=99", "--leak-check=full"))
                platform.update(outcome="pass", scope="pinned local native, QEMU user mode, Valgrind")
                if plan.guard_skip:
                    platform["guard_skip"] = plan.guard_skip

            if only in (None, "coverage"):
                checks["branch_coverage"] = {"outcome": "fail", "commands": [], "runs": []}
                verify_coverage(checks["branch_coverage"], directory, binary, function, source,
                                [arguments(plan, mode, oracle) for mode in plan.coverage_modes],
                                require_entry=function in SCALAR_FUNCTIONS)

            stub = None
            if only in (None, "stub"):
                control = {"outcome": "fail", "commands": [], "probes": []}
                checks["generated_stub"] = control
                source_stub = stub_source(spec, directory)
                stub, control["candidate"] = assemble_candidate(function, source_stub, directory / "stub",
                                                                 control["commands"])
                stub_binary = link_checks(plan, "gcc", objects, stub, directory / "stub-checks",
                                          control["commands"])
                expect_probe(plan, control, stub_binary, "abi", oracle)
                modes = ("unit", "differential", "fuzz") if plan.guard_skip else ("unit", "guard", "differential", "fuzz")
                for mode in modes:
                    expect_probe(plan, control, stub_binary, mode, oracle, expected="fail")
                control.update(outcome="pass", source_sha256=sha256_file(source_stub),
                               binary_sha256=sha256_file(stub_binary))

            if only in (None, "mutation"):
                mutation = {"outcome": "fail", "operators": []}
                checks["production_mutation"] = mutation
                mutation_campaign(plan, spec, source, directory / "mutation", objects, oracle, mutation)

            if only is None:
                engine = {"outcome": "fail", "commands": []}
                checks["engine_fuzz"] = engine
                run_libfuzzer(plan, candidate, directory / "engine", engine)
                external = {"outcome": "fail", "commands": [], "cases": {}}
                checks["external_conformance"] = external
                run_external(plan, candidate, stub, directory / "external", external)
        if evidence["inputs"] != phase2_inputs():
            raise GateError("inputs changed during production verification")
        pending = [name for name, check in checks.items() if check["outcome"] == "pending"]
        if pending:
            raise GateError(f"{function}: required checks pending: {', '.join(pending)}")
        if only is None and not REQUIRED_CHECKS <= checks.keys():
            raise GateError("production evidence is missing a required check")
        evidence["outcome"] = "pass"
        evidence["production_verified"] = only is None
    except (GateError, OSError, KeyError, ValueError) as error:
        evidence["error"] = str(error)
        evidence["failure_class"] = "semantic" if isinstance(error, CandidateFailure) else "harness"
        print(f"gate: {error}", file=sys.stderr)
    return finish_function_gate(function, only, evidence, attempt, phase2_inputs)

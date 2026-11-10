"""Run the local per-function gate on an actual Phase 2 candidate."""

from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import sys
import tempfile

from branch_coverage import verify_coverage
from gate import (BUILD, COMPILE_FLAGS, GateError, LINK_FLAGS, checked, identify_tools,
                  inputs, nm_symbols, run, verify_setup, write_evidence)
from lint import JCC
from phase1 import NASM
from spec import (IDENTIFIER, ROOT, comment_header, keys, load_project, matching, read_toml,
                  regular_file, relative_path, sha256_file, snapshot_inputs, string_list,
                  version_one)

MANIFEST = Path("tests/phase2/manifest.toml")
LEGACY_ORACLES = {"gcc": Path("tests/external/strlen_glibc.c"),
                  "musl-gcc": Path("tests/external/strlen_musl.c")}
CANDIDATE_ROOT = Path("src/x86_64-linux")
MODES = ("abi", "unit", "guard", "differential", "fuzz")
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
    "__al_strtox": ("031ddfce2337980c2800c784aa221ddf39a361e8377a1c304b469eed421f9bb0", {
        "comparison-signedness-24": "A negative base still takes .zero_result via the immediately following unsigned upper bound.",
        "comparison-signedness-104": "Bytes below '0' remain invalid. The later unsigned digit/base comparison rejects the negative offset before accumulation.",
        "comparison-signedness-108": "A negative alphabet offset takes .end_digits either here or at the immediately following unsigned upper bound.",
        "comparison-plus-one-109": "The added digit 36 is rejected by the next comparison for every radix from 2 through 36.",
        "comparison-signedness-110": "A negative alphabet offset still reaches .end_digits through the following unsigned digit/base comparison.",
        "comparison-signedness-113": "For a possible digit both the digit and radix have bit 63 clear. A negative offset has already been excluded.",
        "comparison-signedness-119": "The preceding unsigned jump excludes values above the cutoff. The cutoff is at most UINT64_MAX divided by two.",
        "comparison-signedness-121": "Both the digit and remainder are below the radix and have bit 63 clear.",
    }),
    "bsearch": ("8926356d54c6fcadadc308330b7ab3505233037957b45361b01088fd03135ce7", {
        "comparison-signedness-49": "Both indices are bounded by the readable Linux user array.",
    }),
    "memmove": ("0d280e67a9e08a4acfc70222ce1b14e27e7225ccb0a38ed46936db51486ea54f", {
        "comparison-signedness-30": "Valid x86-64 Linux user pointers have bit 63 clear.",
        "comparison-signedness-36": "This path has dest > src. Their difference and the valid object extent have bit 63 clear.",
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
             ("fuzz_sources", "guard_skip"))
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
        names[name] = Plan(name, id_, test_paths(table, "sources", where, required=True),
                           host_symbols, modes, oracle,
                           test_paths(table, "fuzz_sources", where, required=False), skip)
    if function not in names:
        raise GateError(f"{function}: independent production test manifest is pending")
    return names[function]


def phase2_inputs():
    bound = inputs()
    headers = sorted(path.relative_to(ROOT) for path in (ROOT / BUILD / "include/c").rglob("*.h"))
    bound.update(snapshot_inputs(ROOT, headers))
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
            if plan.legacy_strlen:
                flags.extend(("-include", "build/include/c/string.h"))
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
    checked(log, [compiler, *COMPILE_FLAGS, "-include", "build/include/c/string.h",
                  "-c", LEGACY_ORACLES[compiler], "-o", obj])
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


def expect_probe(plan, record, binary, mode, oracle=None, *, expected="pass", **options):
    item = probe(plan, binary, mode, oracle, **options)
    record["probes"].append(item)
    if item["outcome"] != expected:
        detail = (item["stderr"] or item["stdout"]).strip()
        raise GateError(f"{plan.name} {mode}: expected {expected}, got {item['outcome']}. {detail}")
    print((item["stdout"] or item["stderr"]).strip(), flush=True)


def stub_source(spec, directory):
    path = directory / f"{spec.name}.stub.asm"
    path.write_text(comment_header(spec) + f"""
bits 64
default rel
global {spec.name}:function
section .text.{spec.name} progbits alloc exec nowrite
{spec.name}:
    xor eax, eax
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
""", encoding="utf-8")
    return path


def variants(source, *, returns_value=True):
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
        for opcode, name in (("inc", "return-plus-one"), ("dec", "return-minus-one")):
            mutated = [f"    {opcode} rax\n{line}" if re.match(r"^\s*ret\s*(?:;.*)?$", line) else line
                       for line in lines]
            if mutated != lines:
                yield name, "".join(mutated)


def applicable_variants(function, source, record, *, returns_value=True):
    proof_hash, exclusions = MUTATION_EQUIVALENCES.get(function, ("", {}))
    if exclusions and sha256_file(source) != proof_hash:
        raise GateError(f"{function}: source changed since its reviewed mutation equivalence proofs")
    applied_exclusions = set()
    record["equivalent"] = []
    for name, contents in variants(source, returns_value=returns_value):
        if name in exclusions:
            record["equivalent"].append({"operator": name, "source_sha256": proof_hash,
                                         "reason": exclusions[name]})
            applied_exclusions.add(name)
            continue
        yield name, contents
    if applied_exclusions != exclusions.keys():
        raise GateError(f"{function}: mutation equivalence proofs do not match generated operators")


def mutation_campaign(plan, spec, source, directory, test_objects, oracle, record):
    directory.mkdir()
    for name, contents in applicable_variants(
            plan.name, source, record, returns_value=not spec.prototype.startswith("void ")):
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
        candidate = record.get("checks", {}).get("candidate_build", {})
        if (record.get("scope") == "production-function" and record.get("function") == name
                and record.get("outcome") == "pass" and record.get("production_verified") is True
                and record.get("inputs") == inputs_snapshot
                and candidate.get("source") == source
                and candidate.get("source_sha256") == inputs_snapshot.get(source)):
            item.update(outcome="pass", evidence=str(path), evidence_sha256=sha256_file(path))
        elif (name == "__al_strtox" and record.get("scope") == "production-private-dependency"
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


def run_libfuzzer(plan, objects, directory, record):
    directory.mkdir()
    log = record["commands"]
    if not plan.fuzz_sources:
        record.update(outcome="pending", reason="independent libFuzzer source is pending")
        return
    fixture_objects = []
    refs = set()
    for index, source in enumerate(plan.fuzz_sources):
        path = directory / f"fuzz-{index}.o"
        if source.suffix == ".c":
            checked(log, ["al-clang", *COMPILE_FLAGS, *plan.defines, "-DTEST_LIBFUZZER=1",
                          "-fsanitize=fuzzer-no-link", "-c", source, "-o", path])
            checked(log, ["tools/elf-audit", "--test-object", path])
            refs.update(nm_symbols(log, path, ["-g", "-u"]))
        else:
            checked(log, [*NASM, "-o", path, source])
            checked(log, ["tools/elf-audit", "--assembly-object", path])
        fixture_objects.append(path)
    if candidate_symbol(plan.name) not in refs:
        raise GateError(f"{plan.name}: libFuzzer fixture does not reference the candidate")
    binary = directory / "libfuzzer"
    checked(log, ["al-clang", "-no-pie", "-fsanitize=fuzzer", "-o", binary,
                  *fixture_objects, *objects], timeout=60)
    checked(log, ["tools/elf-audit", "--hosted-test", binary])
    defined = nm_symbols(log, binary, ["-g", "--defined-only"])
    if not {"LLVMFuzzerTestOneInput", candidate_symbol(plan.name)} <= defined.keys():
        raise GateError("libFuzzer executable is missing fixture or candidate entry")
    record["artifacts"] = {path.name: sha256_file(path) for path in (binary, *fixture_objects)}
    stdout = checked(log, [binary, "-seed=1634488114", "-max_total_time=60", "-max_len=8192",
                           "-print_final_stats=1"], timeout=90)
    if stdout or not re.search(r"(?m)^Done [1-9][0-9]* runs in \d+ second\(s\)$", log[-1]["stderr"]):
        raise GateError(f"{plan.name}: libFuzzer did not report completed execution")
    record["outcome"] = "pass"
    print(f"PASS {plan.name} 60-second libFuzzer campaign", flush=True)


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


def production(function, only=None):
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
            if only is None and candidate_info["dependencies"]:
                checks["dependency_coverage_mutation"] = dependency_evidence(
                    candidate_info["dependencies"], evidence["inputs"])

            if only in (None, "coverage"):
                checks["branch_coverage"] = {"outcome": "fail", "commands": [], "runs": []}
                verify_coverage(checks["branch_coverage"], directory, binary, function, source,
                                [arguments(plan, mode, oracle) for mode in plan.coverage_modes])
            if only is None:
                behavior = {"outcome": "fail", "probes": [], "oracle": plan.oracle}
                checks["native_oracles"] = behavior
                for mode in MODES:
                    if mode != "guard" or not plan.guard_skip:
                        expect_probe(plan, behavior, binary, mode, oracle)
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
                expect_probe(plan, musl, musl_binary, "differential", musl_oracle, musl=True)
                if ("diff:musl" in plan.oracle and
                        not musl["probes"][-1]["stdout"].startswith("PASS differential diff:musl ")):
                    raise GateError("musl differential did not name its oracle")
                musl["binary_sha256"] = sha256_file(musl_oracle or musl_binary)
                musl["outcome"] = "pass"

                platform = {"outcome": "fail", "probes": []}
                checks["platform_matrix"] = platform
                mode = "unit" if plan.guard_skip else "guard"
                expect_probe(plan, platform, binary, mode,
                             prefix=("valgrind", "--quiet", "--error-exitcode=99", "--leak-check=full"))
                platform.update(outcome="pass", scope="pinned local native, QEMU user mode, Valgrind")
                if plan.guard_skip:
                    platform["guard_skip"] = plan.guard_skip

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
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence(f"{function}.production" if only is None else f"{function}.{only}", evidence)
    print(f"{scope} evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1

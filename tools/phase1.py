"""Build and verify the freestanding Phase 1 runtime."""

from dataclasses import dataclass
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

from gate import (BUILD, COMPILE_FLAGS, GateError, checked, identify_tools, inputs, nm_symbols,
                  run, source_policy, verify_setup, write_evidence)
from lint import PRIVATE_DATA
from spec import (IDENTIFIER, ROOT, SpecError, comment_header, keys, load_project, nasm_name, matching,
                  read_toml, regular_file, relative_path, sha256_file, snapshot_inputs,
                  string_list, version_one)

RUNTIME_SRC = Path("src/x86_64-linux")
STARTUP_SRC = RUNTIME_SRC / "rt/_start.asm"
MANIFEST = Path("tests/runtime/manifest.toml")
BACKENDS = {"native", "qemu", "valgrind"}
RUNTIME_BUILD_TIMEOUT = 180
DEFINED_KINDS = {"T", "B", "D", "R"}
PHASE1_PUBLIC = {"__errno_location", "__stack_chk_fail", "_Exit", "_exit", "atexit",
                 "close", "exit", "read", "write"}
NASM = ("nasm", "-f", "elf64", "-Wall", "-Werror", "-Wno-reloc-rel-dword",
        "-I", "include/asm/")
TEST_C_FLAGS = (*COMPILE_FLAGS, "-fno-asynchronous-unwind-tables", "-fno-unwind-tables",
                "-fstack-protector-explicit", "-I", "build/include/c")
RUNTIME_LINK = ("ld", "-m", "elf_x86_64", "-static", "-no-pie", "-z", "noexecstack",
                "--fatal-warnings", "--no-undefined", "--gc-sections", "-e", "_start")


@dataclass(frozen=True)
class Case:
    name: str
    sources: tuple[Path, ...]
    requires: tuple[str, ...]
    args: list[str]
    env: dict[str, str]
    status: int
    stdout: str
    stderr: str
    oracle: tuple[str, ...]
    backends: tuple[str, ...]
    skip: dict[str, str]


def expected_result(table, where):
    status, stdout, stderr = (table[key] for key in ("status", "stdout", "stderr"))
    if type(status) is not int or not -64 <= status <= 255 or any(
            type(stream) is not str for stream in (stdout, stderr)):
        raise GateError(f"{where}: invalid expected process status or output")
    return status, stdout, stderr


def load_manifest():
    document = read_toml(regular_file(ROOT, MANIFEST, "Phase 1 manifest"))
    keys(document, {"schema", "case", "stub"}, MANIFEST)
    version_one(document["schema"], MANIFEST)
    if type(document["case"]) is not list or not document["case"]:
        raise GateError(f"{MANIFEST} requires a nonempty [[case]] array")
    cases = {}
    fields = set(Case.__dataclass_fields__) - {"skip"}
    for index, table in enumerate(document["case"], 1):
        where = f"{MANIFEST}: case {index}"
        keys(table, fields, where, ("skip",))
        name = matching(table["name"], r"[a-z][a-z0-9-]*", where)
        if name in cases:
            raise GateError(f"{where}: duplicate case {name}")
        sources = tuple(relative_path(path, where) for path in
                        string_list(table["sources"], r".+", where, nonempty=True))
        for source in sources:
            if (source.parts[0] != "tests" or source.suffix not in {".asm", ".c"}) and (
                    source.parts[0] != "apps" or source.suffix != ".asm"):
                raise GateError(f"{where}: unsupported fixture source {source}")
            regular_file(ROOT, source, where)
        requires = string_list(table["requires"], IDENTIFIER, where, nonempty=True)
        oracle = string_list(table["oracle"], r"[a-z][a-z0-9_-]*:[A-Za-z0-9_./+-]+",
                             where, nonempty=True)
        backends = string_list(table["backends"], r"native|qemu|valgrind", where, nonempty=True)
        skip = table.get("skip", {})
        if (type(skip) is not dict or set(skip) != BACKENDS - set(backends)
                or any(type(reason) is not str or not reason.strip() for reason in skip.values())):
            raise GateError(f"{where}: each omitted backend requires a reason in case.skip")
        if (type(table["args"]) is not list or
                any(type(arg) is not str or "\0" in arg for arg in table["args"])):
            raise GateError(f"{where}: args must be an array of argument strings")
        env = table["env"]
        if type(env) is not dict or any(
                not re.fullmatch(IDENTIFIER, key) or type(value) is not str or "\0" in value
                for key, value in env.items()):
            raise GateError(f"{where}: env must map valid environment names to strings")
        status, stdout, stderr = expected_result(table, where)
        cases[name] = Case(name, sources, requires, table["args"], env, status,
                           stdout, stderr, oracle, backends, skip)

    for name, suffix in (("hello-asm", ".asm"), ("hello-c", ".c")):
        case = cases.get(name)
        if (case is None or {source.suffix for source in case.sources} != {suffix}
                or set(case.backends) != BACKENDS or case.status != 0 or not case.stdout.strip()):
            raise GateError(f"{MANIFEST} requires a passing {suffix} {name} on all three backends")
    if set(cases) == {"hello-asm", "hello-c"}:
        raise GateError(f"{MANIFEST} requires independent runtime semantic probes")
    if type(document["stub"]) is not list:
        raise GateError(f"{MANIFEST} requires a [[stub]] control for each public Phase 1 function")
    stubs = {}
    for index, table in enumerate(document["stub"], 1):
        where = f"{MANIFEST}: stub {index}"
        keys(table, {"symbol", "case", "status", "stdout", "stderr"}, where)
        symbol = matching(table["symbol"], IDENTIFIER, where)
        name = matching(table["case"], r"[a-z][a-z0-9-]*", where)
        case = cases.get(name)
        if (symbol not in PHASE1_PUBLIC or symbol in stubs or case is None
                or symbol not in case.requires or "native" not in case.backends):
            raise GateError(f"{where}: expected a unique Phase 1 symbol referenced by its selected case")
        expected = expected_result(table, where)
        if expected == (case.status, case.stdout, case.stderr):
            raise GateError(f"{where}: the stub must fail the selected case's oracle")
        stubs[symbol] = (case, expected)
    if PHASE1_PUBLIC != stubs.keys():
        raise GateError("missing stub controls: " + ", ".join(sorted(PHASE1_PUBLIC - stubs.keys())))
    return cases.values(), stubs


def phase1_inputs():
    bound = inputs()
    headers = sorted((BUILD / "include/c").rglob("*.h"))
    if not headers:
        raise GateError("no generated C test headers")
    bound.update(snapshot_inputs(ROOT, [*headers, Path("docs/adr/0002-runtime-abi.md")]))
    return dict(sorted(bound.items()))


def build_runtime(directory, log):
    checked(log, ["make", "--no-print-directory", "runtime", f"RUNTIME_BUILD={directory}"],
            timeout=RUNTIME_BUILD_TIMEOUT)
    startup = directory / "crt1.o"
    archive = directory / "libopenasm.a"
    sources = sorted(path for path in RUNTIME_SRC.rglob("*.asm") if path != STARTUP_SRC)
    if not sources:
        raise GateError("the runtime library has no source files")
    objects = [directory / "obj" / path.relative_to(RUNTIME_SRC).with_suffix(".o")
               for path in sources]
    members = checked(log, ["ar", "t", archive]).splitlines()
    if members != [obj.name for obj in objects] or len(set(members)) != len(members):
        raise GateError("the archive must contain each runtime object exactly once in source order")
    extracted = directory / "members"
    extracted.mkdir()
    checked(log, ["ar", "x", f"--output={extracted}", archive])
    if any(sha256_file(extracted / obj.name) != sha256_file(obj) for obj in objects):
        raise GateError("an archived member differs from its standalone object")
    checked(log, ["tools/elf-audit", "--assembly-object", startup, *objects])
    exports = {}
    references = {}
    for source, obj in zip([STARTUP_SRC, *sources], [startup, *objects], strict=True):
        defined = nm_symbols(log, obj, ["-g", "--defined-only"])
        runtime_path = source.relative_to(RUNTIME_SRC).with_suffix("").as_posix()
        if ({name for name, kind in defined.items() if kind == "T"} != {source.stem}
                or any(PRIVATE_DATA.get(name) != runtime_path for name in defined if name != source.stem)
                or any(kind not in DEFINED_KINDS for kind in defined.values())):
            raise GateError(f"{obj} must export the text symbol {source.stem} and only modeled data")
        if exports.keys() & defined.keys():
            raise GateError(f"{obj} defines a runtime symbol exported by another object")
        exports.update(defined)
        undefined = nm_symbols(log, obj, ["-g", "-u"])
        if any(kind != "U" for kind in undefined.values()):
            raise GateError(f"{obj} contains a non-strong runtime reference")
        references[obj] = set(undefined)
    for obj, undefined in references.items():
        unresolved = undefined - exports.keys() - ({"main"} if obj == startup else set())
        if unresolved:
            raise GateError(f"{obj} references unknown symbols: {', '.join(sorted(unresolved))}")
    if "main" not in references[startup]:
        raise GateError("runtime startup must reference application main")
    hashes = {path.relative_to(directory).as_posix(): sha256_file(path)
              for path in (startup, archive, *objects)}
    return startup, archive, exports, hashes


def build_case(case, directory, runtime, log, stub=None, *, link_wraps=(), candidate=None,
               c_include=(), c_flags=()):
    startup, archive, exports, _ = runtime
    directory.mkdir()
    objects = []
    references = set()
    for index, source in enumerate(case.sources):
        obj = directory / f"test-{index}.o"
        if source.suffix == ".c":
            include = [argument for path in c_include for argument in ("-I", path)]
            checked(log, ["gcc", *TEST_C_FLAGS, *include, *c_flags, "-c", source, "-o", obj])
            audit = "--test-object"
        else:
            checked(log, [*NASM, "-o", obj, source])
            audit = "--assembly-object"
        checked(log, ["tools/elf-audit", audit, obj])
        references.update(name for name, kind in nm_symbols(log, obj, ["-g", "-u"]).items() if kind == "U")
        objects.append(obj)
    for symbol in case.requires:
        if symbol not in references or symbol not in exports:
            raise GateError(f"{case.name}: test objects do not reference runtime symbol {symbol}")
    test_definitions = {}
    for obj in objects:
        defined = nm_symbols(log, obj, ["-g", "--defined-only"])
        overridden = exports.keys() & defined.keys()
        if overridden:
            raise GateError(f"{case.name}: test object defines runtime symbols {', '.join(sorted(overridden))}")
        test_definitions.update(defined)
    binary = directory / case.name
    wrap_options = []
    for wrapped in link_wraps:
        if (exports.get(wrapped) != "T" or test_definitions.get(f"__wrap_{wrapped}") != "T"
                or f"__real_{wrapped}" not in references or (stub and stub[0] == wrapped)):
            raise GateError(f"{case.name}: missing real runtime call or test wrapper for {wrapped}")
        wrap_options.append(f"--wrap={wrapped}")
    symbol = wrapper = None
    if stub:
        symbol, obj = stub
        wrapper = f"__wrap_{symbol}"
        wrap_options.append(f"--wrap={symbol}")
        objects.append(obj)
    if candidate:
        name, obj = candidate
        if (stub or name not in case.requires or exports.get(name) != "T"
                or nm_symbols(log, obj, ["-g", "--defined-only"]) != {name: "T"}):
            raise GateError(f"{case.name}: debug or mutant object does not replace a required function")
        wrap_options.append(f"--unique=.text.{name}")
        objects.append(obj)
    checked(log, [*RUNTIME_LINK, *wrap_options, "-o", binary, startup, *objects, archive])
    checked(log, ["tools/elf-audit", binary])
    defined = nm_symbols(log, binary, ["-g", "--defined-only"])
    if defined.get("_start") != "T" or defined.get("main") != "T":
        raise GateError(f"{case.name}: executable is missing _start or main")
    for wrapped in link_wraps:
        if defined.get(wrapped) != "T" or defined.get(f"__wrap_{wrapped}") != "T":
            raise GateError(f"{case.name}: executable is missing real and wrapped symbols for {wrapped}")
    for symbol in case.requires:
        target = wrapper if stub and symbol == stub[0] else symbol
        if defined.get(target) != exports[symbol]:
            raise GateError(f"{case.name}: executable does not define runtime symbol {symbol}")
    return binary, {path.name: sha256_file(path) for path in (binary, *objects)}


def generate_stub(spec, directory, log):
    source = directory / f"{spec.name}.asm"
    obj = directory / f"{spec.name}.o"
    wrapped = directory / f"{spec.name}.wrapped.o"
    result_type = spec.prototype.split("(", 1)[0].removesuffix(spec.name).strip()
    if spec.abi.noreturn:
        external = "extern __al_syscall:function\n"
        body = """    sub rsp, 8
    mov qword [rsp], 0
    mov edi, 231
    xor esi, esi
    xor edx, edx
    xor ecx, ecx
    xor r8d, r8d
    xor r9d, r9d
    call __al_syscall
    ud2
"""
    elif result_type == "long double _Complex":
        external = ""
        body = "    fldz\n    fldz\n    ret\n"
    elif result_type == "double _Complex":
        external = ""
        body = "    pxor xmm0, xmm0\n    pxor xmm1, xmm1\n    ret\n"
    elif result_type == "long double":
        external = ""
        body = "    fldz\n    ret\n"
    elif result_type in {"float", "double", "float _Complex"}:
        external = ""
        body = "    pxor xmm0, xmm0\n    ret\n"
    else:
        external = ""
        body = "    xor eax, eax\n    ret\n"
    symbol = nasm_name(spec.name)
    source.write_text(comment_header(spec) + f"""
bits 64
default rel
global {symbol}:function
{external}
section .text.{spec.name} progbits alloc exec nowrite
{symbol}:
{body}
section .note.GNU-stack noalloc noexec nowrite progbits
""", encoding="utf-8")
    checked(log, ["tools/lint", "--function", spec.name, source])
    checked(log, [*NASM, "-o", obj, source])
    wrapper = f"__wrap_{spec.name}"
    checked(log, ["objcopy", "--redefine-sym", f"{spec.name}={wrapper}", obj, wrapped])
    checked(log, ["tools/elf-audit", "--assembly-object", obj, wrapped])
    if nm_symbols(log, wrapped, ["-g", "--defined-only"]) != {wrapper: "T"}:
        raise GateError(f"generated stub for {spec.name} does not define {wrapper}")
    return wrapped, sha256_file(source)


def check_stubs(controls, directory, runtime, record):
    project = load_project()
    for symbol, (case, expected) in controls.items():
        item = {"outcome": "fail", "case": case.name, "oracle": case.oracle,
                "expected_rejection": expected, "commands": []}
        record["symbols"][symbol] = item
        work = directory / f"stub-{symbol}"
        work.mkdir()
        obj, item["source_sha256"] = generate_stub(project.functions[symbol], work, item["commands"])
        binary, item["artifacts"] = build_case(case, work / "probe", runtime, item["commands"],
                                                (symbol, obj))
        result = run([binary, *case.args], environment=case.env)
        item["run"] = result
        observed = (result["returncode"], result["stdout"], result["stderr"])
        if observed != expected:
            raise GateError(f"{symbol} stub in {case.name}: expected rejection {expected!r}, got {observed!r}")
        item["outcome"] = "pass"
        print(f"PASS {case.name} rejected generated {symbol} stub", flush=True)
    record["outcome"] = "pass"


def execute_case(case, binary, record):
    runners = {
        "native": [],
        "qemu": [shutil.which("qemu-x86_64")],
        "valgrind": [shutil.which("valgrind"), "--quiet", "--error-exitcode=99",
                     "--leak-check=full", "--errors-for-leak-kinds=all"],
    }
    for backend in case.backends:
        result = run([*runners[backend], binary, *case.args], environment=case.env, timeout=60)
        observed = (result["returncode"], result["stdout"], result["stderr"])
        expected = (case.status, case.stdout, case.stderr)
        outcome = "pass" if observed == expected else "fail"
        record["runs"][backend] = {**result, "outcome": outcome}
        if outcome != "pass":
            raise GateError(f"{case.name} under {backend}: expected {expected!r}, got {observed!r}")
        print(f"PASS {case.name} {backend} ({', '.join(case.oracle)})", flush=True)


def execute_phase1():
    evidence = {
        "schema_version": 1, "scope": "phase1", "production_verified": False, "outcome": "fail",
        "platform": {key: getattr(os.uname(), key) for key in ("sysname", "release", "machine")},
        "checks": {},
    }
    checks = evidence["checks"]
    try:
        evidence["toolchain"] = identify_tools("ar", "make", "qemu-x86_64")
        evidence["inputs"] = verify_setup(checks, False, snapshot=phase1_inputs)
        cases, controls = load_manifest()
        workspace = BUILD / "phase1"
        workspace.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(dir=workspace, prefix="run-") as temp:
            directory = Path(temp).resolve().relative_to(ROOT)
            source_policy(checks, directory)
            runtime = {"outcome": "fail", "commands": []}
            checks["runtime_build"] = runtime
            first = build_runtime(directory / "first", runtime["commands"])
            second = build_runtime(directory / "second", runtime["commands"])
            runtime["artifacts"] = {"first": first[3], "second": second[3]}
            if first[3] != second[3]:
                raise GateError("two isolated runtime builds produced different artifacts")
            runtime.update(outcome="pass", reproducible=True)
            print(f"PASS reproducible runtime build ({len(first[3]) - 2} archive members)", flush=True)

            for case in cases:
                record = {
                    "outcome": "fail", "commands": [], "runs": {}, "skipped_backends": case.skip,
                    "oracle": case.oracle, "required_symbols": case.requires,
                    "expected": {"status": case.status, "stdout": case.stdout, "stderr": case.stderr},
                    "environment": case.env,
                }
                checks[case.name] = record
                binary, first_hashes = build_case(case, directory / case.name, first, record["commands"])
                _, second_hashes = build_case(case, directory / (case.name + "-second"), second,
                                             record["commands"])
                record["artifacts"] = {"first": first_hashes, "second": second_hashes}
                if first_hashes != second_hashes:
                    raise GateError(f"{case.name}: two isolated builds produced different artifacts")
                execute_case(case, binary, record)
                record["outcome"] = "pass"
            checks["stub_controls"] = {"outcome": "fail", "symbols": {}}
            check_stubs(controls, directory, first, checks["stub_controls"])
        if evidence["inputs"] != phase1_inputs():
            raise GateError("inputs changed during Phase 1 verification")
        evidence["outcome"] = "pass"
    except (GateError, KeyError, OSError, SpecError, ValueError) as error:
        evidence["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    report = write_evidence("phase1", evidence)
    print(f"phase1 evidence: {report}", flush=True)
    return 0 if evidence["outcome"] == "pass" else 1

"""Pinned controls for operation isolation and exact ELF equality."""

from hashlib import sha256
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from campaign import atomic_json, identity
from operation_artifacts import BINARY_OPERATIONS, build_probe, compare_probes
from gate import GateError, checked, identify_tools, verify_setup
from phase1 import NASM, TEST_C_FLAGS, build_runtime
from phase5 import mpfr_identity
from phase7_exact import link_fixture
from phase7_transcendental import TESTS, input_snapshot, required_symbols, validate_specs
from spec import ROOT, SpecError, load_project, sha256_file

sys.path.insert(0, str(ROOT / TESTS))
from oracle import MODES, shard
from verify import observe


OPERATIONS = {"exp2": None, "pow": 0x40400000}


def changed_archive(directory, runtime, symbol, log):
    """Assemble a temporary text change outside the product source tree."""
    directory.mkdir()
    source = directory / f"{symbol}.asm"
    original = Path(f"src/x86_64-linux/math/{symbol}.asm").read_text()
    label = f"\n{symbol}:\n"
    if original.count(label) != 1:
        raise GateError(f"cannot seed text change for {symbol}")
    source.write_text(original.replace(label, label + "    nop\n"))
    obj = directory / f"{symbol}.o"
    checked(log, [*NASM, "-o", obj, source])
    checked(log, ["tools/elf-audit", "--assembly-object", obj])
    startup, archive, exports, artifacts = runtime
    altered = directory / archive.name
    shutil.copyfile(archive, altered)
    checked(log, ["ar", "rD", altered, obj])
    if sha256_file(altered) == sha256_file(archive):
        raise GateError(f"the seeded {symbol} archive did not change")
    return startup, altered, exports, artifacts | {archive.name: sha256_file(altered)}


def build_all(directory, runtime, log):
    directory.mkdir()
    obj, binary = directory / "trans-f32.o", directory / "trans-f32"
    checked(log, ["gcc", *TEST_C_FLAGS, "-DTEST_FORMAT=32", "-c", TESTS / "probe.c", "-o", obj])
    link_fixture(log, binary, obj, runtime, required_symbols(32))
    return binary


def oracle_profile():
    sources = (TESTS / "oracle.py", TESTS / "verify.py", TESTS / "operations.def",
               TESTS.parent / "math_vectors.py", TESTS.parent / "operations.def", Path("tests/phase5/vectors.py"))
    mpfr = mpfr_identity()
    del mpfr["commands"]
    return {"backend": "python-mpfr", "sources": {str(path): sha256_file(path) for path in sources},
            "python_sha256": sha256_file(Path(sys.executable).resolve()), "mpfr": mpfr}


def reject(reason, origin, current, oracle, *, current_oracle=None):
    try:
        compare_probes(origin, current, origin_oracle=oracle,
                       current_oracle=oracle if current_oracle is None else current_oracle)
    except (GateError, SpecError) as error:
        if reason in str(error):
            return str(error)
        raise
    raise GateError(f"expected rejection: {reason}")


def execute(work, report):
    checks, log = report["checks"], report["commands"]
    validate_specs(load_project())
    inputs = verify_setup(checks, False, snapshot=input_snapshot)
    report["inputs"] = inputs
    report["source_snapshot_sha256"] = identity(inputs)
    report["toolchain"] = identify_tools("ar", "make", "qemu-x86_64")
    oracle = oracle_profile()
    old = build_runtime(work / "old", log)
    replay = build_runtime(work / "replay", log)
    if old[3] != replay[3]:
        raise GateError("isolated runtime builds differ")
    unrelated = changed_archive(work / "unrelated", replay, "lgammaf", log)
    old_all = build_all(work / "old-all", old, log)
    new_all = build_all(work / "unrelated-all", unrelated, log)
    if old_all.read_bytes() == new_all.read_bytes():
        raise GateError("unrelated operation did not change the all-operation ELF")
    checks["legacy_all_operation"] = {"old": sha256_file(old_all), "unrelated_change": sha256_file(new_all)}
    cases = {operation: [row for mode in MODES for start in (0, 0x3f7fffec, 0x7f7ffff0, 0x7f800000)
                         for row in shard(operation, start, 16, mode, second)]
             for operation, second in OPERATIONS.items()}
    for operation, second in OPERATIONS.items():
        item = checks[operation] = {"fixed_second_operand_bits": second}
        origin = build_probe(work / "old-probes" / operation, old, operation, log)
        duplicate = build_probe(work / "replay-probes" / operation, replay, operation, log)
        current = build_probe(work / "unrelated-probes" / operation, unrelated, operation, log)
        item["clean_build_equality"] = compare_probes(origin, duplicate, origin_oracle=oracle, current_oracle=oracle)
        item["unrelated_change_equality"] = compare_probes(origin, current, origin_oracle=oracle, current_oracle=oracle)
        selected = changed_archive(work / f"selected-{operation}", replay, operation + "f", log)
        changed = build_probe(work / "selected-probes" / operation, selected, operation, log)
        item["changed_selected"] = {"probe": changed, "rejection": reject("ELF bytes differ", origin, changed, oracle)}
        item["changed_oracle"] = reject("oracle identities differ", origin, current, oracle,
                                        current_oracle=oracle | {"backend": "seeded-change"})
        item["changed_probe_identity"] = reject("probe bytes differ from their audited identity", origin,
                                               current | {"probe_sha256": "0" * 64}, oracle)
        item["escaping_probe"] = reject("repository-relative path", origin,
                                        current | {"probe": "../outside"}, oracle)
        rows = cases[operation]
        legacy = observe([old_all], rows)
        native = observe([origin["probe"]], rows)
        qemu = observe(["qemu-x86_64", origin["probe"]], rows)
        if not all(row["passed"] for row in (legacy, native, qemu)) or len({
                row["result_sha256"] for row in (legacy, native, qemu)}) != 1:
            raise GateError(f"the specialized {operation} probe disagrees with the MPFR or legacy probe")
        item["packets"] = {"legacy": legacy, "native": native, "qemu": qemu}
        wrong = next(name for name in OPERATIONS if name != operation)
        payload = cases[wrong][0].wire()
        process = subprocess.run([origin["probe"]], input=payload, env={"LC_ALL": "C"}, capture_output=True, timeout=10)
        if (process.returncode, process.stdout, process.stderr) != (3, b"", b""):
            raise GateError(f"the {operation} probe accepted a {wrong} wire operation")
        item["wrong_wire_operation"] = {"operation": wrong, "status": 3,
                                         "request_sha256": sha256(payload).hexdigest()}
        print(f"PASS specialized {operation} {'binary axis' if operation in BINARY_OPERATIONS else 'unary'}", flush=True)
    if input_snapshot() != inputs or oracle_profile() != oracle:
        raise GateError("operation probe inputs changed during the controls")


def main():
    folder = Path("build/operation-probe-controls")
    folder.mkdir(parents=True, exist_ok=True)
    report = {"schema_version": 1, "scope": "operation probe controls", "outcome": "fail",
              "release_credit": 0, "checks": {}, "commands": []}
    try:
        work = Path(tempfile.mkdtemp(dir=folder, prefix="run-")).resolve().relative_to(ROOT)
        execute(work, report)
        report["outcome"] = "pass"
    except (GateError, OSError, SpecError, ValueError, subprocess.SubprocessError) as error:
        report["error"] = str(error)
        print(f"gate: {error}", file=sys.stderr)
    atomic_json(folder / "report.json", report)
    return int(report["outcome"] != "pass")


if __name__ == "__main__":
    raise SystemExit(main())

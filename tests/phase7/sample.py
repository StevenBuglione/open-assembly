"""Run typed math packets against pinned native, QEMU, Memcheck, and hosted binaries."""

import argparse
import hashlib
from itertools import groupby
import json
from pathlib import Path
import re
import shutil
import subprocess
from time import monotonic

import gmpy2
from math_vectors import OP_ID as operation_ids, SEED, describe, hosted_subset, memcheck_subset, samples

KINDS = ("f32", "f64", "f80")


def sha256(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def tool(name):
    path = shutil.which(name)
    if path is None:
        raise RuntimeError(f"pinned runner is missing {name}")
    return Path(path).resolve(strict=True)


def observe(command, cases, bits_only=False):
    data = b"".join(case.wire() for case in cases)
    start = monotonic()
    command = [*map(str, command), *(("b",) if bits_only else ())]
    result = subprocess.run(command, env={"LC_ALL": "C"}, input=data,
                            capture_output=True, timeout=120)
    outcome = result.returncode == 0 and not (result.stdout or result.stderr)
    record = {
        "command": command, "records": len(cases), "status": result.returncode,
        "stdout": result.stdout.decode(errors="replace"), "stderr": result.stderr.decode(errors="replace"),
        "elapsed_seconds": monotonic() - start, "input_sha256": hashlib.sha256(data).hexdigest(),
        "comparison": "result bits and out-parameters" if bits_only else
                      "result bits, out-parameters, errno, exception flags, and control state",
        "passed": outcome,
    }
    if outcome and any(case.expected.result.category in {"zero", "normal", "subnormal"}
                       for case in cases):
        record["finite_max_ulp"] = 0
    if not outcome:
        failed = re.match(r"record (\d+) operation \d+ status \d+", record["stderr"])
        if failed and int(failed[1]) < len(cases):
            record["failed_packet"] = describe(cases[int(failed[1])])
    return record


def symbol(kind, op):
    return op + {"f32": "f", "f64": "", "f80": "l"}[kind]


def stub_case(cases):
    for case in cases:
        expected = case.expected
        if expected.flags or expected.error:
            continue
        if expected.result.low or expected.result.high:
            return case, 20
        if expected.integer or (expected.secondary and
                                (expected.secondary.low or expected.secondary.high)):
            return case, 21
    raise ValueError(f"no zero-stub rejection vector for {cases[0].operation}")


def run_stubs(directory, kind, op, cases):
    name = symbol(kind, op)
    binary = directory / name
    case, expected = stub_case(cases)
    observed = observe([binary], [case])
    expected_error = f"record 0 operation {operation_ids[op]} status {expected}\n"
    observed["passed"] = (observed["status"] == expected and not observed["stdout"] and
                          observed["stderr"] == expected_error)
    observed.update(expected_status=expected, expected_stderr=expected_error,
                    semantic_control=describe(case), executable_sha256=sha256(binary))
    if observed["passed"]:
        observed.pop("failed_packet", None)
    return observed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binaries", type=Path, help="directory of math-f32, math-f64, and math-f80")
    parser.add_argument("report", type=Path)
    parser.add_argument("--hosts", type=Path, help="directory of gcc-math-f32 etc. and musl-gcc equivalents")
    parser.add_argument("--stubs", type=Path, help="directory of candidate executables with one wrapped symbol")
    parser.add_argument("--input", action="append", type=Path, default=[], help="additional frozen build inputs")
    args = parser.parse_args()

    native = {kind: (args.binaries / f"math-{kind}").resolve(strict=True) for kind in KINDS}
    hosts = ({kind: {compiler: (args.hosts / f"{compiler}-math-{kind}").resolve(strict=True)
                     for compiler in ("gcc", "musl-gcc")} for kind in KINDS} if args.hosts else {})
    qemu = tool("qemu-x86_64")
    valgrind = tool("valgrind")
    test_directory = Path(__file__).resolve().parent
    files = [*native.values(), *(path for binaries in hosts.values() for path in binaries.values()),
             qemu, valgrind, test_directory / "sample.py", test_directory / "math_packet.c",
             test_directory / "math_vectors.py", test_directory / "operations.def",
             test_directory.parent / "phase5" / "fp_machine.h",
             test_directory.parent / "phase5" / "vectors.py", *args.input]
    if args.stubs:
        files.extend(args.stubs / symbol(kind, op) for kind in KINDS for op in operation_ids
                     if op not in {"classify", "compare"})
    hashes = {str(path): sha256(path) for path in files}
    report = {
        "schema": 1, "scope": "sampled Phase 7 exact mathematics", "seed": SEED,
        "mpfr": {"version": gmpy2.mpfr_version(), "gmpy2": gmpy2.version()},
        "sha256": hashes, "results": {}, "generated_stub_rejections": {},
        "limitations": {
            "valgrind": "Nearest finite binary32/64 common-domain packets use result and out-parameter checks. "
                        "Extended precision and raw control/status observation are covered natively and in QEMU.",
            "hosts": "Hosted packets cover the shared exact finite domain and canonical empty-tag NaN. "
                     "C17 permits different remquo quotient bit widths, signed-zero tie selection for min/max, "
                     "and approximation error in cbrt. Hosted cbrt is limited to nearest and small shared exact cubes.",
            "exhaustive": "Full binary32 coverage is recorded by separate exhaustive.py reports.",
        },
    }

    passed = True
    for kind, exe in native.items():
        results = report["results"][kind] = {}
        for op, group in groupby(samples(kind), key=lambda case: case.operation):
            cases = list(group)
            records = {
                "native": observe([exe], cases),
                "qemu": observe([qemu, exe], cases),
            }
            selected = [case for case in cases if memcheck_subset(kind, case)]
            if selected:
                records["valgrind"] = observe([valgrind, "--quiet", "--error-exitcode=99",
                                               "--leak-check=full", "--errors-for-leak-kinds=all", exe],
                                              selected, bits_only=True)
            if kind in hosts:
                common = [case for case in cases if hosted_subset(case)]
                records.update({compiler: observe([path], common, bits_only=True)
                                for compiler, path in hosts[kind].items()})
            results[op] = records
            passed &= all(item["passed"] for item in records.values())
            if args.stubs and op not in {"classify", "compare"}:
                item = run_stubs(args.stubs, kind, op, cases)
                report["generated_stub_rejections"][symbol(kind, op)] = item
                passed &= item["passed"]
            print(kind, op, " ".join(f"{key}={'pass' if row['passed'] else 'fail'}"
                                    for key, row in records.items()), flush=True)
    report["inputs_frozen"] = all(sha256(path) == hashes[str(path)] for path in files)
    report["passed"] = passed and report["inputs_frozen"]
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(f"sampled evidence: {args.report}", flush=True)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

"""Measure sampled transcendental results in target-representation ULPs."""

import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
from time import monotonic

import gmpy2
from oracle import (BINARY, CHANGED_CONTROL, MODES, NEAREST, OBSERVATION, OPERATIONS, SEED, TEST_ERRNO,
                    Number, bits, cases, ordinal, shard)

KINDS = ("f32", "f64", "f80")
SUFFIX = {"f32": "f", "f64": "", "f80": "l"}


def sha256(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def executable(path):
    return Path(path).resolve(strict=True)


def tool(name):
    path = shutil.which(name)
    if path is None:
        raise RuntimeError(f"missing pinned executable {name}")
    return executable(path)


def canonical(result):
    if result.fmt.bits == 80:
        return bool(result.low >> 63) == bool(result.field)
    return not result.high and result.low >> result.fmt.bits == 0


def compare(case, actual, check_environment):
    expected = case.expected
    low, high, flags, error = actual
    result = Number(expected.result.fmt, low, high)
    if not canonical(result):
        return None, ["noncanonical representation"]
    exact = result == expected.result
    wanted_class = expected.result.category
    finite = {"normal", "subnormal", "zero"}
    distance = None
    if result.category in finite and wanted_class in finite:
        distance = abs(ordinal(result) - ordinal(expected.result))
    failures = []
    if expected.policy == "quiet-nan":
        if result.category != "quiet":
            failures.append("domain result is not a quiet NaN")
    elif expected.policy == "exact":
        if not exact:
            failures.append("exact representation")
    elif expected.policy == "ulp":
        if (result.category != wanted_class or result.negative != expected.result.negative or
                distance is None or distance > 1):
            failures.append("one-ULP bound, sign, or result class")
    else:
        raise ValueError(f"unknown policy {expected.policy}")
    if check_environment:
        if flags & CHANGED_CONTROL:
            failures.append("changed control state")
        if (flags & ~CHANGED_CONTROL) != (expected.flags | case.seed):
            failures.append("exception flags")
        if error != (expected.error or TEST_ERRNO):
            failures.append("errno")
    return distance, failures


def observe(command, rows, check_environment=True, max_failures=12):
    data = b"".join(row.wire() for row in rows)
    before = monotonic()
    command = list(map(str, command))
    process = subprocess.run(command, env={"LC_ALL": "C"}, input=data,
                             capture_output=True, timeout=180)
    report = {
        "command": command, "status": process.returncode,
        "stderr": process.stderr.decode(errors="replace"), "records": len(rows),
        "flags_errno_controls_checked": check_environment, "input_sha256": hashlib.sha256(data).hexdigest(),
        "result_sha256": hashlib.sha256(process.stdout).hexdigest(),
        "elapsed_seconds": monotonic() - before, "strata": dict(Counter(row.label for row in rows)),
    }
    if process.returncode or process.stderr or len(process.stdout) != len(rows) * OBSERVATION.size:
        report.update(passed=False, observed_result_bytes=len(process.stdout), error="probe transport")
        return report

    maxima = {}
    checked_distances = 0
    samples = []
    failures_by_reason = Counter()
    for case, actual in zip(rows, OBSERVATION.iter_unpack(process.stdout), strict=True):
        distance, failures = compare(case, actual, check_environment)
        low, high, flags, error = actual
        if distance is not None:
            checked_distances += 1
            current = maxima.get(case.mode)
            if current is None or distance > current["distance"]:
                maxima[case.mode] = {"distance": distance, **case.description(),
                                     "actual": f"{high:04x}:{low:016x}"}
        if failures:
            failures_by_reason.update(failures)
            if len(samples) < max_failures:
                samples.append({**case.description(), "actual": f"{high:04x}:{low:016x}",
                                "actual_flags": flags, "actual_errno": error, "failures": failures,
                                "distance": distance})
    report.update(passed=not failures_by_reason, finite_distances=checked_distances,
                  max_finite_ulp=max((item["distance"] for item in maxima.values()), default=None),
                  maxima_by_mode=maxima, failures_by_reason=dict(failures_by_reason), failures=samples)
    return report


def applicable_shared(row):
    return (row.mode == NEAREST and row.argument.category in {"normal", "zero"} and
            row.expected.result.category in {"normal", "zero"} and row.expected.error == 0 and
            (row.operand is None or row.operand.category in {"normal", "zero"}))


def stub_check(binary, rows):
    # Choose a nonzero valid ordinary result. Require an attributable observation,
    # including correct transport, rather than accepting a crash or a build error.
    row = next(case for case in rows if case.expected.result.category == "normal" and
               case.expected.error == 0 and case.argument.category == "normal")
    observed = observe([binary], [row], check_environment=False)
    recorded = observed.get("failures", [])
    rejected = (observed["status"] == 0 and len(recorded) == 1 and
                recorded[0]["actual"] == "0000:0000000000000000" and
                bool(recorded[0]["failures"]))
    observed["stub_rejected"] = rejected
    return observed


def write_report(path, report):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binaries", type=Path, help="directory containing trans-f32/f64/f80")
    parser.add_argument("report", type=Path)
    parser.add_argument("--hosts", type=Path, help="directory containing pinned glibc and musl probe binaries")
    parser.add_argument("--stubs", type=Path, help="directory of typed generated zero-stub executables")
    parser.add_argument("--input", action="append", type=Path, default=[])
    parser.add_argument("--random", type=int, default=192)
    parser.add_argument("--second", type=lambda text: int(text, 0), help="fixed second operand binary32 bits")
    parser.add_argument("--shard", nargs=4, metavar=("OP", "START", "COUNT", "MODE"))
    args = parser.parse_args()
    if args.random < 0:
        parser.error("--random must be nonnegative")
    if args.second is not None and (not args.shard or args.shard[0] not in BINARY):
        parser.error("--second applies only to binary-operation shards")
    fixture_dir = Path(__file__).resolve().parent
    test_inputs = [*sorted(fixture_dir.glob("*.py")), fixture_dir / "probe.c", fixture_dir / "operations.def",
                   fixture_dir.parent / "math_vectors.py", fixture_dir.parent / "operations.def",
                   fixture_dir.parents[1] / "phase5" / "fp_machine.h",
                   fixture_dir.parents[1] / "phase5" / "vectors.py", *args.input]
    report = {
        "schema": 1, "scope": "sampled Phase 7 transcendental verification", "seed": SEED,
        "mpfr": {"version": gmpy2.mpfr_version(), "gmpy2": gmpy2.version()},
        "ulp_definition": "Integer count of adjacent target-format finite encodings between observed "
                          "and correctly rounded MPFR results in the selected mode. "
                          "Result sign and class are checked separately.",
        "results": {}, "generated_stub_rejections": {},
        "limitations": {
            "valgrind": "Nearest normal/zero binary32 and binary64 shared-domain values. "
                        "Full errno, flags, directed rounding, and x87 extended are checked in native/QEMU.",
            "host": "Nearest normal/zero shared domain measured independently. The project accuracy "
                    "gate is relative to MPFR. Host differences are recorded for comparison.",
        },
    }
    if args.shard:
        operation, start, count, mode = args.shard
        try:
            start, count, mode_index = int(start, 0), int(count, 0), int(mode, 0)
        except ValueError as error:
            parser.error(str(error))
        if (operation not in OPERATIONS or
                (operation in BINARY and (args.second is None or not 0 <= args.second < 1 << 32)) or
                not 0 <= start < 1 << 32 or
                not 0 < count <= (1 << 32) - start or not 0 <= mode_index < len(MODES)):
            parser.error("invalid binary32 shard interval or mode")
        candidate = executable(args.binaries / "trans-f32")
        test_inputs.append(candidate)
        frozen = {str(path): sha256(path) for path in test_inputs}
        before = monotonic()
        rows = list(shard(operation, start, count, MODES[mode_index], args.second))
        report["oracle_seconds"] = monotonic() - before
        report.update(scope="consecutive binary32 shard", operation=operation, start=start,
                      count=count, mode_index=mode_index, second_bits=args.second, backend="native")
        report["results"]["native"] = result = observe([candidate], rows)
        passed = result["passed"]
        print(f"{operation} {start:#010x}+{count} mode={mode_index}: "
              f"max ULP={result.get('max_finite_ulp')}, "
              f"MPFR {report['oracle_seconds']:.3f}s, candidate {result['elapsed_seconds']:.3f}s", flush=True)
    else:
        native = {kind: executable(args.binaries / f"trans-{kind}") for kind in KINDS}
        hosts = ({kind: {compiler: executable(args.hosts / f"{compiler}-trans-{kind}")
                         for compiler in ("gcc", "musl-gcc")} for kind in KINDS} if args.hosts else {})
        stubs = ({op + SUFFIX[kind]: executable(args.stubs / (op + SUFFIX[kind]))
                  for kind in KINDS for op in OPERATIONS} if args.stubs else {})
        qemu, valgrind = tool("qemu-x86_64"), tool("valgrind")
        test_inputs += [*native.values(), *stubs.values(), qemu, valgrind,
                        *(path for group in hosts.values() for path in group.values())]
        frozen = {str(path): sha256(path) for path in test_inputs}
        passed = True
        for kind, binary in native.items():
            group = report["results"][kind] = {}
            for operation in OPERATIONS:
                rows = list(cases(kind, operation, args.random))
                runs = group[operation] = {
                    "native": observe([binary], rows),
                    "qemu": observe([qemu, binary], rows),
                }
                common = [row for row in rows if applicable_shared(row)]
                if kind != "f80":
                    runs["valgrind"] = observe([valgrind, "--quiet", "--error-exitcode=99", binary],
                                               common, check_environment=False)
                if hosts:
                    for name, host in hosts[kind].items():
                        runs[name] = observe([host], common, check_environment=False)
                for name in ("native", "qemu", "valgrind"):
                    if name in runs:
                        passed &= runs[name]["passed"]
                if stubs:
                    symbol = operation + SUFFIX[kind]
                    result = report["generated_stub_rejections"][symbol] = stub_check(stubs[symbol], rows)
                    passed &= result["stub_rejected"]
                print(kind, operation, " ".join(f"{name}={'pass' if value['passed'] else 'fail'}"
                                                f"/{value.get('max_finite_ulp')}"
                                                for name, value in runs.items()), flush=True)

    report["sha256"] = frozen
    report["inputs_frozen"] = all(sha256(path) == frozen[str(path)] for path in test_inputs)
    report["passed"] = passed and report["inputs_frozen"]
    write_report(args.report, report)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

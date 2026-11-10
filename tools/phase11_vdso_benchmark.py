"""Measure warmed userspace realtime against pinned musl with raw realtime denied."""

import os
from pathlib import Path
import re
import statistics
import sys
import tempfile

from gate import BUILD, GateError, identify_tools, run, verify_setup, write_evidence
from phase11_copy_benchmark import MAX_SIZE_RATIO, MIN_IDLE, PAIRS, NoQuietCPU, build_benchmarks, quiet_cpu
from production import phase2_inputs
from spec import ROOT, snapshot_inputs

SOURCE = Path("tests/phase11/vdso-bench/benchmark.c")
CALLS = 1000000
CONTRACTS = (Path("docs/adr/0022-vdso-realtime.md"), Path("docs/cookbook/vdso-benchmark.md"))


class NoAcceleratedClock(Exception):
    pass


def inputs():
    return dict(sorted((phase2_inputs() | snapshot_inputs(ROOT, CONTRACTS)).items()))


def check_platform_status(kind, result):
    status = result["returncode"]
    if status in {7, 8} and not result["stdout"] and not result["stderr"]:
        reason = "seccomp setup" if status == 7 else "accelerated realtime after raw denial"
        raise NoAcceleratedClock(f"{kind}: {reason} unavailable")


def qualify(executables, report):
    for kind, binary in executables.items():
        result = run([binary, "qualify"], timeout=15)
        report["qualification"][kind] = result
        check_platform_status(kind, result)
        if (result["returncode"], result["stdout"], result["stderr"]) != (
                0, "PASS realtime through vDSO with raw calls denied\n", ""):
            raise GateError(f"{kind}: vDSO and raw denial qualification failed")
        print(f"PASS {kind} vDSO qualification", flush=True)


def measure(executables, report):
    cpu, original = quiet_cpu(report["native_cpu"])
    samples = {kind: [] for kind in executables}
    report["measurements"] = samples
    os.sched_setaffinity(0, {cpu})
    try:
        for pair in range(PAIRS):
            order = executables if pair % 2 == 0 else reversed(executables)
            for kind in order:
                result = run([executables[kind]], timeout=15)
                report["commands"].append(result)
                status = result["returncode"]
                check_platform_status(kind, result)
                match = re.fullmatch(r"(\d+) (\d+) (\d+)\n", result["stdout"])
                if status or result["stderr"] or match is None:
                    raise GateError(f"{kind}: invalid vDSO sample, status {status}")
                elapsed, cpu_time, calls = map(int, match.groups())
                if not elapsed or not cpu_time or calls != CALLS:
                    raise GateError(f"{kind}: clocks or realtime observations differ")
                samples[kind].append({"pair": pair + 1, "nanoseconds": elapsed,
                                      "cpu_nanoseconds": cpu_time, "valid_calls": calls})
                if elapsed - cpu_time > max(50_000, elapsed * (1 - MIN_IDLE)):
                    raise NoQuietCPU(f"{kind}: scheduler interference in pair {pair + 1}")
    finally:
        os.sched_setaffinity(0, original)
    medians = {kind: statistics.median(row["nanoseconds"] for row in rows) for kind, rows in samples.items()}
    report["median_nanoseconds"] = medians
    report["ratio"] = medians["openasm"] / medians["musl"]
    return report["ratio"] <= MAX_SIZE_RATIO


def main():
    name = "phase11-vdso-benchmark"
    report = {"schema_version": 1, "scope": "phase11-native-warm-vdso-time-benchmark",
              "outcome": "fail", "production_verified": False, "commands": [], "checks": {},
              "native_cpu": {}, "artifacts": {}, "qualification": {}, "measurements": {},
              "workload": {"api": "time(NULL)", "calls_per_sample": CALLS, "pairs": PAIRS,
                           "median_ratio_limit": MAX_SIZE_RATIO, "min_preflight_idle": MIN_IDLE,
                           "raw_denial": {"time": "EACCES", "gettimeofday": "EACCES",
                                          "clock_gettime": "EACCES except MONOTONIC and THREAD_CPUTIME_ID"}}}
    try:
        report["toolchain"] = identify_tools("musl-gcc", "make", "ar")
        report["inputs"] = verify_setup(report["checks"], False, snapshot=inputs)
        with tempfile.TemporaryDirectory(dir=BUILD, prefix="vdso-benchmark-") as workspace:
            directory = Path(workspace).resolve().relative_to(ROOT)
            executables = build_benchmarks(directory, report, source=SOURCE, symbols=("time",),
                                           open_members=("time", "__al_realtime_parts", "__al_vdso_clock_entry"))
            qualify(executables, report)
            passed = measure(executables, report)
        report["outcome"] = "pass" if passed else "fail"
        if not passed:
            report["reason"] = "median exceeds the predeclared musl ratio"
    except (NoQuietCPU, NoAcceleratedClock) as error:
        report.update(outcome="incomplete", reason=str(error))
    except (GateError, OSError, ValueError) as error:
        report.update(outcome="fail", reason=str(error))
    if "inputs" in report and inputs() != report["inputs"]:
        report.update(outcome="fail", reason="benchmark inputs changed during the run")
    path = write_evidence(name, report)
    print(f"{report['outcome'].upper()} vDSO benchmark, evidence at {path}")
    if "reason" in report:
        print(report["reason"], file=sys.stderr)
    return int(report["outcome"] != "pass")


if __name__ == "__main__":
    raise SystemExit(main())

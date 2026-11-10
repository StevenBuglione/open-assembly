"""Compare fixed allocator workloads and resident memory against pinned musl."""

import math
import os
from pathlib import Path
import re
import statistics
import sys
import tempfile

from gate import BUILD, GateError, identify_tools, run, verify_setup, write_evidence
from phase11_copy_benchmark import MAX_GEOMEAN, MAX_SIZE_RATIO, MIN_IDLE, PAIRS, NoQuietCPU, build_benchmarks, quiet_cpu
from production import phase2_inputs
from spec import ROOT, snapshot_inputs

SOURCE = Path("tests/phase11/allocator-bench/benchmark.c")
CONTRACTS = (Path("docs/adr/0036-direct-allocation-remap.md"), Path("docs/cookbook/allocator-benchmark.md"))
SYMBOLS = ("malloc", "realloc", "free")
TIMINGS = ("small", "mixed", "growth")
MAX_EXTRA_RSS_KIB = 8 * 1024


class NoRssSource(Exception):
    pass


def allocator_inputs():
    return dict(sorted((phase2_inputs() | snapshot_inputs(ROOT, CONTRACTS)).items()))


def observe(executables, report, workload):
    samples = {kind: [] for kind in executables}
    row = {"samples": samples}
    report["measurements"][workload] = row
    checksums = set()
    for pair in range(PAIRS):
        order = executables if pair % 2 == 0 else reversed(executables)
        for kind in order:
            result = run([executables[kind], workload], timeout=30)
            report["commands"].append(result)
            label = f"{kind} {workload} pair {pair + 1}"
            if workload == "rss":
                if result["returncode"] == 7 and not result["stdout"] and not result["stderr"]:
                    raise NoRssSource(f"{label}: /proc/self/smaps_rollup Rss unavailable")
                match = re.fullmatch(r"(\d+) (\d+) (\d+) (\d+) (\d+)\n", result["stdout"])
            else:
                match = re.fullmatch(r"(\d+) (\d+) (\d+)\n", result["stdout"])
            if result["returncode"] or result["stderr"] or match is None:
                raise GateError(f"{label}: invalid benchmark result, status {result['returncode']}")
            values = tuple(map(int, match.groups()))
            if workload == "rss":
                baseline, peak, retained, released, checksum = values
                if not min(values[:4]) or peak <= baseline:
                    raise GateError(f"{label}: invalid RSS samples")
                point = {"baseline_kib": baseline, "peak_kib": peak, "retained_kib": retained,
                         "released_kib": released, "retained_delta_kib": retained - baseline,
                         "released_delta_kib": released - baseline}
            else:
                elapsed, cpu_time, checksum = values
                if not elapsed or not cpu_time:
                    raise GateError(f"{label}: benchmark clocks did not advance")
                point = {"nanoseconds": elapsed, "cpu_nanoseconds": cpu_time}
            samples[kind].append({"pair": pair + 1, "checksum": checksum, **point})
            if workload != "rss" and elapsed - cpu_time > max(50_000, elapsed * (1 - MIN_IDLE)):
                raise NoQuietCPU(f"{label}: scheduler interference")
            checksums.add(checksum)
    if len(checksums) != 1:
        raise GateError(f"{workload}: payload checksum mismatch")
    if workload == "rss":
        keys = ("retained_delta_kib", "released_delta_kib")
        medians = {kind: {key: statistics.median(point[key] for point in points) for key in keys}
                   for kind, points in samples.items()}
        deltas = {key: medians["openasm"][key] - medians["musl"][key] for key in keys}
        row.update(medians=medians, openasm_excess_kib=deltas)
        return max(deltas.values()) <= MAX_EXTRA_RSS_KIB
    medians = {kind: statistics.median(point["nanoseconds"] for point in points)
               for kind, points in samples.items()}
    ratio = medians["openasm"] / medians["musl"]
    row.update(median_nanoseconds=medians, ratio=ratio)
    return ratio


def measure(executables, report):
    cpu, original = quiet_cpu(report["native_cpu"])
    os.sched_setaffinity(0, {cpu})
    try:
        ratios = [observe(executables, report, name) for name in TIMINGS]
        rss_pass = observe(executables, report, "rss")
    finally:
        os.sched_setaffinity(0, original)
    geometric_mean = math.exp(statistics.fmean(math.log(ratio) for ratio in ratios))
    report["geometric_mean"] = geometric_mean
    return geometric_mean <= MAX_GEOMEAN and max(ratios) <= MAX_SIZE_RATIO and rss_pass


def main():
    report = {"schema_version": 1, "scope": "phase11-allocator-benchmark",
              "outcome": "fail", "production_verified": False, "commands": [], "checks": {},
              "native_cpu": {}, "artifacts": {}, "measurements": {},
              "workload": {"pairs": PAIRS, "min_preflight_idle": MIN_IDLE,
                           "geometric_mean_limit": MAX_GEOMEAN, "per_workload_limit": MAX_SIZE_RATIO,
                           "max_rss_excess_kib": MAX_EXTRA_RSS_KIB}}
    try:
        report["toolchain"] = identify_tools("musl-gcc", "make", "ar")
        report["inputs"] = verify_setup(report["checks"], False, snapshot=allocator_inputs)
        with tempfile.TemporaryDirectory(dir=BUILD, prefix="allocator-benchmark-") as workspace:
            directory = Path(workspace).resolve().relative_to(ROOT)
            executables = build_benchmarks(directory, report, source=SOURCE, symbols=SYMBOLS,
                                           open_members=(*SYMBOLS, "__al_heap_remap"))
            passed = measure(executables, report)
        report["outcome"] = "pass" if passed else "fail"
        if not passed:
            report["reason"] = "measured timing or resident memory exceeds the predeclared musl margin"
    except (NoQuietCPU, NoRssSource) as error:
        report.update(outcome="incomplete", reason=str(error))
    except (GateError, OSError, ValueError) as error:
        report.update(outcome="fail", reason=str(error))
    if "inputs" in report and allocator_inputs() != report["inputs"]:
        report.update(outcome="fail", reason="benchmark inputs changed during the run")
    path = write_evidence("phase11-allocator-benchmark", report)
    print(f"{report['outcome'].upper()} allocator benchmark, evidence at {path}")
    if "reason" in report:
        print(report["reason"], file=sys.stderr)
    return int(report["outcome"] != "pass")


if __name__ == "__main__":
    raise SystemExit(main())

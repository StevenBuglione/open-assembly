"""Measure the fixed Phase 11 memcpy workload against pinned musl on one native CPU."""

import math
import os
from pathlib import Path
import re
import statistics
import sys
import tempfile
import time

from gate import (BUILD, COMPILE_FLAGS, GateError, LINK_FLAGS, checked, identify_tools,
                  nm_symbols, run, verify_setup, write_evidence)
from production import phase2_inputs
from spec import ROOT, sha256_file

SOURCE = Path("tests/phase11/copy/benchmark.c")
SIZES = (256, 1024, 4096, 65536, 1048576)
PAIRS = 9
BYTES = 128 * 1024 * 1024
MIN_IDLE = 0.90
MAX_GEOMEAN = 1.25
MAX_SIZE_RATIO = 1.50


class NoQuietCPU(Exception):
    pass


def cpu_ticks(allowed):
    result = {}
    for line in Path("/proc/stat").read_text().splitlines():
        name, *fields = line.split()
        if name.startswith("cpu") and name[3:].isdigit() and int(name[3:]) in allowed:
            values = list(map(int, fields[:8]))  # guest time is already included
            result[int(name[3:])] = (sum(values), values[3])
    return result


def quiet_cpu(observation):
    allowed = os.sched_getaffinity(0)
    before = cpu_ticks(allowed)
    time.sleep(1)
    after = cpu_ticks(allowed)
    idle = {}
    for cpu in before.keys() & after.keys():
        elapsed = after[cpu][0] - before[cpu][0]
        if elapsed > 0:
            idle[cpu] = (after[cpu][1] - before[cpu][1]) / elapsed
    observation.update(allowed_cpus=sorted(allowed), idle_fractions=idle, kernel=os.uname().release,
                       cpuinfo_sha256=sha256_file(Path("/proc/cpuinfo")))
    if not idle or max(idle.values()) < MIN_IDLE:
        raise NoQuietCPU(f"no allowed CPU reached {MIN_IDLE:.0%} idle during the preflight")
    cpu = min(idle, key=lambda index: (-idle[index], index))
    observation["cpu"] = cpu
    return cpu, allowed


def build_benchmarks(directory, report):
    log = report["commands"]
    runtime = directory / "runtime"
    checked(log, ["make", "--no-print-directory", "runtime", f"RUNTIME_BUILD={runtime}"], timeout=240)
    startup = runtime / "crt1.o"
    archive = runtime / "libopenasm.a"
    libc = Path(checked(log, ["musl-gcc", "-print-file-name=libc.a"]).strip()).resolve()
    if not libc.is_file() or "musl" not in str(libc):
        raise GateError("musl compiler did not identify its pinned static libc archive")
    report["runtime_artifacts"] = {str(path): sha256_file(path) for path in (startup, archive, libc)}
    executables = {}
    for kind, compiler, includes in (("openasm", "gcc", ("-I", "build/include/c")),
                                     ("musl", "musl-gcc", ())):
        obj = directory / f"benchmark-{kind}.o"
        binary = directory / f"benchmark-{kind}"
        link_map = binary.with_suffix(".map")
        checked(log, [compiler, *COMPILE_FLAGS, "-fno-stack-protector", *includes, "-c", SOURCE, "-o", obj])
        checked(log, ["tools/elf-audit", "--test-object", obj])
        if nm_symbols(log, obj, ["-g", "-u"]).get("memcpy") != "U":
            raise GateError(f"{kind}: compiler eliminated the measured memcpy reference")
        if kind == "openasm":
            checked(log, ["ld", "-static", "-no-pie", "--fatal-warnings", "--gc-sections", "-z", "noexecstack",
                          "-Map", link_map, "-o", binary, startup, obj, archive])
        else:
            checked(log, [compiler, *LINK_FLAGS, f"-Wl,-Map,{link_map}", "-o", binary, obj])
        checked(log, ["tools/elf-audit", binary])
        symbols = nm_symbols(log, binary, ["-g", "--defined-only"])
        map_text = link_map.read_text()
        if symbols.get("memcpy") != "T":
            raise GateError(f"{kind}: missing linked memcpy text symbol")
        if kind == "openasm":
            if (f"{archive}(memcpy.o)" not in map_text or f"{archive}(__al_memcpy_bulk.o)" not in map_text
                    or symbols.get("__al_memcpy_bulk") != "T"):
                raise GateError("linked memcpy does not contain the Open Assembly dispatched implementation")
        else:
            match = re.search(r"(?m)^(\S+/libc\.a)\([^\n]+\)\s+\S*benchmark-musl\.o \(memcpy\)", map_text)
            if match is None or Path(match[1]).resolve() != libc:
                raise GateError("linked memcpy origin was not the pinned musl archive")
        report["artifacts"][kind] = {path.name: sha256_file(path) for path in (obj, binary, link_map)}
        executables[kind] = binary
    return executables


def measure(executables, report):
    cpu, original_affinity = quiet_cpu(report["native_cpu"])
    ratios = []
    os.sched_setaffinity(0, {cpu})
    try:
        for size in SIZES:
            samples = {kind: [] for kind in executables}
            row = {"samples": samples}
            report["measurements"][str(size)] = row
            checksums = set()
            for pair in range(PAIRS):
                order = executables if pair % 2 == 0 else reversed(executables)
                for kind in order:
                    result = run([executables[kind], size], timeout=15)
                    report["commands"].append(result)
                    match = re.fullmatch(r"(\d+) (\d+) (\d+)\n", result["stdout"])
                    if result["returncode"] or result["stderr"] or match is None:
                        raise GateError(f"{kind}: invalid benchmark result for {size} bytes")
                    elapsed, cpu_time, checksum = map(int, match.groups())
                    if not elapsed or not cpu_time:
                        raise GateError(f"{kind}: benchmark clocks did not advance")
                    samples[kind].append({"pair": pair + 1, "nanoseconds": elapsed,
                                          "cpu_nanoseconds": cpu_time, "checksum": checksum})
                    if elapsed - cpu_time > max(50_000, elapsed * (1 - MIN_IDLE)):
                        raise NoQuietCPU(f"{kind}: scheduler interference at {size} bytes in pair {pair + 1}")
                    checksums.add(checksum)
            if len(checksums) != 1:
                raise GateError(f"checksum mismatch at {size} bytes")
            medians = {kind: statistics.median(point["nanoseconds"] for point in points)
                       for kind, points in samples.items()}
            ratio = medians["openasm"] / medians["musl"]
            ratios.append(ratio)
            row.update(median_nanoseconds=medians, ratio=ratio)
    finally:
        os.sched_setaffinity(0, original_affinity)
    report["geometric_mean"] = math.exp(statistics.fmean(math.log(ratio) for ratio in ratios))
    return report["geometric_mean"] <= MAX_GEOMEAN and max(ratios) <= MAX_SIZE_RATIO


def main():
    report = {"schema_version": 1, "scope": "phase11-native-hot-disjoint-memcpy-benchmark",
              "outcome": "fail", "production_verified": False, "commands": [], "checks": {},
              "native_cpu": {}, "artifacts": {}, "measurements": {},
              "workload": {"sizes": SIZES, "bytes_per_sample": BYTES, "pairs_per_size": PAIRS,
                           "min_preflight_idle": MIN_IDLE, "geometric_mean_limit": MAX_GEOMEAN,
                           "per_size_limit": MAX_SIZE_RATIO}}
    try:
        report["toolchain"] = identify_tools("musl-gcc", "make", "ar")
        report["inputs"] = verify_setup(report["checks"], False, snapshot=phase2_inputs)
        with tempfile.TemporaryDirectory(dir=BUILD, prefix="copy-benchmark-") as workspace:
            directory = Path(workspace).resolve().relative_to(ROOT)
            executables = build_benchmarks(directory, report)
            passed = measure(executables, report)
        report["outcome"] = "pass" if passed else "fail"
        if not passed:
            report["reason"] = "measured medians exceed the predeclared musl margin"
    except NoQuietCPU as error:
        report.update(outcome="incomplete", reason=str(error))
    except (GateError, OSError, ValueError) as error:
        report.update(outcome="fail", reason=str(error))
    if "inputs" in report and phase2_inputs() != report["inputs"]:
        report.update(outcome="fail", reason="benchmark inputs changed during the run")
    path = write_evidence("phase11-copy-benchmark", report)
    print(f"{report['outcome'].upper()} memcpy benchmark, evidence at {path}")
    if "reason" in report:
        print(report["reason"], file=sys.stderr)
    return int(report["outcome"] != "pass")


if __name__ == "__main__":
    raise SystemExit(main())

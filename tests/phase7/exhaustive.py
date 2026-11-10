"""Run disjoint native binary32 ranges and record exact completion evidence."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import subprocess
from time import monotonic

DOMAIN = 1 << 32
OPERATIONS = ("class", "sign", "fabsf", "copysignf", "ceilf", "floorf", "truncf", "roundf",
              "nearbyintf", "rintf", "frexpf", "ilogbf", "logbf", "modff")


def sha256(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def observation(binary, operation, mode, start, count, timeout):
    command = [str(binary), operation, str(mode), str(start), str(count)]
    before = monotonic()
    try:
        observed = subprocess.run(command, env={}, stdin=subprocess.DEVNULL,
                                  capture_output=True, text=True, timeout=timeout)
        record = dict(status=observed.returncode, stdout=observed.stdout, stderr=observed.stderr)
    except subprocess.TimeoutExpired:
        record = dict(status=None, stdout="", stderr=f"Timeout after {timeout} seconds")
    record.update(start=start, count=count, elapsed_seconds=monotonic() - before,
                  passed=record["status"] == 0 and not (record["stdout"] or record["stderr"]))
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binary", type=Path)
    parser.add_argument("operation", choices=OPERATIONS)
    parser.add_argument("report", type=Path)
    parser.add_argument("--mode", type=int, choices=range(4), default=0)
    parser.add_argument("--start", type=lambda text: int(text, 0), default=0)
    parser.add_argument("--count", type=lambda text: int(text, 0), default=DOMAIN)
    parser.add_argument("--shards", type=int, default=64)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--timeout", type=float, default=180)
    parser.add_argument("--input", action="append", type=Path, default=[])
    args = parser.parse_args()
    if not 0 <= args.start < DOMAIN or not 0 < args.count <= DOMAIN - args.start:
        parser.error("the selected range is outside the binary32 domain")
    if not 1 <= args.workers <= 32 or not 1 <= args.shards <= args.count or args.timeout <= 0:
        parser.error("worker count, shard count or timeout is invalid")

    binary = args.binary.resolve(strict=True)
    fixture = Path(__file__).with_suffix(".c")
    artifact_paths = [binary, fixture, Path(__file__), *args.input]
    hashes = {str(path): sha256(path) for path in artifact_paths}
    ranges = []
    for index in range(args.shards):
        start = args.start + args.count * index // args.shards
        end = args.start + args.count * (index + 1) // args.shards
        ranges.append((start, end - start))

    began = monotonic()
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = [executor.submit(observation, binary, args.operation, args.mode,
                                   start, count, args.timeout)
                   for start, count in ranges]
        observations = []
        for index, future in enumerate(futures):
            result = future.result()
            print(f"shard {index + 1}/{args.shards} {result['start']:#010x} "
                  f"+ {result['count']} {'PASS' if result['passed'] else 'FAIL'}", flush=True)
            observations.append(result)

    passed = 0
    expected_start = args.start
    for record in observations:
        if record["start"] != expected_start:
            raise RuntimeError("overlapping or incomplete shard partition")
        expected_start += record["count"]
        if record["passed"]:
            passed += record["count"]
    if expected_start != args.start + args.count:
        raise RuntimeError("incomplete shard partition")
    frozen = all(sha256(path) == hashes[str(path)] for path in artifact_paths)
    success = frozen and passed == args.count
    report = {
        "schema": 1, "backend": "native", "operation": args.operation,
        "rounding_mode_index": args.mode, "start": args.start, "requested_patterns": args.count,
        "passed_patterns": passed, "elapsed_seconds": monotonic() - began,
        "complete_domain": success and args.count == DOMAIN, "inputs_frozen": frozen,
        "workers": args.workers, "sha256": hashes, "shards": observations,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, indent=2) + "\n")
    print(f"{passed}/{args.count} patterns, evidence {args.report}", flush=True)
    return 0 if success else 1


if __name__ == "__main__":
    raise SystemExit(main())

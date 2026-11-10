"""Compare a native MPFR exp2f packet producer with the Python oracle."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from time import monotonic

from campaign import digest, source_inputs
from native_oracle import checked, compare_native, produce

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "transcendental"))
from oracle import MODES, OBSERVATION, TEST_ERRNO, shard
from verify import compare

PROOF_RANGES = (0, 0x80000000, 0x3f000000, 0x42fffe00, 0xc315fe00,
                0x7f7ffe00, 0xff7ffe00, 0x7fbffe00, 0xffbffe00)


def prove(helper, folder, start, count, mode):
    requests, expected = produce(helper, folder, start, count, mode)
    rows = list(shard("exp2", start, count, MODES[mode]))
    python_requests = b"".join(row.wire() for row in rows)
    python_expected = b"".join(OBSERVATION.pack(row.expected.result.low, row.expected.result.high,
                                               row.expected.flags | row.seed,
                                               row.expected.error or TEST_ERRNO) for row in rows)
    if requests != python_requests or expected != python_expected:
        if requests != python_requests:
            raise RuntimeError("native requests differ from Python oracle requests")
        for index, (first, second) in enumerate(zip(OBSERVATION.iter_unpack(expected),
                                                     OBSERVATION.iter_unpack(python_expected), strict=True)):
            if first != second:
                raise RuntimeError(f"native/Python oracle mismatch at {start + index:#x} mode {mode}: "
                                   f"{first!r} != {second!r}")
    return {"start": start, "count": count, "mode_index": mode,
            "expected_sha256": hashlib.sha256(expected).hexdigest()}


def measure(helper, candidate, folder, start, count):
    began = monotonic()
    requests, expected = produce(helper, folder, start, count, 0)
    actual = checked([candidate], data=requests)
    maximum = compare_native(actual, expected, start, count)
    native_elapsed = monotonic() - began

    began = monotonic()
    rows = list(shard("exp2", start, count, MODES[0]))
    python_requests = b"".join(row.wire() for row in rows)
    python_actual = checked([candidate], data=python_requests)
    if requests != python_requests or actual != python_actual:
        raise RuntimeError("the benchmark did not feed identical requests to the same candidate")
    for row, observed in zip(rows, OBSERVATION.iter_unpack(python_actual), strict=True):
        if compare(row, observed, True)[1]:
            raise RuntimeError(f"Python checker rejected {row.description()!r}")
    python_elapsed = monotonic() - began
    return {"start": start, "count": count, "mode_index": 0, "native_seconds": native_elapsed,
            "python_seconds": python_elapsed, "speedup": python_elapsed / native_elapsed,
            "max_ulp": maximum, "request_sha256": hashlib.sha256(requests).hexdigest(),
            "candidate_response_sha256": hashlib.sha256(actual).hexdigest()}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("gate", type=Path)
    parser.add_argument("artifacts", type=Path)
    parser.add_argument("helper", type=Path)
    parser.add_argument("headers", type=Path)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    root = Path.cwd().resolve()
    gate = json.loads(args.gate.read_text())
    artifacts = source_inputs(gate, root)
    assert all(digest(args.artifacts / name) == expected for name, expected in artifacts.items())
    helper = args.helper.resolve(strict=True)
    candidate = (args.artifacts / "trans-f32").resolve(strict=True)
    inputs = [helper, candidate, args.gate, args.headers / "mpfr.h", args.headers / "gmp.h",
              Path(os.environ["OPEN_ASSEMBLY_MPFR"]).resolve(strict=True),
              Path(__file__), Path(__file__).with_name("native_exp2.c")]
    hashes = {str(path): digest(path) for path in inputs}
    with tempfile.TemporaryDirectory(dir="build", prefix="native-exp2-") as temporary:
        folder = Path(temporary)
        proof = [prove(helper, folder, start, 1024, mode)
                 for start in PROOF_RANGES for mode in range(4)]
        timing = measure(helper, candidate, folder, 0x3f000000, 65536)
    assert all(digest(path) == hashes[str(path)] for path in inputs)
    assert source_inputs(gate, root) == artifacts
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps({"schema": 1, "scope": "native MPFR exp2f prototype",
                                       "complete_domain": False, "sha256": hashes, "proof": proof,
                                       "timing": timing}, indent=2) + "\n")
    print(f"PASS {sum(item['count'] for item in proof)} native/Python oracle agreements; "
          f"{timing['speedup']:.2f}x measured on unchanged candidate")


if __name__ == "__main__":
    main()

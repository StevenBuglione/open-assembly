"""Compare fixed-axis native MPFR packets byte for byte with Python."""

import argparse
from collections import Counter
from hashlib import sha256
import os
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
from time import monotonic

from campaign import atomic_json, digest
from native_binary_oracle import compare_binary, linked_dependencies, produce, verify_wire
from native_oracle import OracleMismatch, checked

HERE = Path(__file__).resolve().parent
TRANS = HERE.parent / "transcendental"
sys.path[:0] = [str(TRANS), str(HERE.parents[2] / "tools")]
from oracle import CHANGED_CONTROL, MODES, OBSERVATION, REQUEST, TEST_ERRNO, shard
from phase5 import mpfr_identity
from verify import compare

SIGN = 0x80000000
SEED = 0x4f4142494e415859


def encoding(value):
    return struct.unpack("<I", struct.pack("<f", value))[0]


SPECIAL = (0, 1, 0x007fffff, 0x00800000, 0x3f800000, 0x7f7fffff,
           0x7f800000, 0x7f800055, 0x7fbfffff, 0x7fc00243, 0x7fffffff)
POW_AXES = (*SPECIAL, *(encoding(value) for value in (0.5, 1.5, 2, 3, 23, 127, 128, 148, 149, 150)),
            0x4affffff, 0x4b000000, 0x4b000001, 0x4b7fffff, 0x4b800000)
ATAN2_AXES = (*SPECIAL, encoding(0.5), encoding(2), 0x37800000, 0x6f000000)
CENTER = (0x00800000, 0x3f000000, 0x3f800000, 0x40000000, 0x40800000, 0x41100000,
          0x42a20000, 0x4b000000, 0x7f800000, 0x7fc00000)
WINDOWS = ((0, 32), (0x7fffffe0, 32), *((point - 16, 32) for point in CENTER))
DIRECTED = [(start | sign, count) for start, count in WINDOWS for sign in (0, SIGN)]


def prove(helper, directory, operation, second, mode, windows):
    requests, results = sha256(), sha256()
    observed_flags, observed_errno, classes = Counter(), Counter(), Counter()
    total, native_time, python_time = 0, 0.0, 0.0
    for start, count in windows:
        began = monotonic()
        request, actual = produce(helper, directory, operation, start, count, mode, second)
        native_time += monotonic() - began
        if len(request) != count * REQUEST.size or len(actual) != count * OBSERVATION.size:
            raise RuntimeError("wrong native packet length")
        verify_wire(request, actual, operation, start, count, mode, second)
        began = monotonic()
        rows = list(shard(operation, start, count, MODES[mode], second))
        reference_request = b"".join(row.wire() for row in rows)
        reference_response = b"".join(OBSERVATION.pack(row.expected.result.low, row.expected.result.high,
                                                        row.expected.flags | row.seed,
                                                        row.expected.error or TEST_ERRNO) for row in rows)
        python_time += monotonic() - began
        for encoding_name, got, want, record in (("request", request, reference_request, REQUEST),
                                                 ("response", actual, reference_response, OBSERVATION)):
            if got == want:
                continue
            for index, pair in enumerate(zip(record.iter_unpack(got), record.iter_unpack(want), strict=True)):
                if pair[0] != pair[1]:
                    raise RuntimeError(f"{operation} {encoding_name} {start + index:#010x}, second {second:#010x}, "
                                       f"mode {mode}: native {pair[0]!r}, Python {pair[1]!r}")
        for row in rows:
            value = row.expected.result
            category = value.category
            if category == "zero":
                category = "negative-zero" if value.negative else "positive-zero"
            classes[category] += 1
            observed_flags[row.expected.flags] += 1
            observed_errno[row.expected.error or TEST_ERRNO] += 1
        total += count
        requests.update(request)
        results.update(actual)
    return {"operation": operation, "fixed_second_operand_bits": second, "mode_index": mode,
            "records": total, "intervals": windows, "native_seconds": native_time, "python_seconds": python_time,
            "request_sha256": requests.hexdigest(), "expected_sha256": results.hexdigest(),
            "reference_flags": observed_flags, "reference_errno": observed_errno, "result_classes": classes}


def compile_helper(directory, headers, library):
    command = ["gcc", "-std=c17", "-O2", "-Wall", "-Wextra", "-Werror", f"-I{headers}",
               HERE / "native_binary.c", library, f"-Wl,-rpath,{library.parent}"]
    helper, replay = directory / "native-binary", directory / "replay"
    for output in (helper, replay):
        checked([*command, "-o", output])
    if helper.read_bytes() != replay.read_bytes():
        raise RuntimeError("isolated native binary producer builds differ")
    return helper, linked_dependencies(helper, library)


def invalid_arguments(helper, directory):
    controls = (("sin", 0, 1, 0, 0), ("pow", 0, 0, 0, 0), ("pow", 0xffffffff, 2, 0, 0),
                ("pow", 0, 1, 4, 0), ("atan2", 0, 1, 0, 0x100000000))
    request, response = directory / "invalid-requests", directory / "invalid-responses"
    for arguments in controls:
        run = subprocess.run(list(map(str, (helper, *arguments, request, response))),
                             capture_output=True, env={"LC_ALL": "C"}, timeout=10)
        if (run.returncode, run.stdout, run.stderr) != (2, b"", b"") or request.exists() or response.exists():
            raise RuntimeError(f"accepted invalid binary axis arguments {arguments!r}")
    return controls


def compare_policies(helper, work):
    quiet, other_quiet, signal, other_signal = 0x7fc00243, 0xffc00017, 0x7f800055, 0xff800008
    mixed = ((quiet, other_signal), (signal, other_quiet), (quiet, other_quiet), (signal, other_signal))
    power = ((0xbf800000, encoding(0.5)), (SIGN, encoding(-3)), (SIGN, encoding(3)),
             (encoding(2), encoding(-149)), (1, encoding(2)), (0x7f7fffff, encoding(2)),
             (0x3f800001, encoding(3)))
    angles = ((SIGN, 0), (0, SIGN), (1, 0x7f7fffff), (0x3f800001, 0x3f800000))
    agreements = {"accepted": 0, "rejected": 0}
    for operation, pairs in (("pow", power), ("atan2", angles)):
        for first, second in (*mixed, *pairs):
            for mode, rounding in enumerate(MODES):
                row = next(shard(operation, first, 1, rounding, second))
                request, expected = produce(helper, work, operation, first, 1, mode, second)
                value, high, flags, error = OBSERVATION.unpack(expected)
                alternatives = (value, (value + 1) & 0xffffffff, (value - 1) & 0xffffffff,
                                (value + 2) & 0xffffffff, value ^ SIGN, quiet, other_quiet, signal,
                                0, SIGN, 0x7f800000, value | (1 << 32))
                mutations = [(bits, high, flags, error) for bits in alternatives]
                mutations += [(value, 1, flags, error), (value, high, flags ^ 1, error),
                              (value, high, flags | CHANGED_CONTROL, error), (value, high, flags, error ^ 1)]
                for response in mutations:
                    distance, reasons = compare(row, response, True)
                    try:
                        maximum = compare_binary(request, OBSERVATION.pack(*response), expected, operation, first, 1)
                    except OracleMismatch:
                        if not reasons:
                            raise RuntimeError(f"binary comparator rejected Python-approved {row.description()!r} {response!r}")
                        agreements["rejected"] += 1
                    else:
                        if reasons or maximum != (distance or 0):
                            raise RuntimeError(f"binary comparator approved Python-rejected {row.description()!r} {response!r}")
                        agreements["accepted"] += 1
    return agreements


def proof_inputs(headers, library):
    files = (Path(__file__), HERE / "native_binary.c", HERE / "native_binary_oracle.py",
             HERE / "native_oracle.py", TRANS / "oracle.py", TRANS / "verify.py", TRANS / "operations.def",
             HERE.parent / "math_vectors.py", HERE.parent.parent / "phase5/vectors.py",
             headers / "mpfr.h", headers / "gmp.h", library, Path(sys.executable).resolve())
    return {str(path): digest(path) for path in files}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("headers", type=Path, help="pinned MPFR and GMP header directory")
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    args.report.parent.mkdir(parents=True, exist_ok=True)
    library = Path(os.environ["OPEN_ASSEMBLY_MPFR"]).resolve(strict=True)
    metadata = {"schema_version": 1, "scope": "native MPFR binary32 fixed-second-operand oracle parity",
                "outcome": "fail", "complete_cartesian_domain": False, "release_credit": 0, "seed": SEED}
    try:
        work = Path(tempfile.mkdtemp(dir=args.report.parent, prefix="native-binary-"))
        inputs = proof_inputs(args.headers, library)
        helper, dependencies = compile_helper(work, args.headers, library)
        python_mpfr = mpfr_identity()
        del python_mpfr["commands"]
        helper_sha = digest(helper)
        metadata.update(inputs=inputs, helper=str(helper), helper_sha256=helper_sha,
                        native_dependencies=dependencies, python_mpfr=python_mpfr,
                        invalid_arguments=invalid_arguments(helper, work))
        rng = random.Random(SEED)
        proof = []
        for operation, axes in (("pow", POW_AXES), ("atan2", ATAN2_AXES)):
            for second in sorted({value | sign for value in axes for sign in (0, SIGN)}):
                for mode in range(4):
                    proof.append(prove(helper, work, operation, second, mode, DIRECTED))
            for _ in range(12):
                second, start = rng.getrandbits(32), rng.randrange(2**32 - 128)
                for mode in range(4):
                    proof.append(prove(helper, work, operation, second, mode, [(start, 128)]))
            print(f"PASS {operation} native/Python fixed axes", flush=True)
        benchmark = [prove(helper, work, operation, second, 0, [(0x3f7f8000, 32768)])
                     for operation, second in (("pow", 0x457ff000), ("atan2", 0x3f800000))]
        policy = compare_policies(helper, work)
        if (inputs != proof_inputs(args.headers, library) or helper_sha != digest(helper)
                or any(digest(Path(path)) != value for path, value in dependencies.items())):
            raise RuntimeError("native binary proof inputs changed")
        metadata.update(outcome="pass", proof=proof, benchmark=benchmark, comparator_policy=policy,
                        compared_records=sum(item["records"] for item in [*proof, *benchmark]))
    except (KeyError, OSError, RuntimeError, ValueError, subprocess.SubprocessError) as error:
        metadata["error"] = str(error)
        print(f"oracle: {error}", file=sys.stderr)
    atomic_json(args.report, metadata)
    return int(metadata["outcome"] != "pass")


if __name__ == "__main__":
    raise SystemExit(main())

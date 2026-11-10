"""Pinned, test-only native MPFR producer and independent packet comparator."""

import os
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "transcendental"))
from oracle import DIVBYZERO, EDOM, OBSERVATION, REQUEST, TEST_ERRNO


class OracleMismatch(ValueError):
    """The candidate returned a wrong value, errno, or floating state."""


def checked(command, *, data=None):
    result = subprocess.run(list(map(str, command)), input=data, capture_output=True,
                            env={**os.environ, "LC_ALL": "C"}, timeout=180)
    if result.returncode or result.stderr:
        raise RuntimeError(f"{command}: status {result.returncode}, stderr {result.stderr!r}")
    return result.stdout


def produce(helper, folder, operation, start, count, mode):
    request = folder / "requests"
    expected = folder / "expected"
    checked([helper, operation, start, count, mode, request, expected])
    return request.read_bytes(), expected.read_bytes()


def compare_native(actual, expected, operation, start, count):
    if len(actual) != len(expected) or len(expected) != count * OBSERVATION.size:
        raise RuntimeError("wrong response length")
    # Identical representations also establish exact exception, errno and
    # control-state bytes for every row. Only differences need per-row review.
    if actual == expected:
        return 0
    maximum = 0
    for index, (got, wanted) in enumerate(zip(OBSERVATION.iter_unpack(actual),
                                               OBSERVATION.iter_unpack(expected), strict=True)):
        value, high, flags, error = got
        reference, _, wanted_flags, wanted_error = wanted
        if high or value > 0xffffffff or flags != wanted_flags or error != wanted_error:
            raise OracleMismatch(f"environment or representation mismatch at {start + index:#x}")
        if value == reference:
            continue
        if wanted_error == EDOM and value & 0x7fc00000 == 0x7fc00000:
            continue
        same_sign = (reference ^ value) >> 31 == 0
        normal = all(0x00800000 <= (bits & 0x7fffffff) < 0x7f800000 for bits in (reference, value))
        distance = abs(value - reference)
        # A valid normal approximation always carries INEXACT in addition
        # to the seeded DIVBYZERO. An exact result admits no neighboring encoding.
        if (wanted_flags == DIVBYZERO or wanted_error != TEST_ERRNO or
                not same_sign or not normal or distance > 1):
            raise OracleMismatch(f"value mismatch at {start + index:#x}: {value:#x} != {reference:#x}")
        maximum = max(maximum, distance)
    return maximum


def evaluate(helper, candidate, folder, operation, start, count, mode):
    requests, expected = produce(helper, folder, operation, start, count, mode)
    if len(requests) != count * REQUEST.size or len(expected) != count * OBSERVATION.size:
        raise RuntimeError("wrong request or oracle packet length")
    result = subprocess.run([candidate], input=requests, capture_output=True,
                            env={"LC_ALL": "C"}, timeout=180)
    if result.returncode or result.stderr:
        raise RuntimeError(f"candidate probe status {result.returncode}, stderr {result.stderr!r}")
    return requests, expected, result.stdout

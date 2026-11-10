"""Produce and compare native MPFR fixed-operand binary32 packets."""

from array import array
from hashlib import file_digest
from pathlib import Path
import re
import sys

from native_oracle import OracleMismatch, checked
from oracle import DIVBYZERO, EDOM, ERANGE, INEXACT, OBSERVATION, OP_ID, REQUEST, TEST_ERRNO, UNDERFLOW


def produce(helper, folder, operation, start, count, mode, second):
    request, response = folder / "requests", folder / "responses"
    checked([helper, operation, start, count, mode, second, request, response])
    return request.read_bytes(), response.read_bytes()


def linked_dependencies(helper, library):
    def digest(path):
        with path.open("rb") as source:
            return file_digest(source, "sha256").hexdigest()

    def interpreter_for(path):
        headers = checked(["readelf", "-lW", path]).decode()
        interpreters = re.findall(r"\[Requesting program interpreter: ([^\]]+)\]", headers)
        if len(interpreters) != 1:
            raise RuntimeError("expected exactly one native binary producer interpreter")
        return Path(interpreters[0]).resolve(strict=True)

    interpreter = interpreter_for(helper)
    if interpreter != interpreter_for(Path(sys.executable).resolve()):
        raise RuntimeError("native binary producer interpreter differs from the pinned Python interpreter")
    dependencies = {str(interpreter): digest(interpreter)}
    for line in checked([interpreter, "--list", helper]).decode().splitlines():
        path = line.split("=>", 1)[-1].strip().split(maxsplit=1)[0]
        if path.startswith("/"):
            absolute = Path(path).resolve(strict=True)
            dependencies[str(absolute)] = digest(absolute)
    if str(library) not in dependencies:
        raise RuntimeError("native binary producer did not load pinned MPFR")
    return dependencies


def verify_wire(requests, expected, operation, start, count, mode, second):
    """Verify every fixed-axis request word before running the candidate."""
    if len(requests) != count * REQUEST.size or len(expected) != count * OBSERVATION.size:
        raise RuntimeError("wrong native binary packet length")
    words = memoryview(requests).cast("I")
    width = REQUEST.size // 4
    columns = ((1, 0), (2, mode << 26), (3, OP_ID[operation]), (4, second), (5, 0), (7, 0))
    for slot, value in columns:
        if words[slot::width] != memoryview(array("I", [value]) * count):
            raise RuntimeError(f"native binary request column {slot} does not match its axis")
    if words[::width] != memoryview(array("I", range(start, start + count))):
        raise RuntimeError("native binary first operands do not match their interval")
    seeds = array("I", [DIVBYZERO << 16]) * count
    if operation == "pow":
        for zero in (0, 0x80000000):
            index = zero - start
            if 0 <= index < count:
                _, _, flags, error = OBSERVATION.unpack_from(expected, index * OBSERVATION.size)
                if flags == (DIVBYZERO | UNDERFLOW) and error == ERANGE:
                    seeds[index] = UNDERFLOW << 16
    if words[6::width] != memoryview(seeds):
        raise RuntimeError("native binary request exception seeds do not match their axis")


def nan_class(bits):
    magnitude = bits & 0x7fffffff
    if magnitude <= 0x7f800000:
        return 0
    return 2 if magnitude & 0x00400000 else 1


def compare_binary(requests, actual, expected, operation, start, count):
    """Apply the Python policy to already-bound binary32 producer packets."""
    if operation not in {"pow", "atan2"} or len(requests) != count * REQUEST.size:
        raise RuntimeError("wrong binary operation or request length")
    if len(actual) != len(expected) or len(expected) != count * OBSERVATION.size:
        raise RuntimeError("wrong binary response length")
    if actual == expected:
        return 0
    maximum = 0
    rows = zip(REQUEST.iter_unpack(requests), OBSERVATION.iter_unpack(actual),
               OBSERVATION.iter_unpack(expected), strict=True)
    for index, (request, got, wanted) in enumerate(rows):
        value, high, flags, error = got
        reference, _, wanted_flags, wanted_error = wanted
        if high or value >> 32 or flags != wanted_flags or error != wanted_error:
            raise OracleMismatch(f"environment or representation mismatch at {start + index:#x}")
        if value == reference:
            continue
        first, second = nan_class(request[0]), nan_class(request[4])
        dual_nan = first and second and (operation == "atan2" or first == second)
        if (wanted_error == EDOM or dual_nan) and nan_class(value) == 2:
            continue
        same_sign = (reference ^ value) >> 31 == 0
        normal = all(0x00800000 <= (bits & 0x7fffffff) < 0x7f800000 for bits in (reference, value))
        distance = abs(value - reference)
        if (not wanted_flags & INEXACT or wanted_error != TEST_ERRNO or
                not same_sign or not normal or distance > 1):
            raise OracleMismatch(f"value mismatch at {start + index:#x}: {value:#x} != {reference:#x}")
        maximum = max(maximum, distance)
    return maximum

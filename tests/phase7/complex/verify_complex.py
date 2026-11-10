"""Independent complex representation, magnitude, and argument oracle."""

import argparse
from collections import Counter
from dataclasses import dataclass, replace
from fractions import Fraction
from itertools import product
import hashlib
import json
from pathlib import Path
import random
import re
import struct
import subprocess
import sys
from time import monotonic

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "transcendental"))
from oracle import (CHANGED_CONTROL, TEST_ERRNO, Expected, FORMATS, MODES, NEAREST, Number, REQUEST, bits, expected_atan2,
                    finite, infinity, random_inputs, signed_zero, special_inputs)
from verify import KINDS, SUFFIX, canonical, compare, executable, sha256, tool, write_report
from math_vectors import DIVBYZERO, INEXACT, INVALID, OVERFLOW, UNDERFLOW, reference
import gmpy2
from complex_math import directed, expected_pair
from power import power_rows

OPERATIONS = tuple(re.findall(r"^(?:SCALAR|PAIR|BINARY)\(([a-z]+)\)$",
                              Path(__file__).with_name("operations.def").read_text(), re.MULTILINE))
BASE_OPERATIONS = frozenset(OPERATIONS[:6])
OP_ID = {name: index for index, name in enumerate(OPERATIONS)}
OBSERVATION = struct.Struct("<QHHiQH6x")
EXPONENT = struct.Struct("<QQHHI")
CHANGED_X87_DEPTH = 0x4000
SEED = 0x434d5058


@dataclass(frozen=True)
class Row:
    operation: str
    argument: Number
    operand: Number
    mode: int
    label: str
    expected: Expected
    imaginary: Expected
    optional_flags: int = 0
    exponent: tuple[Number, Number] | None = None

    @property
    def seed(self):
        choices = [flag for flag in (DIVBYZERO, UNDERFLOW, OVERFLOW, INVALID, INEXACT)
                   if not self.expected.flags & flag]
        return next((flag for flag in choices if not self.optional_flags & flag), choices[0])

    def wire(self):
        base = REQUEST.pack(self.argument.low, self.argument.high, self.mode, OP_ID[self.operation],
                            self.operand.low, self.operand.high, self.seed, 0)
        if self.exponent is None:
            return base + bytes(EXPONENT.size)
        real, imag = self.exponent
        return base + EXPONENT.pack(real.low, imag.low, real.high, imag.high, 0)

    def description(self):
        return {"family": self.operation, "input_real": bits(self.argument),
                "input_imaginary": bits(self.operand), "mode": self.mode, "stratum": self.label,
                "exponent": tuple(map(bits, self.exponent)) if self.exponent is not None else None,
                "expected_real": bits(self.expected.result), "expected_imaginary": bits(self.imaginary.result),
                "flags": self.expected.flags, "optional_flags": self.optional_flags, "errno": self.expected.error,
                "real_policy": self.expected.policy, "imaginary_policy": self.imaginary.policy}


def expected(operation, real, imag, mode):
    fmt = real.fmt
    zero = signed_zero(fmt)
    if operation == "creal":
        return Expected(real), zero
    if operation == "cimag":
        return Expected(imag), zero
    if operation == "conj":
        return Expected(real), imag.with_sign(not imag.negative)
    if operation == "cproj":
        if real.category == "inf" or imag.category == "inf":
            return Expected(infinity(fmt)), signed_zero(fmt, imag.negative)
        return Expected(real), imag
    if operation == "carg":
        return expected_atan2(imag, real, mode), zero
    if operation == "cabs":
        result = reference("hypot", fmt, real, imag, zero, mode, 0)
        policy = "quiet-nan" if result.policy else "exact"
        return Expected(result.result, result.flags, result.error, policy), zero
    raise ValueError(operation)


def cases(kind, operation, random_count):
    fmt = FORMATS[kind]
    rng = random.Random(SEED ^ fmt.bits ^ OP_ID[operation] * 65537)
    if operation == "cpow":
        for real, imag, exponent, mode, label, wanted, imaginary, optional in power_rows(
                fmt, rng, random_count):
            yield Row(operation, real, imag, mode, label, wanted, imaginary, optional, exponent)
        return
    if operation in BASE_OPERATIONS:
        values = [value for value, _ in special_inputs(fmt)]
        values.extend(finite(fmt, value) for value in (1, -1, 2, -2, 3, 4, 5, -5, 12, -12))
        randoms = zip(random_inputs(fmt, rng, random_count), random_inputs(fmt, rng, random_count),
                      strict=True)
        pairs = [(real, imag, "component-quadrants-and-extrema")
                 for real, imag in product(values, repeat=2)]
        pairs.extend((real, imag, "seeded-stratified") for (real, _), (imag, _) in randoms)
        for real, imag, label in pairs:
            for mode in MODES:
                re_part, im_part = expected(operation, real, imag, mode)
                yield Row(operation, real, imag, mode, label, re_part, Expected(im_part))
        return

    pairs = list(directed(fmt, operation))
    for _ in range(random_count):
        real, imag = (finite(fmt, Fraction(rng.randrange(-32768, 32769), 4096)) for _ in range(2))
        pairs.append((real, imag, "seeded-ordinary-dyadic"))
    for real, imag, label in pairs:
        for mode in MODES:
            re_part, im_part, optional = expected_pair(operation, real, imag, mode)
            yield Row(operation, real, imag, mode, label, re_part, im_part, optional)


def compare_component(row, expected, low, high):
    actual = Number(expected.result.fmt, low, high)
    if expected.policy == "class":
        return None, ([] if canonical(actual) and actual.category == expected.result.category
                      else ["result class"])
    if expected.policy == "pi-over-two-either-sign":
        fmt = expected.result.fmt
        expected = expected_atan2(finite(fmt, -1 if actual.negative else 1), signed_zero(fmt), row.mode)
    return compare(replace(row, expected=expected), (low, high, 0, 0), False)


def observe(command, rows, environment=True):
    data = b"".join(row.wire() for row in rows)
    command = list(map(str, command))
    start = monotonic()
    result = subprocess.run(command, env={"LC_ALL": "C"}, input=data,
                            capture_output=True, timeout=180)
    evidence = {"command": command, "status": result.returncode, "records": len(rows),
                "stderr": result.stderr.decode(errors="replace"), "environment_checked": environment,
                "request_sha256": hashlib.sha256(data).hexdigest(),
                "response_sha256": hashlib.sha256(result.stdout).hexdigest(),
                "elapsed_seconds": monotonic() - start}
    if result.returncode or result.stderr or len(result.stdout) != len(rows) * OBSERVATION.size:
        evidence.update(passed=False, response_bytes=len(result.stdout), error="probe transport")
        return evidence

    real_max, imag_max = 0, 0
    failures = Counter()
    witnesses = []
    for row, observed in zip(rows, OBSERVATION.iter_unpack(result.stdout), strict=True):
        low, high, flags, error, imag_low, imag_high = observed
        result_imag = Number(row.imaginary.result.fmt, imag_low, imag_high)
        distance, re_failures = compare_component(row, row.expected, low, high)
        im_distance, im_failures = compare_component(row, row.imaginary, imag_low, imag_high)
        real_max = max(real_max, distance or 0)
        imag_max = max(imag_max, im_distance or 0)
        reasons = [f"real {failure}" for failure in re_failures]
        reasons.extend(f"imaginary {failure}" for failure in im_failures)
        if environment:
            if flags & CHANGED_X87_DEPTH:
                reasons.append("changed x87 stack depth")
            if flags & CHANGED_CONTROL:
                reasons.append("changed control state")
            ignored = row.optional_flags & ~row.seed
            if (flags & ~(CHANGED_CONTROL | CHANGED_X87_DEPTH | ignored)) != (row.expected.flags | row.seed):
                reasons.append("exception flags")
            if error != (row.expected.error or TEST_ERRNO):
                reasons.append("errno")
        if reasons:
            failures.update(reasons)
            if len(witnesses) < 8:
                witnesses.append({**row.description(), "actual_real": f"{high:04x}:{low:016x}",
                                  "actual_imaginary": bits(result_imag), "actual_flags": flags,
                                  "actual_errno": error, "failures": reasons,
                                  "real_distance": distance, "imaginary_distance": im_distance})
    evidence.update(passed=not failures, max_real_ulp=real_max, max_imaginary_ulp=imag_max,
                    failures_by_reason=dict(failures), witnesses=witnesses)
    return evidence


def common(row):
    finite_kinds = {"normal", "zero"}
    return (row.mode == NEAREST and
            (row.exponent is None or all(value.category in finite_kinds for value in row.exponent)) and
            row.argument.category in finite_kinds and
            row.operand.category in finite_kinds and row.expected.result.category in finite_kinds and
            row.imaginary.result.category in finite_kinds and not row.expected.error)


def loaded_libraries():
    paths = {Path(line.split()[-1]) for line in Path("/proc/self/maps").read_text().splitlines()
             if " /" in line}
    selected = []
    for name in ("libmpc.so.", "libmpfr.so."):
        libraries = {path.resolve() for path in paths if path.name.startswith(name)}
        if len(libraries) != 1:
            raise ValueError(f"expected exactly one loaded {name} oracle library")
        selected.extend(libraries)
    return selected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binaries", type=Path)
    parser.add_argument("report", type=Path)
    parser.add_argument("--hosts", type=Path)
    parser.add_argument("--stubs", type=Path)
    parser.add_argument("--input", type=Path, action="append", default=[])
    parser.add_argument("--random", type=int, default=128)
    parser.add_argument("--operation", choices=OPERATIONS, action="append")
    args = parser.parse_args()
    qemu, valgrind = tool("qemu-x86_64"), tool("valgrind")
    chosen = tuple(args.operation or OPERATIONS)
    candidate = {kind: executable(args.binaries / f"complex-{kind}") for kind in KINDS}
    hosts = ({kind: {compiler: executable(args.hosts / f"{compiler}-complex-{kind}")
                     for compiler in ("gcc", "musl-gcc")} for kind in KINDS} if args.hosts else {})
    stubs = ({op + SUFFIX[kind]: executable(args.stubs / (op + SUFFIX[kind]))
              for kind in KINDS for op in chosen} if args.stubs else {})
    current = Path(__file__).resolve().parent
    inputs = [current / "probe.c", current / "operations.def", current / "complex_math.py", current / "power.py",
              Path(__file__), current.parent / "math_vectors.py",
              current.parent / "transcendental" / "oracle.py",
              current.parent / "transcendental" / "verify.py", *candidate.values(),
              *(path for group in hosts.values() for path in group.values()),
              *stubs.values(), qemu, valgrind, *loaded_libraries(), *args.input]
    hashes = {str(path): sha256(path) for path in inputs}
    report = {"schema": 1, "scope": "Phase 7 complex functions with MPC references", "seed": SEED,
              "mpfr": gmpy2.mpfr_version(), "mpc": gmpy2.mpc_version(), "sha256": hashes, "results": {}, "stubs": {}}
    passed = True
    for kind, binary in candidate.items():
        family = report["results"][kind] = {}
        for operation in chosen:
            rows = list(cases(kind, operation, args.random))
            print(f"prepared {kind} {operation} {len(rows)}", flush=True)
            selected = [row for row in rows if common(row)]
            result = family[operation] = {
                "native": observe([binary], rows),
                "qemu": observe([qemu, binary], rows),
            }
            if kind != "f80":
                result["valgrind"] = observe([valgrind, "--quiet", "--error-exitcode=99", binary],
                                              selected, environment=False)
            passed &= all(item["passed"] for item in result.values())
            if kind in hosts:
                result.update({name: observe([path], selected, environment=False)
                               for name, path in hosts[kind].items()})
            symbol = operation + SUFFIX[kind]
            if symbol in stubs:
                witness = next(row for row in selected if row.expected.result.category == "normal" or
                               row.imaginary.result.category == "normal")
                stub = observe([stubs[symbol]], [witness], environment=False)
                failures = stub.get("witnesses", [])
                zero = "0000:0000000000000000"
                killed = (stub["status"] == 0 and len(failures) == 1 and
                          failures[0]["actual_real"] == failures[0]["actual_imaginary"] == zero)
                report["stubs"][symbol] = {**stub, "rejected": killed}
                passed &= killed
            print(kind, operation, " ".join(f"{name}={'pass' if item['passed'] else 'fail'}"
                                            for name, item in result.items()), flush=True)
    report["inputs_frozen"] = all(sha256(path) == hashes[str(path)] for path in inputs)
    report["passed"] = passed and report["inputs_frozen"]
    write_report(args.report, report)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

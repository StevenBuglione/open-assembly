"""Replay directed complex inverse range transitions on pinned candidate ELFs."""

import argparse
from dataclasses import replace
import json
from pathlib import Path

from verify_complex import KINDS, Row, expected_pair, observe, sha256, tool
from math_vectors import DOWN, ERANGE, INEXACT, UNDERFLOW, finite, representation, two
from oracle import FORMATS


def boundary_rows(kind):
    fmt = FORMATS[kind]
    largest_subnormal = representation(fmt, False, 0, (1 << (fmt.precision - 1)) - 1)
    least_normal = representation(fmt, False, 1)
    scale, one = finite(fmt, two(-fmt.minimum)), finite(fmt, 1)
    for operation, real, imag, axis, result, flags, error in (
        ("catanh", scale, one, 0, largest_subnormal, UNDERFLOW | INEXACT, ERANGE),
        ("catan", one, scale, 1, largest_subnormal, UNDERFLOW | INEXACT, ERANGE),
        ("cacos", scale, one, 0, least_normal, INEXACT, 0),
        ("cacosh", scale, one, 1, least_normal, INEXACT, 0),
    ):
        expected = expected_pair(operation, real, imag, DOWN)
        first, second, optional = expected
        # For atanh, the real part is half atanh(2*x/(x*x+2)). Bound
        # the remaining positive series terms by t^3/(3*(1-t^2)).
        # For the other pair, s=sin(angle) satisfies x^2=1/s^2-s^2.
        # The first correction of asin(s) puts the angle above 1/x,
        # while its difference from 1/x remains below a target step.
        if expected[axis].result != result or first.flags != flags or first.error != error:
            raise ValueError(f"MPC disagrees with analytic transition for {kind} {operation}")
        if axis == 0:
            first = replace(first, policy="exact")
        else:
            second = replace(second, policy="exact")
        yield Row(operation, real, imag, DOWN, "inverse-minnormal-replay", first, second, optional)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("binaries", type=Path)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    qemu = tool("qemu-x86_64")
    results, hashes = {}, {}
    for kind in KINDS:
        binary = (args.binaries / f"complex-{kind}").resolve(strict=True)
        hashes[kind] = sha256(binary)
        rows = list(boundary_rows(kind))
        results[kind] = {"native": observe([binary], rows), "qemu": observe([qemu, binary], rows)}
    passed = all(item["passed"] for group in results.values() for item in group.values())
    report = {"schema": 1, "passed": passed, "candidate_sha256": hashes, "results": results}
    args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    print(f"{'PASS' if passed else 'FAIL'} 12 directed inverse range transitions per backend")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())

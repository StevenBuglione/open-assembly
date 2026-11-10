"""Verify the native ABI and guard-page probes detect injected faults."""

import argparse
import json
from pathlib import Path
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
CONTROLS = (
    (
        "FAIL_ABI",
        "abi",
        "FAIL abi abi:sysv-amd64: sample 0 returned 0, mask 0x7ff: "
        "RSP DF RBX RBP R12 R13 R14 R15 MXCSR control x87 control word x87 stack",
    ),
    (
        "FAIL_GUARD_START",
        "guard",
        "FAIL guard reference:page-protection: start length 0 raised signal 11",
    ),
    (
        "FAIL_GUARD_END",
        "guard",
        "FAIL guard reference:page-protection: end length 0 raised signal 11",
    ),
    (
        "FAIL_GUARD_WRITE",
        "guard",
        "FAIL guard reference:page-protection: start length 0 raised signal 11",
    ),
)


def run(command, **options):
    return subprocess.run(command, cwd=ROOT, timeout=15, **options)


def evaluate(args, work):
    abi = args.abi_object.resolve() if args.abi_object else work / "abi.o"
    tests = args.test_object.resolve() if args.test_object else work / "checks.o"
    fault = work / "fault.o"
    binary = work / "checks"
    if args.abi_object is None:
        run(["nasm", "-f", "elf64", "tests/abi/strlen.asm", "-o", abi], check=True)
        run(
            ["gcc", "-std=c17", "-O2", "-Wall", "-Wextra", "-Werror",
             "-ffreestanding", "-fno-builtin", "-c", "tests/unit/strlen.c", "-o", tests],
            check=True,
        )

    cases = []
    for flag, mode, expected in CONTROLS:
        run(
            ["nasm", "-f", "elf64", f"-D{flag}", "tests/abi/probe_faults.asm", "-o", fault],
            check=True,
        )
        run(["gcc", "-static", "-no-pie", tests, abi, fault, "-o", binary], check=True)
        result = run([binary, mode], capture_output=True, text=True, check=False)
        cases.append({
            "control": flag,
            "mode": mode,
            "expected_status": 1,
            "expected_diagnostic": expected,
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
            "passed": result.returncode == 1 and result.stderr.strip() == expected,
        })
    return cases


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--abi-object", type=Path)
    parser.add_argument("--test-object", type=Path)
    parser.add_argument("--json", type=Path, help="write the full diagnostic evidence")
    args = parser.parse_args()
    if (args.abi_object is None) != (args.test_object is None):
        parser.error("--abi-object and --test-object must be supplied together")

    try:
        with tempfile.TemporaryDirectory(prefix="al-probes-") as temp:
            cases = evaluate(args, Path(temp))
        passed = all(case["passed"] for case in cases)
        if args.json:
            args.json.parent.mkdir(parents=True, exist_ok=True)
            args.json.write_text(json.dumps({"schema": 1, "cases": cases, "passed": passed}, indent=2) + "\n")
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        print(f"ERROR runtime probe controls: {error}", file=sys.stderr)
        return 2

    for case in cases:
        if not case["passed"]:
            print(
                f"FAIL runtime probe {case['control']}: expected status 1 and "
                f"{case['expected_diagnostic']!r}, got {case['returncode']} and {case['stderr'].strip()!r}",
                file=sys.stderr,
            )
    print(
        f"{'PASS' if passed else 'FAIL'} runtime probe controls "
        f"{sum(case['passed'] for case in cases)}/{len(cases)} intended failures"
    )
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())

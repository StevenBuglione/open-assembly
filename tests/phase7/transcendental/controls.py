"""Generate typed zero stubs and deliberate accuracy/environment controls."""

import argparse
from pathlib import Path
import subprocess

from oracle import Case, FORMATS, NEAREST, OPERATIONS, expected, finite
from verify import KINDS, SUFFIX, observe, sha256, write_report

AUDIT = Path("tools/elf-audit")


def checked(command):
    return subprocess.run(command, check=True, capture_output=True, text=True).stdout


def symbols(path, undefined=False):
    flag = "--undefined-only" if undefined else "--defined-only"
    return {fields[-1]: fields[-2] for line in checked(["nm", "-g", flag, path]).splitlines()
            if len(fields := line.split()) >= 2}


def wrapped_binary(directory, label, symbol, body, fixture, startup, archive):
    source = directory / f"{label}.asm"
    obj = directory / f"{label}.o"
    binary = directory / label
    source.write_text(f"""bits 64
global __wrap_{symbol}:function
section .text
__wrap_{symbol}:
{body}
section .note.GNU-stack noalloc noexec nowrite progbits
""")
    checked(["nasm", "-f", "elf64", "-Wall", "-Werror", "-Wno-reloc-rel-dword", "-o", obj, source])
    checked([AUDIT, "--assembly-object", obj])
    checked(["ld", "-m", "elf_x86_64", "-static", "-no-pie", "-z", "noexecstack", "--gc-sections",
             "--fatal-warnings", f"--wrap={symbol}", "-o", binary, startup, fixture, obj, archive])
    checked([AUDIT, binary])
    if symbols(binary).get(f"__wrap_{symbol}") != "T":
        raise RuntimeError(f"{label} does not link the generated {symbol} replacement")
    return binary, {str(path): sha256(path) for path in (source, obj, binary)}


def make_stubs(directory, fixtures, startup, archive):
    records = {}
    for kind in KINDS:
        fixture = fixtures / f"trans-{kind}.o"
        positive = fixtures / f"trans-{kind}"
        checked([AUDIT, "--test-object", fixture])
        checked([AUDIT, positive])
        references, definitions = symbols(fixture, undefined=True), symbols(positive)
        zero = "fldz" if kind == "f80" else "pxor xmm0, xmm0"
        for operation in OPERATIONS:
            symbol = operation + SUFFIX[kind]
            if references.get(symbol) != "U" or definitions.get(symbol) != "T":
                raise RuntimeError(f"the {kind} fixture does not bind the public candidate {symbol}")
            _, records[symbol] = wrapped_binary(directory, symbol, symbol, f"    {zero}\n    ret",
                                                 fixture, startup, archive)
    return records


def control_cases():
    fmt = FORMATS["f64"]
    one, zero = finite(fmt, 1), finite(fmt, 0)
    sin = Case("sin", one, NEAREST, "comparator-control", expected("sin", one, NEAREST))
    exp2 = Case("exp2", zero, NEAREST, "exact-result-control", expected("exp2", zero, NEAREST))
    for delta in (1, 2):
        yield (f"sin-{delta}-ulp", sin, f"    mov rax, {sin.expected.result.low + delta:#x}\n"
                                      "    movq xmm0, rax", delta == 1, delta)
    yield ("sin-extra-exception", sin, "    stmxcsr [rsp]\n    or dword [rsp], 1\n    ldmxcsr [rsp]",
           False, 0)
    yield ("exp2-exact-neighbor", exp2, f"    mov rax, {exp2.expected.result.low + 1:#x}\n"
                                       "    movq xmm0, rax", False, 1)


def run_controls(directory, fixture, startup, archive):
    results = {}
    for label, case, change, accepted, distance in control_cases():
        operation = case.operation
        body = f"""    extern __real_{operation}:function
    sub rsp, 8
    call __real_{operation}
{change}
    add rsp, 8
    ret"""
        binary, hashes = wrapped_binary(directory, label, operation, body, fixture, startup, archive)
        observed = observe([binary.resolve()], [case])
        reason = {
            "sin-2-ulp": "one-ULP bound, sign, or result class",
            "sin-extra-exception": "exception flags",
            "exp2-exact-neighbor": "exact representation",
        }.get(label)
        expected_failures = {reason: 1} if reason else {}
        matched = (observed.get("max_finite_ulp") == distance and
                   observed["passed"] == accepted and observed.get("failures_by_reason") == expected_failures)
        results[label] = {"matched": matched, "expected_acceptance": accepted, "expected_ulp": distance,
                          "sha256": hashes, "observation": observed}
        print(f"control {label}: {'pass' if matched else 'fail'}", flush=True)
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixtures", type=Path)
    parser.add_argument("startup", type=Path)
    parser.add_argument("archive", type=Path)
    parser.add_argument("directory", type=Path)
    parser.add_argument("report", type=Path)
    parser.add_argument("--accuracy-only", action="store_true")
    args = parser.parse_args()
    args.directory.mkdir(parents=True, exist_ok=True)
    stubs = {} if args.accuracy_only else make_stubs(
        args.directory, args.fixtures, args.startup, args.archive)
    controls = run_controls(args.directory, args.fixtures / "trans-f64.o", args.startup, args.archive)
    report = {"schema": 1, "stub_artifacts": stubs, "controls": controls,
              "startup_sha256": sha256(args.startup), "archive_sha256": sha256(args.archive),
              "passed": all(control["matched"] for control in controls.values())}
    write_report(args.report, report)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

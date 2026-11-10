"""Run the checker against independently specified positive and negative cases."""

import argparse
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import tomllib


ROOT = Path(__file__).resolve().parents[2]
CORPUS = ROOT / "tests/seeded-bugs"
DIAGNOSTIC = re.compile(r"(?P<path>.+?):(?P<line>[1-9][0-9]*): (?P<rule>[A-Z_0-9]+): (?P<message>.+)")


def load_cases():
    with (CORPUS / "manifest.toml").open("rb") as manifest_file:
        manifest = tomllib.load(manifest_file)

    if set(manifest) != {"case", "positive"} or len(manifest["case"]) < 30 or not manifest["positive"]:
        raise ValueError("manifest must contain at least 30 seeds and a positive control")

    cases = []
    paths = set()
    for group in ("case", "positive"):
        for entry in manifest[group]:
            path = Path(entry["path"])
            full_path = (ROOT / path).resolve()
            if full_path.parent != CORPUS or full_path in paths or not full_path.is_file():
                raise ValueError(f"invalid or duplicate case path: {path}")
            paths.add(full_path)

            rule = entry.get("rule")
            if group == "case" and (not rule or not re.fullmatch(r"[A-Z_0-9]+", rule)):
                raise ValueError(f"negative case needs an explicit rule: {path}")
            if group == "positive" and rule is not None:
                raise ValueError(f"positive case may not expect a diagnostic: {path}")
            if not entry["description"].strip() or type(entry.get("syscall_boundary", False)) is not bool:
                raise ValueError(f"invalid case metadata: {path}")
            cases.append(entry)

    if paths != set(CORPUS.glob("*.asm")):
        raise ValueError("manifest paths do not match the complete assembly corpus")
    return cases


def run(command):
    return subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=15, check=False)


def evaluate(entry, object_path, function=None):
    path = entry["path"]
    expected = entry.get("rule")
    assembled = run(["nasm", "-f", "elf64", "-o", str(object_path), path])
    command = ["tools/lint"]
    if function:
        command.extend(["--function", function])
    if entry.get("syscall_boundary", False):
        command.append("--fixture-syscall-boundary")
    linted = run([*command, path])

    lines = linted.stderr.splitlines()
    diagnostics = []
    for line in lines:
        match = DIAGNOSTIC.fullmatch(line)
        if match:
            diagnostic = match.groupdict()
            diagnostic["line"] = int(diagnostic["line"])
            diagnostics.append(diagnostic)

    diagnostic_format_ok = len(diagnostics) == len(lines) and all(
        (ROOT / diagnostic["path"]).resolve() == ROOT / path
        for diagnostic in diagnostics
    )
    if expected is None:
        expected_result = linted.returncode == 0 and not lines
    else:
        expected_result = (
            linted.returncode == 1
            and bool(diagnostics)
            and diagnostics[0]["rule"] == expected
        )

    return {
        "path": path,
        "description": entry["description"],
        "expected_rule": expected,
        "function": function,
        "syscall_boundary": entry.get("syscall_boundary", False),
        "assembler_returncode": assembled.returncode,
        "assembler_stderr": assembled.stderr,
        "returncode": linted.returncode,
        "diagnostics": diagnostics,
        "stderr": linted.stderr,
        "stdout": linted.stdout,
        "passed": assembled.returncode == 0 and diagnostic_format_ok and expected_result,
    }


def public_call_case(work):
    header = run(["tools/gen", "--comment-header", "strlen"])
    if header.returncode != 0:
        raise ValueError(f"could not generate the strlen header: {header.stderr.strip()}")
    source = work / "strlen_unspecced_call.asm"
    source.write_text(header.stdout + "\n" + """\
bits 64
default rel
section .text
global strlen:function
extern printf
strlen:
    sub rsp, 8
    call printf
    add rsp, 8
    ret
section .note.GNU-stack noalloc noexec nowrite progbits
""")
    return evaluate({
        "path": str(source),
        "description": "Spec-aware checking rejects an external call with no known signature and unset AL.",
        "rule": "CALL_SIGNATURE",
    }, work / "public.o", function="strlen")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--json", type=Path, help="write the full diagnostic evidence")
    args = parser.parse_args()

    try:
        with tempfile.TemporaryDirectory(prefix="al-lint-") as temp:
            work = Path(temp)
            cases = [evaluate(entry, work / "seed.o") for entry in load_cases()]
            public_cases = [public_call_case(work)]
        all_cases = cases + public_cases
        passed = all(case["passed"] for case in all_cases)
        if args.json:
            args.json.parent.mkdir(parents=True, exist_ok=True)
            args.json.write_text(json.dumps({
                "schema": 1, "cases": cases, "public_cases": public_cases, "passed": passed,
            }, indent=2) + "\n")
    except (KeyError, OSError, TypeError, ValueError, subprocess.TimeoutExpired) as error:
        print(f"ERROR checker corpus: {error}", file=sys.stderr)
        return 2

    for case in all_cases:
        if not case["passed"]:
            print(f"FAIL {case['path']} expected {case['expected_rule'] or 'acceptance'}", file=sys.stderr)
            print(
                f"  NASM status {case['assembler_returncode']}\n{case['assembler_stderr']}"
                f"  checker status {case['returncode']}\n{case['stderr']}{case['stdout']}",
                file=sys.stderr,
            )
    seeds = [case for case in cases if case["expected_rule"] is not None]
    positives = [case for case in cases if case["expected_rule"] is None]
    print(
        f"{'PASS' if passed else 'FAIL'} checker corpus "
        f"{sum(case['passed'] for case in seeds)}/{len(seeds)} intended rejections, "
        f"{sum(case['passed'] for case in positives)}/{len(positives)} positive controls, "
        f"{sum(case['passed'] for case in public_cases)}/{len(public_cases)} public CLI regressions"
    )
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())

"""Check the public nonlocal-jump frame against the static control-flow model."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]
REGISTERS = ("rbx", "rbp", "r12", "r13", "r14", "r15")
CHECKER_TOOLS = ("lint", "lint.py", "gen", "spec.py", "extensions.py", "extension_abi.py")
SAVE_RULE = "context save must capture the caller registers and return point at entry"
RESUME_RULE = "context resume must restore the exact saved registers and transfer to the saved PC"


def hash_file(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def slot(index):
    return f"[rdi + {index * 8}]" if index else "[rdi]"


def save_body(signal=False, resumed_stack=8, interior=False):
    lines = ["    movsxd rsi, esi"] if signal else []
    for index, register in enumerate(REGISTERS):
        if interior and index == 2:
            lines.append(".interior:")
        lines.append(f"    mov {slot(index)}, {register}")
    lines.extend((f"    lea rax, [rsp + {resumed_stack}]", f"    mov {slot(6)}, rax",
                  "    mov rax, [rsp]", f"    mov {slot(7)}, rax", "    xor eax, eax", "    ret"))
    return "\n".join(lines)


def resume_body(stack_slot=6, jump_register="r11", saved_r12_slot=2):
    lines = ["    movsxd rax, esi", "    test eax, eax", "    jnz .restore",
             "    mov eax, 1", ".restore:", f"    mov r11, {slot(7)}",
             f"    mov r10, {slot(stack_slot)}"]
    for index, register in enumerate(REGISTERS):
        field = saved_r12_slot if register == "r12" else index
        lines.append(f"    mov {register}, {slot(field)}")
    lines.extend(("    mov rsp, r10", f"    jmp {jump_register}"))
    return "\n".join(lines)


def fixtures():
    yield "save-valid", "setjmp", save_body(), None
    yield "signal-save-valid", "sigsetjmp", save_body(signal=True), None
    yield "resume-valid", "longjmp", resume_body(), None
    yield "save-wrong-stack", "setjmp", save_body(resumed_stack=16), SAVE_RULE
    yield "signal-save-interior-label", "sigsetjmp", save_body(signal=True, interior=True), SAVE_RULE
    yield "resume-stack-from-pc", "longjmp", resume_body(stack_slot=7), RESUME_RULE
    yield "resume-jump-to-stack", "longjmp", resume_body(jump_register="r10"), RESUME_RULE
    yield "resume-r12-from-r13", "longjmp", resume_body(saved_r12_slot=3), RESUME_RULE


def run(command, directory):
    return subprocess.run(list(map(str, command)), cwd=directory, text=True,
                          capture_output=True, timeout=30)


def prepare(root):
    for directory in ("spec", "include/asm"):
        shutil.copytree(ROOT / directory, root / directory)
    (root / "tools").mkdir()
    for name in CHECKER_TOOLS:
        shutil.copy2(ROOT / "tools" / name, root / "tools" / name)
    (root / "src/x86_64-linux/setjmp").mkdir(parents=True)


def check_case(root, name, function, body, reason):
    header = run(["tools/gen", "--comment-header", function], root)
    if header.returncode:
        raise RuntimeError(header.stderr)
    source = Path("src/x86_64-linux/setjmp") / f"{function}.asm"
    generated = header.stdout + f"""
bits 64
default rel
global {function}:function
section .text.{function} progbits alloc exec nowrite
{function}:
{body}
section .note.GNU-stack noalloc noexec nowrite progbits
"""
    (root / source).write_text(generated)
    assembly = run(["nasm", "-f", "elf64", "-Wall", "-Werror", "-o", "test.o", source], root)
    observed = run(["tools/lint", source], root)
    expected = "" if reason is None else f"{source}:1: CONTROL_FLOW: {reason}\n"
    matched = (assembly.returncode == 0 and observed.returncode == int(reason is not None) and
               not observed.stdout and observed.stderr == expected)
    print(f"{'PASS' if matched else 'FAIL'} {name}", flush=True)
    return {"passed": matched, "function": function, "fixture_sha256": hash_file(root / source),
            "assembly_status": assembly.returncode, "assembly_stderr": assembly.stderr,
            "lint_status": observed.returncode, "lint_stderr": observed.stderr,
            "expected_stderr": expected}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("build/evidence/phase6-jump-checker.json"))
    args = parser.parse_args()
    with tempfile.TemporaryDirectory(prefix="oa-jump-checker-") as temporary:
        root = Path(temporary)
        prepare(root)
        cases = {name: check_case(root, name, function, body, reason)
                 for name, function, body, reason in fixtures()}
    paths = [Path("tools") / name for name in CHECKER_TOOLS]
    paths.extend((Path("docs/adr/0007-linux-files-process-signal-time.md"),
                  Path(__file__).resolve().relative_to(ROOT)))
    paths.extend(path.relative_to(ROOT) for path in (ROOT / "spec/functions/setjmp").glob("*.toml"))
    report = {"schema": 1, "scope": "Phase 6 independent jump checker controls",
              "sha256": {path.as_posix(): hash_file(ROOT / path) for path in sorted(paths)},
              "cases": cases, "passed": all(case["passed"] for case in cases.values())}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())

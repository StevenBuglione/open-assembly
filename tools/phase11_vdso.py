"""Run independent source-bound vDSO lookup and realtime dispatch checks."""

from pathlib import Path

from phase6 import execute_manifest_gate, phase6_inputs
from spec import ROOT, snapshot_inputs

SUITE = Path("tests/phase11/vdso")


def inputs():
    hashes = phase6_inputs()
    hashes.update(snapshot_inputs(ROOT, [Path("docs/adr/0022-vdso-realtime.md")]))
    return dict(sorted(hashes.items()))


if __name__ == "__main__":
    raise SystemExit(execute_manifest_gate(
        "phase11-vdso", SUITE, {"time"}, {SUITE / "dispatch.c": ("__al_syscall",)}, (),
        inputs, "OA_PHASE11_HOST", {"limits": [
            "Only realtime seconds via time() use this vDSO path.",
            "Live kernel dispatch is verified on native Linux. Other backends exercise raw fallback.",
            "Directed ELF64 metadata, raw failures, signal and fork reentry, and a synthetic callable entry.",
        ]},
    ))

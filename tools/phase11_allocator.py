"""Verify the direct-allocation mremap path independently."""

from pathlib import Path

from phase6 import execute_manifest_gate, phase6_inputs
from spec import ROOT, snapshot_inputs

SUITE = Path("tests/phase11/allocator")


def inputs():
    bound = phase6_inputs()
    bound.update(snapshot_inputs(ROOT, [Path("docs/adr/0004-allocator-environment.md"),
                                        Path("docs/adr/0036-direct-allocation-remap.md")]))
    return dict(sorted(bound.items()))


if __name__ == "__main__":
    raise SystemExit(execute_manifest_gate(
        "phase11-allocator", SUITE, {"realloc"}, {SUITE / "remap.c": ("__al_syscall",)}, (),
        inputs, "OA_PHASE11_HOST", {"limits": [
            "Direct anonymous allocation growth, fallback and ownership.",
            "The forced-move observation uses native MAP_FIXED_NOREPLACE.",
            "Other allocator v2 workloads and musl benchmarks have separate acceptance.",
        ]},
    ))

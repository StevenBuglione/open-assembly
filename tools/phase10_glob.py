"""Run independent source-bound pathname expansion checks."""

from pathlib import Path

from phase6 import execute_manifest_gate, phase6_inputs
from spec import ROOT, snapshot_inputs

SUITE = Path("tests/phase10/glob")


def inputs():
    bound = phase6_inputs()
    bound.update(snapshot_inputs(ROOT, [Path("docs/adr/0030-pathname-expansion.md")]))
    return dict(sorted(bound.items()))


if __name__ == "__main__":
    raise SystemExit(execute_manifest_gate(
        "phase10-glob", SUITE, {"glob", "globfree"},
        {SUITE / "errors.c": ("readdir",), SUITE / "lifetime.c": ("malloc", "calloc", "realloc", "free")},
        (), inputs, "OA_PHASE10_HOST", {"limits": [
            "POSIX pathname expansion and project error-retention semantics.",
            "Each case creates its own local directory tree and symlinks.",
        ]},
    ))

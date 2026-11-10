"""Run independent wide-modifier tests against the inherited byte stdio family."""

from pathlib import Path

from phase6 import execute_manifest_gate, phase6_inputs
from spec import ROOT, snapshot_inputs

SUITE = Path("tests/phase9/narrow-wide")
PUBLIC = {
    "printf", "fprintf", "sprintf", "snprintf", "vprintf", "vfprintf",
    "vsprintf", "vsnprintf", "vasprintf",
    "scanf", "fscanf", "sscanf", "vscanf", "vfscanf", "vsscanf",
}


def inputs():
    hashes = phase6_inputs()
    hashes.update(snapshot_inputs(ROOT, [Path("docs/adr") / filename for filename in (
        "0032-narrow-printf-wide-conversions.md", "0033-narrow-scanf-wide-conversions.md",
    )]))
    return dict(sorted(hashes.items()))


if __name__ == "__main__":
    raise SystemExit(execute_manifest_gate(
        "phase9-narrow-wide", SUITE, PUBLIC, {}, (), inputs, "OA_PHASE9_HOST", {"limits": [
            "Wide argument and destination modifiers in the inherited byte stdio family.",
            "Hosted comparisons apply to common behavior. Project byte-width scanf follows the C17 oracle.",
        ]},
    ))

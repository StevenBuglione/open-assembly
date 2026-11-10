"""Audit current artifact-bound transcendental ledgers for nightly and release."""

import argparse
from pathlib import Path
import re
import sys

from audit import audit
from campaign import (ARTIFACTS, BINARY_BACKEND, BINARY_OPERATIONS, DOMAIN, NATIVE_BACKEND, OPERATIONS,
                      atomic_json, digest, identity, oracle_artifact_names, read_json)

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
from extensions import confined
from phase7_transcendental import input_snapshot
from spec import ROOT, SpecError, regular_file, relative_path

BUILD = Path("build")
REPORT = BUILD / "evidence/phase7-campaigns.json"
MODES = tuple(range(4))


def inventory():
    operations = {}
    for line in (ROOT / OPERATIONS).read_text().splitlines():
        match = re.fullmatch(r"OP(2?)\(([a-z0-9]+)\)", line)
        if match is None or match[2] in operations:
            raise ValueError("invalid transcendental operation inventory")
        operations[match[2]] = bool(match[1])
    return operations


def settings_for(folder, operations):
    metadata = read_json(regular_file(ROOT, folder.relative_to(ROOT) / "campaign.json", "math campaign"))
    settings = metadata["settings"]
    if type(settings) is not dict or settings.get("schema") != 1 or identity(settings) != metadata.get("id"):
        raise ValueError("campaign metadata does not match its immutable identity")
    operation, mode, second = (settings[key] for key in ("operation", "mode_index", "second_bits"))
    if (type(operation) is not str or operation not in operations or type(mode) is not int
            or mode not in MODES or operations[operation] != (second is not None)
            or second is not None and (type(second) is not int or not 0 <= second < DOMAIN)):
        raise ValueError("invalid operation, rounding mode or fixed second operand")
    start, count, width = (settings[key] for key in ("start", "count", "width"))
    if (any(type(value) is not int for value in (start, count, width))
            or not 0 <= start < DOMAIN or not 1 <= width <= count <= DOMAIN - start):
        raise ValueError("invalid binary32 ledger interval")
    return metadata["id"], settings


def observe(folder, operations, current):
    campaign_id, settings = settings_for(folder, operations)
    gate_path = regular_file(ROOT, folder.relative_to(ROOT) / "source-gate.json", "math campaign source gate")
    gate = read_json(gate_path)
    if (digest(gate_path) != settings["source_gate_sha256"]
            or gate.get("scope") != "phase7-transcendental" or gate.get("outcome") != "pass"
            or type(gate.get("inputs")) is not dict
            or identity(gate["inputs"]) != settings["source_snapshot_sha256"]):
        raise ValueError("invalid source-bound transcendental report")
    backend = settings["oracle"]["backend"]
    if (set(settings["artifacts"]) != set(ARTIFACTS)
            or set(settings["oracle_artifacts"]) != set(oracle_artifact_names(backend))
            or backend == NATIVE_BACKEND and settings["second_bits"] is not None
            or backend == BINARY_BACKEND and settings["operation"] not in BINARY_OPERATIONS):
        raise ValueError("invalid campaign artifact or oracle inventory")
    if gate["inputs"] != current:
        return {"outcome": "historical", "campaign_id": campaign_id,
                "operation": settings["operation"], "mode_index": settings["mode_index"],
                "fixed_second_operand_bits": settings["second_bits"],
                "source_gate_sha256": settings["source_gate_sha256"],
                "source_snapshot_sha256": settings["source_snapshot_sha256"],
                "candidate_sha256": settings["artifacts"]["trans-f32"],
                "archive_sha256": settings["artifacts"]["libopenasm.a"],
                "reason": "The ledger names a different source snapshot."}
    paths = (folder / "artifacts").resolve(strict=True)
    if paths != folder / "artifacts":
        raise ValueError("campaign artifacts are outside the recorded path")
    for name in settings["artifacts"] | settings["oracle_artifacts"]:
        regular_file(ROOT, paths.relative_to(ROOT) / name, "math campaign artifact")
    for name in ("checkpoints", "attempts"):
        directory = confined(ROOT, (folder / name).relative_to(ROOT))
        if not directory.is_dir():
            raise ValueError(f"missing campaign {name}")
        for path in directory.glob("*.json"):
            regular_file(ROOT, path.relative_to(ROOT), "math ledger entry")
    result = audit(folder, ROOT)
    if result["failed_shards_this_run"] or result["observed_semantic_failures"]:
        raise ValueError("campaign has unresolved failed shards")
    full = (result["requested_interval_complete"] is True
            and result["first_pattern"] == 0
            and result["covered_patterns"] == result["requested_patterns"] == result["contiguous_prefix_end"] == DOMAIN
            and result["passed_shards"] == result["total_shards"]
            and type(result["max_finite_ulp"]) is int and 0 <= result["max_finite_ulp"] <= 1)
    if (result["complete_binary32_axis"] is not full
            or result["complete_domain"] is not (full and settings["second_bits"] is None)):
        raise ValueError("invalid binary32 completion scope")
    return {"outcome": "pass" if full else "partial", **result}


def collect(root, operations, current):
    ledgers, unary, binary = {}, set(), {}
    if not root.exists():
        folders = ()
    elif not root.is_dir():
        raise ValueError("campaign root must be a directory")
    elif (root / "campaign.json").exists():
        folders = (root,)
    else:
        folders = sorted(path for path in root.iterdir() if path.is_dir() and (path / "campaign.json").exists())

    for folder in folders:
        relative = folder.relative_to(ROOT)
        try:
            confined(ROOT, relative)
            result = observe(folder, operations, current)
        except (KeyError, OSError, RuntimeError, SpecError, TypeError, ValueError) as error:
            result = {"outcome": "fail", "error": str(error)}
        ledgers[relative.as_posix()] = result
        if result["outcome"] != "pass":
            continue
        key = (result["operation"], result["mode_index"])
        second = result["fixed_second_operand_bits"]
        if second is None:
            unary.add(key)
        else:
            binary.setdefault(key, set()).add(second)

    required = {(name, mode) for name, two_arguments in operations.items() if not two_arguments for mode in MODES}
    missing = [[name, mode] for name, mode in sorted(required - unary)]
    axes = {name: {str(mode): {"required_second_operands": DOMAIN,
                               "covered_second_operands": len(binary.get((name, mode), ()))}
                   for mode in MODES}
            for name, two_arguments in operations.items() if two_arguments}
    binary_complete = all(row["covered_second_operands"] == DOMAIN
                          for operation in axes.values() for row in operation.values())
    outcomes = {result["outcome"] for result in ledgers.values()}
    outcome = "fail" if "fail" in outcomes else "pending" if missing or not binary_complete else "pass"
    return {"outcome": outcome, "ledgers": ledgers,
            "unary": {"required": len(required), "verified": len(unary), "missing_operation_modes": missing},
            "binary": {"complete_cartesian_domain": binary_complete, "first_operand_axes_by_mode": axes}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("campaign_root")
    args = parser.parse_args()
    report = {"schema_version": 1, "scope": "phase7-binary32-campaigns", "outcome": "fail"}
    try:
        relative = relative_path(args.campaign_root, "math campaign root")
        if relative == BUILD or not relative.is_relative_to(BUILD):
            raise ValueError("campaign root must be inside build/")
        root = confined(ROOT, relative)
        current = input_snapshot()
        report.update(campaign_root=relative.as_posix(), source_snapshot_sha256=identity(current),
                      **collect(root, inventory(), current))
    except (KeyError, OSError, SpecError, TypeError, ValueError) as error:
        report["error"] = str(error)
    path = ROOT / REPORT
    path.parent.mkdir(parents=True, exist_ok=True)
    atomic_json(path, report)
    print(f"{report['outcome'].upper()} binary32 campaign evidence {REPORT}", flush=True)
    return int(report["outcome"] == "fail")


if __name__ == "__main__":
    raise SystemExit(main())

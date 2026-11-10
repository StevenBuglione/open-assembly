"""Read atomically published checkpoints while a campaign is running."""

import argparse
import json
from pathlib import Path

from campaign import atomic_json, checkpoints, identity, partition, read_json, summary, verify_campaign


def audit(folder, root):
    campaign = verify_campaign(folder, root)
    settings = campaign["settings"]
    intervals = list(partition(settings["start"], settings["count"], settings["width"]))
    done = checkpoints(folder, campaign, intervals)
    failures = [read_json(path) for path in sorted((folder / "attempts").glob("failure-*.json"))]
    if any(type(item.get("semantic_failure")) is not bool for item in failures):
        raise ValueError("invalid campaign failure record")
    result = summary(folder, campaign, intervals, done, 0, 0.0, len(failures))
    result["observed_semantic_failures"] = sum(item["semantic_failure"] for item in failures)
    result["complete_domain"] = result["complete_domain"] and not failures
    result["complete_binary32_axis"] = result["complete_binary32_axis"] and not failures
    result["checkpoint_set_sha256"] = identity([[start, identity(done[start])] for start in sorted(done)])
    result["source_snapshot_sha256"] = settings["source_snapshot_sha256"]
    result["oracle_identity_sha256"] = identity(settings["oracle"])
    if verify_campaign(folder, root) != campaign:
        raise ValueError("campaign inputs changed during the ledger audit")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("campaign", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    folder = args.campaign.resolve(strict=True)
    root = Path.cwd().resolve()
    result = audit(folder, root)
    if args.output:
        atomic_json(args.output, result)
    print(json.dumps(result, indent=2, sort_keys=True))
    return int(bool(result["failed_shards_this_run"]))


if __name__ == "__main__":
    raise SystemExit(main())

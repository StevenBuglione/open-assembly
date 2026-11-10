"""Read atomically published checkpoints while a campaign is running."""

import argparse
import json
from pathlib import Path

from campaign import atomic_json, checkpoints, partition, read_json, summary, verify_campaign


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("campaign", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    folder = args.campaign.resolve(strict=True)
    root = Path.cwd().resolve()
    campaign = verify_campaign(folder, root)
    settings = campaign["settings"]
    intervals = list(partition(settings["start"], settings["count"], settings["width"]))
    done = checkpoints(folder, campaign, intervals)
    failures = [read_json(path) for path in (folder / "attempts").glob("failure-*.json")]
    result = summary(folder, campaign, intervals, done, 0, 0.0, len(failures))
    result["observed_semantic_failures"] = sum(item["semantic_failure"] for item in failures)
    result["complete_domain"] = result["complete_domain"] and not failures
    result["complete_binary32_axis"] = result["complete_binary32_axis"] and not failures
    if args.output:
        atomic_json(args.output, result)
    print(json.dumps(result, indent=2, sort_keys=True))
    return int(bool(failures))


if __name__ == "__main__":
    raise SystemExit(main())

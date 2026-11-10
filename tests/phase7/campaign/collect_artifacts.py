"""Rebuild the four binary32 campaign artifacts and require the gate's hashes."""

import argparse
from pathlib import Path
import shutil
import sys
import tempfile

from campaign import digest, read_json, source_inputs

sys.path.insert(0, str(Path(__file__).resolve().parents[3] / "tools"))
from phase1 import build_runtime
from phase7_transcendental import build_fixtures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("gate", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    root = Path.cwd().resolve()
    gate = read_json(args.gate)
    hashes = source_inputs(gate, root)
    log = []
    with tempfile.TemporaryDirectory(dir="build", prefix="campaign-artifacts-") as workspace:
        work = Path(workspace).resolve().relative_to(root)
        runtime = build_runtime(work / "runtime", log)
        fixtures = work / "fixtures"
        build_fixtures(fixtures, runtime, log)
        sources = {path.name: path for path in (*runtime[:2], fixtures / "trans-f32.o",
                                                fixtures / "trans-f32")}
        if set(sources) != set(hashes) or any(digest(path) != hashes[name]
                                               for name, path in sources.items()):
            raise ValueError("rebuild did not reproduce the four passing gate artifacts")
        if source_inputs(gate, root) != hashes:
            raise ValueError("source snapshot changed during artifact rebuild")
        args.output.mkdir(parents=True, exist_ok=False)
        for name, path in sources.items():
            shutil.copy2(path, args.output / name)
    print(f"PASS reproduced {len(hashes)} campaign artifacts in {args.output}")


if __name__ == "__main__":
    main()

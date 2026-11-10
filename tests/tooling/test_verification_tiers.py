"""Exercise fail-closed validation of tier evidence files and budgets."""

import json
import os
from pathlib import Path
import sys
import tempfile
from time import time_ns
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from gate import GateError
from production import libfuzzer_seconds
from spec import snapshot_inputs
from verify_tiers import evidence_json, fresh_report, invoke


class TierEvidence(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        for path in ("Makefile", "devenv.lock"):
            (self.root / path).write_text(f"original {path}\n")
        directory = self.root / "build/evidence"
        directory.mkdir(parents=True)
        self.report = directory / "gate.json"
        self.started = time_ns()
        self.data = {"schema_version": 1, "scope": "phase", "outcome": "pass",
                     "inputs": snapshot_inputs(self.root, ["Makefile", "devenv.lock"])}
        self.save()

    def save(self):
        self.report.write_text(json.dumps(self.data))

    def check(self):
        return fresh_report(self.root, "gate.json", "phase", self.started)

    def test_accepts_exact_current_report(self):
        self.assertEqual(self.check(), (self.report, self.data))

    def test_rejects_missing_report(self):
        self.report.unlink()
        with self.assertRaisesRegex(ValueError, "missing regular file"):
            self.check()

    def test_rejects_report_older_than_command(self):
        os.utime(self.report, ns=(self.started - 1, self.started - 1))
        with self.assertRaisesRegex(GateError, "no fresh report"):
            self.check()

    def test_rejects_wrong_scope_or_outcome(self):
        for key, bad in (("scope", "other"), ("outcome", "fail")):
            with self.subTest(key=key):
                good = self.data[key]
                self.data[key] = bad
                self.save()
                with self.assertRaisesRegex(GateError, "expected a passing phase report"):
                    self.check()
                self.data[key] = good

    def test_rejects_changed_or_omitted_inputs(self):
        (self.root / "Makefile").write_text("changed\n")
        with self.assertRaisesRegex(GateError, "stale evidence inputs: Makefile"):
            self.check()
        self.data["inputs"].pop("Makefile")
        self.save()
        with self.assertRaisesRegex(GateError, "missing source-bound identities"):
            self.check()

    def test_rejects_ambiguous_json(self):
        self.report.write_text('{"scope":"one","scope":"two"}')
        with self.assertRaisesRegex(GateError, "duplicate evidence key"):
            evidence_json(self.report)
        self.report.write_text('{"observations":Infinity}')
        with self.assertRaisesRegex(GateError, "invalid JSON number"):
            evidence_json(self.report)

    def test_rejects_out_of_scope_report_path(self):
        with self.assertRaisesRegex(GateError, "expected a report filename"):
            fresh_report(self.root, "../../gate.json", "phase", self.started)

    def test_rejects_child_failure(self):
        result = {}
        with self.assertRaisesRegex(GateError, "exited 23"):
            invoke([sys.executable, "-c", "raise SystemExit(23)"], result, timeout=5)
        self.assertEqual(result["returncode"], 23)

    def test_rejects_timed_out_child(self):
        result = {}
        with self.assertRaisesRegex(GateError, "exceeded"):
            invoke([sys.executable, "-c", "import time; time.sleep(10)"], result, timeout=0.1)
        self.assertTrue(result["timed_out"])

    def test_fuzz_budget_cannot_be_reduced(self):
        with patch.dict(os.environ, {"OPEN_ASSEMBLY_LIBFUZZER_SECONDS": "59"}):
            with self.assertRaisesRegex(GateError, "from 60 to 3600"):
                libfuzzer_seconds()
        with patch.dict(os.environ, {"OPEN_ASSEMBLY_LIBFUZZER_SECONDS": "300"}):
            self.assertEqual(libfuzzer_seconds(), 300)


if __name__ == "__main__":
    unittest.main()

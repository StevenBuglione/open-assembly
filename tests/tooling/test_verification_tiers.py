"""Exercise fail-closed validation of tier evidence files and budgets."""

from copy import deepcopy
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
from math_production import SCOPE as MATH_WRAPPER_SCOPE, SECONDS as MATH_WRAPPER_SECONDS, WRAPPERS
from production import libfuzzer_seconds
from spec import sha256_file, snapshot_inputs
from musl_authorship import ARCHIVE_SHA256, POLICY
from verify_tiers import check_allocator_benchmark, check_authorship, evidence_json, fresh_report, invoke, math_wrapper_report


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

    def test_math_wrapper_batch_requires_all_fresh_scoped_children(self):
        directory = self.report.parent
        batch = directory / "math-wrappers.json"
        children = {}
        aggregate = {"schema_version": 1, "scope": f"{MATH_WRAPPER_SCOPE}-batch", "outcome": "pass",
                     "production_verified": False, "full_scope": True, "total": 4, "passed": 4,
                     "functions": children}
        for name, (operation, width, engine) in WRAPPERS.items():
            child = directory / f"{name}.math-wrapper.json"
            checks = {key: {"outcome": "pass"} for key in (
                "abi", "branch_coverage", "candidate_build", "differential_fuzz", "generated_outputs",
                "generated_stub", "native_oracles", "production_mutation")}
            checks["candidate_build"]["archive_sha256"] = "0" * 64
            checks["dependency_closure"] = {"outcome": "pending", "engine": engine}
            checks["differential_fuzz"].update(oracle="reference:mpfr", requested_seconds=MATH_WRAPPER_SECONDS,
                                               elapsed_s=MATH_WRAPPER_SECONDS, records=512)
            record = {**self.data, "scope": MATH_WRAPPER_SCOPE, "function": name, "operation": operation,
                      "format_bits": width, "production_verified": False, "wrapper_checks_passed": True,
                      "checks": checks}
            child.write_text(json.dumps(record))
            children[name] = {"evidence": child.relative_to(self.root).as_posix(), "outcome": "pass",
                              "evidence_sha256": sha256_file(child)}
        batch.write_text(json.dumps(aggregate))
        with patch("verify_tiers.ROOT", self.root), patch("verify_tiers.math_wrapper_inputs", return_value=self.data["inputs"]):
            self.assertEqual(math_wrapper_report(self.started), (batch, aggregate))
            child = directory / "exp2f.math-wrapper.json"
            original = evidence_json(child)
            for changed in ({**original, "production_verified": True},
                            {**original, "checks": {**original["checks"], "dependency_closure": {"outcome": "pass"}}}):
                child.write_text(json.dumps(changed))
                children["exp2f"]["evidence_sha256"] = sha256_file(child)
                batch.write_text(json.dumps(aggregate))
                with self.assertRaisesRegex(GateError, "pending engine closure"):
                    math_wrapper_report(self.started)
            os.utime(child, ns=(self.started - 1, self.started - 1))
            with self.assertRaisesRegex(GateError, "no fresh report"):
                math_wrapper_report(self.started)

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

    def test_allocator_benchmark_caps(self):
        timing = [{"pair": i, "checksum": 3, "nanoseconds": 100000, "cpu_nanoseconds": 100000}
                  for i in range(1, 10)]
        samples = {"openasm": timing, "musl": timing}
        measurements = {name: {"samples": samples, "ratio": 1.0} for name in ("small", "mixed", "growth")}
        rss = {}
        for kind, excess in (("openasm", 8192), ("musl", 0)):
            rss[kind] = [{"pair": i, "checksum": 3, "baseline_kib": 1, "peak_kib": 9999,
                          "retained_kib": 2 + excess, "released_kib": 2} for i in range(1, 10)]
        measurements["rss"] = {"samples": rss, "openasm_excess_kib": {
            "retained_delta_kib": 8192, "released_delta_kib": 0,
        }}
        record = {"measurements": measurements, "geometric_mean": 1.0,
                  "workload": {"pairs": 9, "min_preflight_idle": 0.9, "geometric_mean_limit": 1.25,
                               "per_workload_limit": 1.5, "max_rss_excess_kib": 8192}}
        check_allocator_benchmark(record)
        measurements["rss"]["openasm_excess_kib"]["retained_delta_kib"] = 8193
        with self.assertRaisesRegex(GateError, "RSS cap"):
            check_allocator_benchmark(record)
        measurements["rss"]["openasm_excess_kib"]["retained_delta_kib"] = 8192
        record["geometric_mean"] = 1.25
        with self.assertRaisesRegex(GateError, "geometric mean cap"):
            check_allocator_benchmark(record)

    def test_authorship_scan_binds_controls_inventory_and_review(self):
        hash_value = "b" * 64
        fingerprint = {"instructions": 30, "sha256": "c" * 64}
        copied = {"classification": "normalized-exact", "candidate": fingerprint,
                  "reference": fingerprint, "similarity_per_mille": 1000, "object_sha256": "d" * 64}
        distinct = {"classification": "clear", "reference": fingerprint, "object_sha256": "e" * 64}
        row = {"symbol": "setjmp", "classification": "normalized-near"}
        scan = {"musl_archive_sha256": ARCHIVE_SHA256, "candidate_archive_sha256": hash_value,
                "policy": POLICY, "symbols": [row], "counts": {"normalized-near": 1},
                "controls": {"symbol": "strlen", "copied": copied, "distinct": distinct,
                             "reference_member_sha256": "f" * 64}}
        review = {"scan_sha256": hash_value, "scan_outcome": "pass", "items": [row]}
        self.assertEqual(check_authorship(scan, review, hash_value, {"setjmp"}), ["setjmp"])
        with self.assertRaisesRegex(GateError, "pinned scan inventory"):
            check_authorship(scan, review, hash_value, {"setjmp", "_setjmp"})
        wrong = deepcopy(scan)
        wrong["controls"]["copied"]["classification"] = "clear"
        with self.assertRaisesRegex(GateError, "relocation and distinct controls"):
            check_authorship(wrong, review, hash_value, {"setjmp"})
        with self.assertRaisesRegex(GateError, "exact passing scan"):
            check_authorship(scan, {**review, "items": []}, hash_value, {"setjmp"})
        with self.assertRaisesRegex(GateError, "exact passing scan"):
            check_authorship(scan, review, "a" * 64, {"setjmp"})

    def test_fuzz_budget_cannot_be_reduced(self):
        with patch.dict(os.environ, {"OPEN_ASSEMBLY_LIBFUZZER_SECONDS": "59"}):
            with self.assertRaisesRegex(GateError, "from 60 to 3600"):
                libfuzzer_seconds()
        with patch.dict(os.environ, {"OPEN_ASSEMBLY_LIBFUZZER_SECONDS": "300"}):
            self.assertEqual(libfuzzer_seconds(), 300)


if __name__ == "__main__":
    unittest.main()

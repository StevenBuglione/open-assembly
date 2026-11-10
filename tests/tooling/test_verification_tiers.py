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
from runtime_manifest_gate import (FILENO_DESCRIPTORLESS, FILENO_REVIEW, FUZZ_SEED, PLANS as MANIFEST_PLANS,
                                   REQUIRED_CHECKS as MANIFEST_CHECKS, bind_descriptorless_scope,
                                   manifest_dependency_bindings, pending_dependency)
from verify_tiers import (MANIFEST_PRODUCTION_GROUPS, PHASES, SCOPED_WRAPPER_BATCHES, check_allocator_benchmark,
                          check_authorship, evidence_json, fresh_report, gate, invoke, manifest_production_reports,
                          math_wrapper_report, scoped_wrapper_report)


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

    def manifest_reports(self):
        sources, records = {}, {}
        self.enterContext(patch("verify_tiers.ROOT", self.root))
        self.enterContext(patch("verify_tiers.source_paths", return_value=sources))
        self.enterContext(patch("verify_tiers.manifest_inputs", side_effect=lambda name: records[name]["inputs"]))
        self.enterContext(patch("runtime_manifest_gate.ROOT", self.root))
        self.enterContext(patch("runtime_manifest_gate.manifest_inputs", side_effect=lambda name: records[name]["inputs"]))
        for symbols in MANIFEST_PRODUCTION_GROUPS.values():
            for name in symbols:
                source = Path(f"src/x86_64-linux/posix/{name}.asm")
                (self.root / source).parent.mkdir(parents=True, exist_ok=True)
                (self.root / source).write_text(f"source for {name}\n")
                hashes = snapshot_inputs(self.root, ["Makefile", "devenv.lock", source])
                checks = {key: {"outcome": "pass"} for key in MANIFEST_CHECKS}
                checks["candidate_build"].update(source=source.as_posix(), source_sha256=hashes[source.as_posix()],
                                                 object_sha256="c" * 64)
                checks["differential_fuzz"].update(
                    elapsed_s=60.01, records=512, runs=["candidate", "glibc", "musl"],
                    sha256={"candidate": "a" * 64, "glibc": "a" * 64, "musl": "a" * 64, "input": "b" * 64})
                archive = {"libopenasm.a": "d" * 64}
                checks["runtime_build"]["artifacts"] = {"first": archive, "second": archive}
                if required := MANIFEST_PLANS[name].required_production:
                    checks["production_dependencies"] = manifest_dependency_bindings(required)
                record = {**self.data, "scope": "production-runtime-manifest-function", "function": name,
                          "production_verified": True, "inputs": hashes, "checks": checks}
                path = self.report.parent / f"{name}.production.json"
                path.write_text(json.dumps(record))
                sources[name] = source
                records[name] = record
        return records

    def test_manifest_production_tier_runs_and_binds_every_fresh_child(self):
        self.manifest_reports()
        self.assertTrue(MANIFEST_PRODUCTION_GROUPS.keys() <= set(PHASES))
        self.assertEqual({name for group in MANIFEST_PRODUCTION_GROUPS.values() for name in group},
                         {"getpid", "getppid", "pipe", "pipe2", "open", "openat", "readlink", "unlink", "rmdir",
                          "waitpid", "wait", "execve", "execv"})
        with patch("verify_tiers.time_ns", return_value=self.started):
            for group, symbols in MANIFEST_PRODUCTION_GROUPS.items():
                with self.subTest(group=group), patch("verify_tiers.invoke") as invoke_gate:
                    result = {}
                    gate(group, result)
                    self.assertEqual(invoke_gate.call_args.args[0], ["make", "--no-print-directory", group])
                    self.assertEqual(tuple(result["children"]), symbols)
                    for name, child in result["children"].items():
                        self.assertEqual(child, {"outcome": "pass", "evidence": f"build/evidence/{name}.production.json",
                                                 "evidence_sha256": sha256_file(self.root / child["evidence"])})

    def test_manifest_production_rejects_missing_stale_and_incomplete_children(self):
        records = self.manifest_reports()
        group = "production-pipes"
        name = "pipe2"
        path = self.report.parent / f"{name}.production.json"

        path.unlink()
        with self.assertRaisesRegex(ValueError, "missing regular file"):
            manifest_production_reports(self.started, group)
        path.write_text(json.dumps(records[name]))
        os.utime(path, ns=(self.started - 1, self.started - 1))
        with self.assertRaisesRegex(GateError, "no fresh report"):
            manifest_production_reports(self.started, group)
        path.write_text(json.dumps(records[name]))
        source = self.root / records[name]["checks"]["candidate_build"]["source"]
        original = source.read_text()
        source.write_text("different source\n")
        with self.assertRaisesRegex(GateError, "stale evidence inputs"):
            manifest_production_reports(self.started, group)
        source.write_text(original)

        for key, value, error in (("scope", "phase6-process", "expected a passing"),
                                  ("function", "pipe", "input snapshot"),
                                  ("production_verified", False, "timed candidate/glibc/musl"),
                                  ("inputs", self.data["inputs"], "input snapshot"),
                                  ("checks", {"abi": {"outcome": "pass"}}, "incomplete manifest production checks")):
            with self.subTest(key=key):
                path.write_text(json.dumps({**records[name], key: value}))
                with self.assertRaisesRegex(GateError, error):
                    manifest_production_reports(self.started, group)

        changed = deepcopy(records[name])
        changed["checks"]["candidate_build"]["source_sha256"] = "0" * 64
        path.write_text(json.dumps(changed))
        with self.assertRaisesRegex(GateError, "does not bind the candidate source"):
            manifest_production_reports(self.started, group)
        for object_hash in (None, "not a SHA-256"):
            with self.subTest(object_hash=object_hash):
                changed = deepcopy(records[name])
                candidate = changed["checks"]["candidate_build"]
                if object_hash is None:
                    del candidate["object_sha256"]
                else:
                    candidate["object_sha256"] = object_hash
                path.write_text(json.dumps(changed))
                with self.assertRaisesRegex(GateError, "does not bind the candidate source and object"):
                    manifest_production_reports(self.started, group)

    def test_manifest_production_rejects_incomplete_three_way_packets(self):
        name = "getpid"
        records = self.manifest_reports()
        path = self.report.parent / f"{name}.production.json"
        for field, value in (("elapsed_s", 59.99), ("elapsed_s", "infinite"), ("records", 0),
                             ("runs", ["candidate", "glibc"]), ("sha256", {"candidate": "a" * 64}),
                             ("sha256", dict(candidate="a" * 64, glibc="a" * 64, musl="b" * 64, input="c" * 64)),
                             ("sha256", dict(candidate="same", glibc="same", musl="same", input="c" * 64))):
            with self.subTest(field=field, value=value):
                changed = deepcopy(records[name])
                changed["checks"]["differential_fuzz"][field] = value
                path.write_text(json.dumps(changed))
                with self.assertRaisesRegex(GateError, "timed candidate/glibc/musl"):
                    manifest_production_reports(self.started, "production-process-identity")
        overflowing_elapsed = json.dumps(records[name]).replace('"elapsed_s": 60.01', '"elapsed_s": 1e999')
        path.write_text(overflowing_elapsed)
        with self.assertRaisesRegex(GateError, "timed candidate/glibc/musl"):
            manifest_production_reports(self.started, "production-process-identity")

    def test_manifest_production_rejects_missing_dependency_binding_or_wrong_archive(self):
        records = self.manifest_reports()
        for group, dependent in (("production-wait", "wait"), ("production-exec", "execv")):
            path = self.report.parent / f"{dependent}.production.json"
            record = records[dependent]
            without_binding = deepcopy(record)
            del without_binding["checks"]["production_dependencies"]
            other_archive = deepcopy(record)
            other_archive["checks"]["runtime_build"]["artifacts"] = {
                stage: {"libopenasm.a": "0" * 64} for stage in ("first", "second")}
            for changed in (without_binding, other_archive):
                with self.subTest(group=group, changed=changed["checks"].keys()):
                    path.write_text(json.dumps(changed))
                    with self.assertRaisesRegex(GateError, "differs from this invocation's child and archive"):
                        manifest_production_reports(self.started, group)
            path.write_text(json.dumps(record))
            dependency, = MANIFEST_PLANS[dependent].required_production
            child = self.report.parent / f"{dependency}.production.json"
            original = child.read_bytes()
            child.write_bytes(original + b" ")
            with self.assertRaisesRegex(GateError, "differs from this invocation's child and archive"):
                manifest_production_reports(self.started, group)
            child.write_bytes(original)
            self.assertEqual(tuple(manifest_production_reports(self.started, group)), (dependency, dependent))

    def scoped_reports(self):
        sources, records, groups = {}, {}, {}
        review = self.root / FILENO_REVIEW
        review.parent.mkdir(parents=True)
        review.write_text("scoped descriptor review\n")
        for target, (suffix, functions) in SCOPED_WRAPPER_BATCHES.items():
            batch = self.report.parent / f"{suffix}s.json"
            aggregate = {**self.data, "scope": f"{suffix}-verification-batch", "production_verified": False,
                         "full_scope": True, "passed": len(functions), "total": len(functions), "functions": {}}
            del aggregate["inputs"]
            groups[target] = batch, aggregate
            for name in sorted(functions):
                source = Path(f"src/x86_64-linux/stdio/{name}.asm")
                (self.root / source).parent.mkdir(parents=True, exist_ok=True)
                (self.root / source).write_text(f"source for {name}\n")
                paths = ["Makefile", "devenv.lock", source]
                if name == "fileno":
                    paths.append(FILENO_REVIEW)
                inputs = snapshot_inputs(self.root, paths)
                checks = {key: {"outcome": "pass"} for key in MANIFEST_CHECKS}
                checks["dependency_closure"] = pending_dependency(MANIFEST_PLANS[name])
                checks["candidate_build"].update(source=source.as_posix(), source_sha256=inputs[source.as_posix()],
                                                 object_sha256="c" * 64)
                runtime = {"crt1.o": "d" * 64, "libopenasm.a": "e" * 64, f"obj/stdio/{name}.o": "c" * 64}
                checks["runtime_build"]["artifacts"] = {"first": runtime, "second": runtime.copy()}
                checks["differential_fuzz"].update(
                    elapsed_s=60.01, seed=FUZZ_SEED, records=512, runs=["candidate", "glibc", "musl"],
                    sha256={"candidate": "a" * 64, "glibc": "a" * 64, "musl": "a" * 64, "input": "b" * 64})
                if name == "fileno":
                    self.enterContext(patch.dict(FILENO_DESCRIPTORLESS, source_sha256=inputs[source.as_posix()]))
                    edge = {"source": source.as_posix(), "line": 38, "instruction": "js"}
                    branch = {"outcome": "partial", "covered": 1, "total": 2, "edges": [
                        {**edge, "branch": "taken", "covered": False}, {**edge, "branch": "fallthrough", "covered": True},
                    ]}
                    bind_descriptorless_scope(self.root / source, branch, inputs)
                    checks["branch_coverage"] = branch
                child = self.report.parent / f"{name}.{suffix}.json"
                record = {**self.data, "scope": f"{suffix}-verification", "function": name,
                          "production_verified": False, "inputs": inputs, "checks": checks}
                child.write_text(json.dumps(record))
                aggregate["functions"][name] = {"outcome": "pass", "evidence": child.relative_to(self.root).as_posix(),
                                                "evidence_sha256": sha256_file(child)}
                sources[name], records[name] = source, record
            batch.write_text(json.dumps(aggregate))
        self.enterContext(patch("verify_tiers.ROOT", self.root))
        self.enterContext(patch("verify_tiers.source_paths", return_value=sources))
        self.enterContext(patch("verify_tiers.manifest_inputs", side_effect=lambda name: records[name]["inputs"]))
        return groups, records

    def test_scoped_wrapper_tiers_run_and_bind_exact_pending_children(self):
        groups, _ = self.scoped_reports()
        self.assertTrue(SCOPED_WRAPPER_BATCHES.keys() <= set(PHASES))
        with patch("verify_tiers.time_ns", return_value=self.started):
            for target, (batch, aggregate) in groups.items():
                with self.subTest(target=target), patch("verify_tiers.invoke") as invoke_gate:
                    result = {}
                    gate(target, result)
                    self.assertEqual(invoke_gate.call_args.args[0], ["make", "--no-print-directory", target])
                    self.assertEqual(result["children"], aggregate["functions"])
                    self.assertEqual(result["evidence_sha256"], sha256_file(batch))
                    self.assertIs(result["production_verified"], False)
                    self.assertEqual(result["dependency_closure"], {"outcome": "pending"})

    def test_scoped_wrapper_batch_rejects_missing_stale_or_replaced_evidence(self):
        groups, records = self.scoped_reports()
        target = "verify-stream-indicators"
        batch, aggregate = groups[target]
        child = self.root / aggregate["functions"]["fileno"]["evidence"]
        child.unlink()
        with self.assertRaisesRegex(ValueError, "missing regular file"):
            scoped_wrapper_report(self.started, target)
        child.write_text(json.dumps(records["fileno"]))
        os.utime(child, ns=(self.started - 1, self.started - 1))
        with self.assertRaisesRegex(GateError, "no fresh report"):
            scoped_wrapper_report(self.started, target)
        child.write_text(json.dumps(records["fileno"]) + "\n")
        with self.assertRaisesRegex(GateError, "invalid fresh scoped wrapper evidence"):
            scoped_wrapper_report(self.started, target)
        child.write_text(json.dumps(records["fileno"]))
        for changed in ({**aggregate, "production_verified": True},
                        {**aggregate, "functions": {key: item for key, item in aggregate["functions"].items()
                                                    if key != "fileno"}}):
            batch.write_text(json.dumps(changed))
            with self.assertRaisesRegex(GateError, "incomplete scoped wrapper batch"):
                scoped_wrapper_report(self.started, target)

    def test_scoped_wrapper_children_reject_promotion_short_runs_and_wrong_identity(self):
        groups, records = self.scoped_reports()
        target = "verify-allocator-wrappers"
        batch, aggregate = groups[target]
        name = "malloc"
        row = aggregate["functions"][name]
        child = self.root / row["evidence"]
        for field, value, error in (
            ("production_verified", True, "pending shared closure"),
            ("dependency_closure", {"outcome": "pass", "engine": "__al_heap"}, "pending shared closure"),
            ("elapsed_s", 59.99, "timed candidate/glibc/musl"),
            ("records", 513, "incomplete seeded packet batches"),
            ("sha256", {"candidate": "a" * 64, "glibc": "a" * 64, "musl": "b" * 64, "input": "b" * 64},
             "timed candidate/glibc/musl"),
            ("object_sha256", "f" * 64, "does not bind the source, object, and runtime"),
        ):
            with self.subTest(field=field):
                changed = deepcopy(records[name])
                checks = changed["checks"]
                destination = {"production_verified": changed, "dependency_closure": checks,
                               "object_sha256": checks["candidate_build"]}.get(field, checks["differential_fuzz"])
                destination[field] = value
                child.write_text(json.dumps(changed))
                row["evidence_sha256"] = sha256_file(child)
                batch.write_text(json.dumps(aggregate))
                with self.assertRaisesRegex(GateError, error):
                    scoped_wrapper_report(self.started, target)

    def test_scoped_wrapper_fileno_requires_the_actual_descriptor_review(self):
        groups, records = self.scoped_reports()
        target = "verify-stream-indicators"
        batch, aggregate = groups[target]
        row = aggregate["functions"]["fileno"]
        child = self.root / row["evidence"]
        changed = deepcopy(records["fileno"])
        changed["checks"]["branch_coverage"]["descriptorless"]["outcome"] = "unreachable_in_reviewed_public_domain"
        child.write_text(json.dumps(changed))
        row["evidence_sha256"] = sha256_file(child)
        batch.write_text(json.dumps(aggregate))
        with self.assertRaisesRegex(GateError, "descriptor branch scope differs"):
            scoped_wrapper_report(self.started, target)

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

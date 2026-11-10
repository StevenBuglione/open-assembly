"""Check that stat production binds current raw helper and errno evidence."""

from copy import deepcopy
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))

from runtime_manifest_gate import (check_stat_archive, check_stat_dependency_binding, manifest_dependency_bindings)
from spec import sha256_file, snapshot_inputs
from stat_query_production import (ERRNO, ERRNO_CHECKS, ERRNO_SOURCE, HELPER, PACKET_CASES, REQUIRED_CHECKS,
                                   SOURCE, stat_dependency_bindings)


class StatDependencies(unittest.TestCase):
    def setUp(self):
        temporary = self.enterContext(TemporaryDirectory())
        self.root = Path(temporary)
        self.enterContext(patch("stat_query_production.ROOT", self.root))
        self.evidence = self.root / "build/evidence"
        self.evidence.mkdir(parents=True)
        self.archive = {"crt1.o": "f" * 64, "libopenasm.a": "a" * 64, "obj/rt/__errno_location.o": "b" * 64,
                        "obj/internal/__al_stat_query.o": "c" * 64, "obj/posix/fstatat.o": "e" * 64}
        self.records = {}
        self.inputs = {}
        self.sources = (ERRNO_SOURCE, SOURCE, Path("src/x86_64-linux/posix/fstatat.asm"))
        for source in self.sources:
            (self.root / source).parent.mkdir(parents=True, exist_ok=True)
            (self.root / source).write_text(f"source for {source.stem}\n")
        for name, path, required in ((ERRNO, ERRNO_SOURCE, ERRNO_CHECKS), (HELPER, SOURCE, REQUIRED_CHECKS)):
            inputs = snapshot_inputs(self.root, self.sources)
            self.inputs[name] = inputs
            object_path = Path("obj") / path.relative_to("src/x86_64-linux").with_suffix(".o")
            checks = {key: {"outcome": "pass"} for key in required}
            checks["candidate_build"].update(source=path.as_posix(), source_sha256=inputs[path.as_posix()],
                                             object_sha256=self.archive[object_path.as_posix()])
            record = {"schema_version": 1, "function": name, "outcome": "pass", "inputs": inputs, "checks": checks}
            if name == HELPER:
                record.update(scope="production-private-dependency", source_sha256=inputs[path.as_posix()])
                checks["runtime_build"]["artifacts"] = {"first": self.archive, "second": self.archive}
                checks["branch_coverage"].update(covered=8, total=8, entry={"observed": True})
                checks["production_mutation"].update(killed=13, total=14, equivalent=[],
                                                     operators=[{"killed": i < 13} for i in range(14)])
                checks["differential_fuzz"]["selectors"] = {
                    case: {"outcome": "pass", "elapsed_s": 60.01, "records": 512,
                           "runs": ["candidate", "raw-linux"],
                           "sha256": {"candidate": "d" * 64, "raw-linux": "d" * 64, "input": "e" * 64}}
                    for case in PACKET_CASES}
            else:
                record.update(scope="production-runtime-function", production_verified=True)
                checks["runtime_build"]["artifacts"] = self.archive
            self.records[name] = record
            self.save(name, record)
        self.enterContext(patch("stat_query_production.stat_query_inputs", side_effect=lambda: self.inputs[HELPER]))
        self.enterContext(patch("stat_query_production.phase2_inputs", side_effect=lambda: self.inputs[ERRNO]))

    def save(self, name, record):
        path = self.evidence / f"{name}.production.json"
        path.write_text(json.dumps(record))
        return path

    def test_binds_exact_reports_and_matches_the_candidate_runtime(self):
        closure = stat_dependency_bindings()
        self.assertEqual(set(closure["functions"]), {HELPER, ERRNO})
        for name, binding in closure["functions"].items():
            self.assertEqual(binding["evidence_sha256"], sha256_file(self.root / binding["evidence"]))
            self.assertEqual(binding["object_sha256"], self.archive[binding["object"]])
        checks = {"dependency_closure": closure,
                  "runtime_build": {"artifacts": {"first": self.archive, "second": self.archive}}}
        with patch("runtime_manifest_gate.manifest_stat_binding", return_value=closure):
            check_stat_dependency_binding(checks)
            changed = deepcopy(checks)
            changed["dependency_closure"]["functions"][HELPER]["evidence_sha256"] = "0" * 64
            with self.assertRaisesRegex(ValueError, "changed or is missing"):
                check_stat_dependency_binding(changed)
        for key in ("libopenasm.a", "obj/internal/__al_stat_query.o", "obj/rt/__errno_location.o"):
            with self.subTest(artifact=key), self.assertRaisesRegex(ValueError, "archive or object differs"):
                check_stat_archive(closure, {**self.archive, key: "0" * 64})

    def test_rejects_missing_stale_and_wrong_archive_reports(self):
        for name in (HELPER, ERRNO):
            with self.subTest(report=name):
                original = self.records[name]
                self.save(name, original).unlink()
                with self.assertRaisesRegex(ValueError, "missing regular file"):
                    stat_dependency_bindings()
                self.save(name, {**original, "inputs": {}})
                with self.assertRaisesRegex(ValueError, "no exact passing stat dependency report"):
                    stat_dependency_bindings()
                self.save(name, original)
        changed = deepcopy(self.records[ERRNO])
        changed["checks"]["runtime_build"]["artifacts"]["libopenasm.a"] = "0" * 64
        self.save(ERRNO, changed)
        with self.assertRaisesRegex(ValueError, "different runtime archives"):
            stat_dependency_bindings()

    def test_rejects_incomplete_or_mismatched_candidate_artifact_maps(self):
        closure = stat_dependency_bindings()
        incomplete = {key: value for key, value in self.archive.items() if key != "crt1.o"}
        changed = {**self.archive, "obj/posix/fstatat.o": "0" * 64}
        cases = ({"first": self.archive}, {"first": self.archive, "second": changed},
                 {"first": incomplete, "second": incomplete})
        with patch("runtime_manifest_gate.manifest_stat_binding", return_value=closure):
            for artifacts in cases:
                with self.subTest(keys=list(artifacts)):
                    checks = {"dependency_closure": closure, "runtime_build": {"artifacts": artifacts}}
                    with self.assertRaisesRegex(ValueError, "runtime maps are incomplete|archive or object differs"):
                        check_stat_dependency_binding(checks)

    def test_rejects_ambiguous_or_nonfinite_dependency_json(self):
        for name in (HELPER, ERRNO):
            path = self.evidence / f"{name}.production.json"
            raw = json.dumps(self.records[name])
            variants = (raw.replace('"candidate_build": {', '"candidate_build": {"outcome": "pass", ', 1),
                        raw[:-1] + ', "unused": NaN}', raw[:-1] + ', "unused": 1e999}')
            for malformed in variants:
                with self.subTest(report=name, tail=malformed[-32:]):
                    path.write_text(malformed)
                    with self.assertRaisesRegex(ValueError, "duplicate field|nonfinite JSON number"):
                        stat_dependency_bindings()
            self.save(name, self.records[name])

    def test_nested_full_fstatat_rejects_ambiguous_json_and_second_build(self):
        closure = stat_dependency_bindings()
        inputs = self.inputs[HELPER]
        source = self.sources[2].as_posix()
        checks = {key: {"outcome": "pass"} for key in REQUIRED_CHECKS}
        checks["candidate_build"].update(source=source, source_sha256=inputs[source], object_sha256="e" * 64)
        checks["runtime_build"]["artifacts"] = {"first": self.archive, "second": self.archive}
        checks["dependency_closure"] = closure
        record = {"schema_version": 1, "scope": "production-runtime-manifest-function", "function": "fstatat",
                  "outcome": "pass", "production_verified": True, "inputs": inputs, "checks": checks}
        path = self.save("fstatat", record)
        with patch("runtime_manifest_gate.ROOT", self.root), patch("runtime_manifest_gate.manifest_inputs", return_value=inputs):
            self.assertEqual(set(manifest_dependency_bindings(("fstatat",))["functions"]), {"fstatat"})
            raw = json.dumps(record)
            for malformed in (raw.replace('"candidate_build": {', '"candidate_build": {"outcome": "pass", ', 1),
                              raw[:-1] + ', "unused": Infinity}'):
                path.write_text(malformed)
                with self.assertRaisesRegex(ValueError, "duplicate field|nonfinite JSON number"):
                    manifest_dependency_bindings(("fstatat",))
            modified = deepcopy(record)
            modified["checks"]["runtime_build"]["artifacts"]["second"] = {**self.archive, "crt1.o": "0" * 64}
            self.save("fstatat", modified)
            with self.assertRaisesRegex(ValueError, "does not bind the source and archive"):
                manifest_dependency_bindings(("fstatat",))

    def test_rejects_missing_packets_or_reclassified_raw_mutation(self):
        for check, key, value, error in (
                ("differential_fuzz", "selectors", {}, "both exact raw packet cases"),
                ("production_mutation", "equivalent", ["cutoff"], "raw mutation evidence"),
                ("branch_coverage", "covered", 7, "full executed branch evidence")):
            with self.subTest(check=check):
                changed = deepcopy(self.records[HELPER])
                changed["checks"][check][key] = value
                self.save(HELPER, changed)
                with self.assertRaisesRegex(ValueError, error):
                    stat_dependency_bindings()


if __name__ == "__main__":
    unittest.main()

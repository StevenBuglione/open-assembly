"""Check exact public collation dependency bindings with synthetic records."""

from copy import deepcopy
import json
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))

import runtime_manifest_gate as gate
from spec import ROOT, sha256_file, snapshot_inputs


class CollationDependencies(unittest.TestCase):
    def setUp(self):
        temporary = self.enterContext(TemporaryDirectory())
        self.root = Path(temporary)
        self.enterContext(patch.object(gate, "ROOT", self.root))
        self.source = Path("src/x86_64-linux/wchar/wcscmp.asm")
        path = self.root / self.source
        path.parent.mkdir(parents=True)
        path.write_text("synthetic dependency source\n")
        self.caller_source = Path("src/x86_64-linux/wchar/wcscoll.asm")
        (self.root / self.caller_source).write_text("synthetic caller source\n")
        self.inputs = snapshot_inputs(self.root, (self.source, self.caller_source))
        self.enterContext(patch.object(gate, "manifest_inputs", return_value=self.inputs))
        self.archive = {"libopenasm.a": "a" * 64, "crt1.o": "b" * 64,
                        "obj/wchar/wcscmp.o": "c" * 64, "obj/wchar/wcscoll.o": "f" * 64}
        checks = {name: {"outcome": "pass"} for name in gate.REQUIRED_CHECKS}
        checks["candidate_build"].update(source=self.source.as_posix(),
            source_sha256=self.inputs[self.source.as_posix()], object_sha256="c" * 64)
        checks["runtime_build"]["artifacts"] = {"first": self.archive, "second": self.archive}
        self.record = {"schema_version": 1, "function": "wcscmp", "scope": "production-runtime-manifest-function",
                       "outcome": "pass", "production_verified": True, "inputs": self.inputs, "checks": checks}
        self.path = self.root / "build/evidence/wcscmp.production.json"
        self.path.parent.mkdir(parents=True)
        self.save(self.record)

    def save(self, record):
        self.path.write_text(json.dumps(record))

    def binding(self):
        return gate.manifest_dependency_bindings(("wcscmp",), bind_runtime=True)

    def test_current_complete_dependency_binds_report_source_object_and_map(self):
        binding = self.binding()
        item = binding["functions"]["wcscmp"]
        self.assertEqual(item["evidence_sha256"], sha256_file(self.path))
        self.assertEqual(item["source"], self.source.as_posix())
        self.assertEqual(item["source_sha256"], self.inputs[self.source.as_posix()])
        self.assertEqual(item["object_sha256"], self.archive[item["object"]])
        checks = {"production_dependencies": binding,
                  "candidate_build": {"source": self.caller_source.as_posix(), "object_sha256": "f" * 64},
                  "runtime_build": {"artifacts": {"first": self.archive, "second": self.archive}}}
        self.assertEqual(gate.check_exact_production_dependencies(checks, ("wcscmp",)), binding)

    def test_missing_stale_and_scoped_dependencies_fail_closed(self):
        self.path.unlink()
        with self.assertRaisesRegex(ValueError, "missing regular file"):
            self.binding()
        for field, value in (("inputs", {}), ("production_verified", False), ("outcome", "pending")):
            with self.subTest(field=field):
                self.save({**self.record, field: value})
                with self.assertRaisesRegex(ValueError, "no exact passing"):
                    self.binding()

    def test_ambiguous_and_nonfinite_json_is_rejected(self):
        raw = json.dumps(self.record)
        for malformed in (raw[:-1] + ', "outcome": "pass"}', raw[:-1] + ', "unused": NaN}',
                          raw[:-1] + ', "unused": 1e999}'):
            with self.subTest(tail=malformed[-35:]):
                self.path.write_text(malformed)
                with self.assertRaisesRegex(ValueError, "duplicate field|nonfinite JSON number"):
                    self.binding()

    def test_dependency_must_bind_both_complete_maps_and_actual_member(self):
        for kind in ("missing", "second", "member", "malformed"):
            record = deepcopy(self.record)
            builds = record["checks"]["runtime_build"]["artifacts"]
            if kind == "missing":
                for stage in ("first", "second"):
                    builds[stage].pop("crt1.o", None)
            elif kind == "second":
                builds["second"] = {**builds["second"], "crt1.o": "e" * 64}
            elif kind == "member":
                record["checks"]["candidate_build"]["object_sha256"] = "e" * 64
            else:
                builds["first"]["crt1.o"] = "bad"
            self.save(record)
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                self.binding()

    def test_caller_rejects_changed_report_and_any_runtime_map_difference(self):
        binding = self.binding()
        checks = {"production_dependencies": binding,
                  "candidate_build": {"source": self.caller_source.as_posix(), "object_sha256": "f" * 64},
                  "runtime_build": {"artifacts": {"first": self.archive, "second": self.archive}}}
        self.path.write_bytes(self.path.read_bytes() + b" ")
        with self.assertRaisesRegex(ValueError, "evidence changed"):
            gate.check_exact_production_dependencies(checks, ("wcscmp",))
        self.save(self.record)
        for kind in ("second", "both", "missing", "caller"):
            changed = deepcopy(checks)
            builds = changed["runtime_build"]["artifacts"]
            if kind == "second":
                builds["second"] = {**builds["second"], "crt1.o": "d" * 64}
            elif kind == "both":
                builds["first"] = builds["second"] = {**self.archive, "crt1.o": "d" * 64}
            elif kind == "missing":
                builds.pop("second")
            else:
                changed["candidate_build"]["object_sha256"] = "e" * 64
            with self.subTest(kind=kind), self.assertRaisesRegex(ValueError, "runtime"):
                gate.check_exact_production_dependencies(changed, ("wcscmp",))

    def test_plan_inventory_and_independent_manifest_domains(self):
        with patch.object(gate, "ROOT", ROOT):
            for name in gate.WIDE_CONCAT_COLLATE:
                plan = gate.PLANS[name]
                probes, controls = gate.load_plan_probes(name, plan)
                self.assertTrue({plan.abi, plan.trace, plan.fuzz} <= probes.keys())
                self.assertIn(name, controls)
                self.assertEqual(plan.exact_dependencies, name == "wcscoll")
                if name == "wcsxfrm":
                    self.assertIn(("wide-concat-collate-wcsxfrm-guard", (21, 22, 23)), plan.mutations)
            self.assertEqual(gate.PLANS["wcscoll"].required_production, ("wcscmp",))
            self.assertEqual(gate.PLANS["wcsxfrm"].private_engine, "wmemcpy")
            self.assertIn("__al_memcpy_bulk", gate.PLANS["wcsxfrm"].private_helpers)


if __name__ == "__main__":
    unittest.main()

"""Reject weak or mismatched references in explicitly selected old observations."""

from dataclasses import replace
from functools import partial
from hashlib import sha256
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))

import manifest_references as refs
import runtime_manifest_gate as gate
from gate import GateError


class RequiredReferences(unittest.TestCase):
    def setUp(self):
        self.plan = gate.PLANS["mbsinit"]
        parse = partial(gate.parse_probe, suite=self.plan.suite, programs=(),
                        asm_fixtures=self.plan.assembly, fault_wrappers={}, allow_fixture_files=True)
        probes, _ = gate.load_probes(self.plan.suite / "manifest.toml", self.plan.public, parse)
        self.probes = {probe.case.name: probe for probe in probes}
        self.probe = self.probes["multibyte-scalar16"]

    def selected(self, plan=None, probes=None, function="mbsinit"):
        return refs.select_required_references(function, self.plan if plan is None else plan,
                                              (self.probes if probes is None else probes).values())

    def test_original_probe_case_expected_and_oracle_remain_unchanged(self):
        selected = self.selected()[self.probe.case.name]
        self.assertIs(selected, self.probe)
        self.assertIs(selected.case, self.probe.case)
        self.assertEqual(selected.case.requires, ("mbrtoc16", "c16rtomb"))
        complete, _ = gate.load_plan_probes("mbsinit", self.plan)
        self.assertIn("multibyte-scalar16", complete)
        ordinary, _ = gate.load_plan_probes("mbsinit", replace(self.plan, required_references=()))
        self.assertNotIn("multibyte-scalar16", ordinary)

    def test_missing_duplicate_wrong_target_or_wrong_case_binding_is_rejected(self):
        binding = self.plan.required_references[0]
        for metadata in ((), (binding, binding), (("missing", "mbsinit"),),
                         (("multibyte-scalar16", "mbrtoc16"),), (("multibyte-scalar16",),),
                         (("multibyte-scalar16", []),)):
            with self.subTest(metadata=metadata), self.assertRaises(GateError):
                self.selected(replace(self.plan, required_references=metadata))
        with self.assertRaisesRegex(GateError, "target differs"):
            self.selected(function="mbrtoc16")
        with self.assertRaisesRegex(GateError, "missing or differs"):
            self.selected(probes={})

    def test_changed_original_case_metadata_is_rejected(self):
        for field, value in (("name", "unrelated"), ("sources", (Path("tests/phase9/restartable/packets.c"),)),
                             ("args", ["scalar32"]), ("requires", ("mbsinit",))):
            changed = replace(self.probe, case=replace(self.probe.case, **{field: value}))
            probes = {**self.probes, self.probe.case.name: changed}
            with self.subTest(field=field), self.assertRaisesRegex(GateError, "missing or differs"):
                self.selected(probes=probes)
        with patch.object(refs, "sha256_file", return_value="a" * 64):
            with self.assertRaisesRegex(GateError, "assertions changed"):
                self.selected()

    def build_records(self):
        directory = Path(self.enterContext(TemporaryDirectory()))
        artifacts = {}
        for stage in ("first", "second"):
            work = directory / self.probe.case.name / stage
            work.mkdir(parents=True)
            objects = ((work / "test-0.o", b"synthetic object"),
                       (work / self.probe.case.name, b"synthetic binary"))
            for path, contents in objects:
                path.write_bytes(contents)
            artifacts[stage] = {path.name: sha256(contents).hexdigest() for path, contents in objects}
        cases = {self.probe.case.name: {"outcome": "pass", "artifacts": artifacts, "commands": []}}
        return directory, cases

    def test_both_objects_and_linked_definitions_are_audited(self):
        directory, cases = self.build_records()
        def symbols(_log, path, _flags):
            return {"mbsinit": "U" if path.suffix == ".o" else "T"}
        with patch.object(refs, "nm_symbols", side_effect=symbols) as nm:
            record = refs.audit_required_references("mbsinit", self.plan, self.probes, directory, cases)
        self.assertEqual(nm.call_count, 4)
        binding = record["bindings"][self.probe.case.name]
        self.assertEqual(set(binding["builds"]), {"first", "second"})
        self.assertEqual(binding["original_requires"], ["mbrtoc16", "c16rtomb"])
        self.assertEqual([item["line"] for item in binding["assertions"]], [105, 106, 119])

    def test_missing_weak_unrelated_or_missing_linked_reference_is_rejected(self):
        for kind in ("missing", "weak", "unrelated", "linked", "second"):
            directory, cases = self.build_records()
            def symbols(_log, path, _flags):
                if path.suffix == ".o":
                    if kind == "missing" or kind == "second" and path.parent.name == "second":
                        return {}
                    if kind == "weak":
                        return {"mbsinit": "w"}
                    if kind == "unrelated":
                        return {"other": "U"}
                    return {"mbsinit": "U"}
                return {} if kind == "linked" else {"mbsinit": "T"}
            with self.subTest(kind=kind), patch.object(refs, "nm_symbols", side_effect=symbols):
                with self.assertRaisesRegex(GateError, "missing strong public"):
                    refs.audit_required_references("mbsinit", self.plan, self.probes, directory, cases)


if __name__ == "__main__":
    unittest.main()

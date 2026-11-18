"""Check that optional model audits bind current source and header identities."""

from hashlib import sha256
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))

import fixture_model as model
import runtime_manifest_gate as gate
from gate import GateError
from spec import snapshot_inputs


class IndependentModels(unittest.TestCase):
    def setUp(self):
        self.root = Path(self.enterContext(TemporaryDirectory()))
        self.source = self.root / "tests/model.c"
        self.header = self.root / "tests/model.h"
        self.generated = self.root / "build/include/c/stdint.h"
        for path in (self.source, self.header, self.generated):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(f"synthetic {path.name}\n")
        self.inputs = snapshot_inputs(self.root, (path.relative_to(self.root) for path in
                                                (self.source, self.header, self.generated)))
        self.dependencies = self.root / "model.d"
        self.dependencies.write_text("model.o: tests/model.c tests/model.h \\\n build/include/c/stdint.h\n")
        self.enterContext(patch.object(model, "ROOT", self.root))

    def test_current_source_and_all_workspace_headers_are_captured(self):
        headers = model.model_headers(self.dependencies, self.source, self.inputs)
        self.assertEqual(headers, {str(path.relative_to(self.root)): sha256(path.read_bytes()).hexdigest()
                                   for path in (self.header, self.generated)})

    def test_changed_or_uncaptured_workspace_header_is_rejected(self):
        for kind in ("changed", "uncaptured"):
            inputs = dict(self.inputs)
            if kind == "changed":
                inputs["tests/model.h"] = "a" * 64
            else:
                inputs.pop("tests/model.h")
            with self.subTest(kind=kind), self.assertRaisesRegex(GateError, "missing or changed"):
                model.model_headers(self.dependencies, self.source, inputs)

    def test_dependency_manifest_must_include_source_and_headers(self):
        for contents in ("", "model.o:", "model.o: tests/model.h", "model.o: tests/model.c"):
            self.dependencies.write_text(contents)
            with self.subTest(contents=contents), self.assertRaises(GateError):
                model.model_headers(self.dependencies, self.source, self.inputs)

    def test_unknown_external_header_and_uncaptured_source_fail_before_compiling(self):
        outside = Path(self.enterContext(TemporaryDirectory())) / "outside.h"
        outside.write_text("synthetic outside header\n")
        self.dependencies.write_text(f"model.o: tests/model.c {outside}\n")
        with self.assertRaisesRegex(GateError, "outside captured inputs"):
            model.model_headers(self.dependencies, self.source, self.inputs)
        with patch.object(model, "checked") as checked:
            with self.assertRaisesRegex(GateError, "missing or changed"):
                model.audit_model(Path("tests/model.c"), self.root, [], {})
            checked.assert_not_called()

    def test_mbsinit_plan_reuses_frozen_cases_and_default_plans_stay_optional(self):
        plan = gate.PLANS["mbsinit"]
        probes, controls = gate.load_plan_probes("mbsinit", plan)
        self.assertTrue({plan.abi, plan.trace, plan.fuzz, "restartable-mbsinit-contract",
                         "multibyte-mbsinit", "multibyte-split", "multibyte-invalid"} <= probes.keys())
        self.assertEqual(controls["mbsinit"][1], (53, b"", b""))
        self.assertEqual(plan.mutations[0], ("restartable-mbsinit-guard", (21, 22, 23, 24, 25)))
        self.assertFalse(plan.private_engine)
        self.assertFalse(plan.required_production)
        self.assertEqual(plan.independent_model, Path("tests/phase9/restartable/model.c"))
        self.assertIsNone(gate.PLANS["memmove"].independent_model)


if __name__ == "__main__":
    unittest.main()

"""Reject missing or ambiguous bindings for the frozen public memmove control."""

from copy import deepcopy
from dataclasses import replace
from hashlib import sha256
import json
from pathlib import Path
import sys
import shutil
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))

import public_copy_production as copy
import runtime_manifest_gate as gate
from gate import GateError
from spec import ROOT, load_project


class NamedControls(unittest.TestCase):
    def setUp(self):
        self.plan = gate.PLANS["memmove"]
        self.probes, self.controls = gate.load_plan_probes("memmove", self.plan)

    def test_exact_published_control_and_entire_fixture_namespace(self):
        self.assertEqual(self.plan.public, {"memcpy", "wmemcpy", "memmove"})
        self.assertEqual(self.controls["memmove"], (self.probes[self.plan.trace], (21, b"", b"")))
        self.assertEqual(len(self.probes), 4)
        self.assertTrue(self.plan.raw_mutations)
        wrapper = gate.PLANS["wmemmove"]
        self.assertEqual(wrapper.required_production, ("memmove",))
        self.assertTrue(wrapper.exact_dependencies)
        self.assertFalse(wrapper.private_engine)
        self.assertEqual(gate.PLANS["wmemcpy"].private_engine, "memcpy")

    def test_missing_duplicate_or_mismatched_control_is_rejected(self):
        for metadata in ((), ("missing-case", (21, b"", b"")),
                         (self.plan.abi, (21, b"", b"")),
                         (self.plan.trace, (True, b"", b"")),
                         (self.plan.trace, (0, b"", b"")),
                         (self.plan.trace, (21, "", b"")),
                         (self.plan.trace, (22, b"", b""))):
            with self.subTest(metadata=metadata), self.assertRaises(GateError):
                gate.load_plan_probes("memmove", replace(self.plan, generated_control=metadata))
        for target, selected, controls in (("memmove", {}, {}), ("memcpy", self.probes, {}),
                                           ("memmove", self.probes, self.controls)):
            with self.subTest(target=target, existing=bool(controls)), self.assertRaises(GateError):
                copy.generated_control(target, self.plan, selected, controls)
        wrong = {**self.probes, self.plan.trace: replace(self.probes[self.plan.trace],
            case=replace(self.probes[self.plan.trace].case, requires=("memcpy",)))}
        with self.assertRaises(GateError):
            copy.generated_control("memmove", self.plan, wrong, {})

    def test_default_loader_still_rejects_incomplete_primary_stub_inventory(self):
        with self.assertRaisesRegex(GateError, "missing generated stubs"):
            gate.load_plan_probes("memmove", replace(self.plan, generated_control=None))

    def test_generated_manifest_does_not_hide_unrelated_or_missing_namespaces(self):
        with self.assertRaisesRegex(GateError, "manifest namespace"):
            gate.load_plan_probes("memmove", replace(self.plan, public=frozenset({"memmove"})))
        unrelated = replace(self.probes[self.plan.trace],
                            case=replace(self.probes[self.plan.trace].case, requires=("unknown",)))
        with patch.object(gate, "load_probes", return_value=([*self.probes.values(), unrelated], {})):
            with self.assertRaisesRegex(GateError, "manifest namespace"):
                gate.load_plan_probes("memmove", self.plan)

    def test_raw_campaign_keeps_signal_timeout_survivor_and_named_kill(self):
        temporary = self.enterContext(TemporaryDirectory())
        directory = Path(temporary)
        source = directory / "source.asm"
        source.write_text("ret\n")
        obj = directory / "original.o"
        obj.write_bytes(b"object")
        spec = load_project().functions["memmove"]
        cases = replace(self.plan, mutations=((self.plan.trace, (21, 22, 23)),))
        variants = [(name, "ret\n") for name in ("signal", "timeout", "survivor", "kill")]
        observed = [((-11, b"", b""), {}), copy.subprocess.TimeoutExpired("probe", 15),
                    ((0, b"", b""), {}), ((22, b"", b""), {})]
        record = {"operators": []}
        with patch.object(copy, "variants", return_value=variants), \
                patch.object(gate, "candidate_object", return_value=obj), \
                patch("phase1.build_case", return_value=(obj, {obj.name: "a" * 64})), \
                patch.object(gate, "execute_native", side_effect=observed):
            with self.assertRaisesRegex(GateError, "2 unresolved operators"):
                copy.raw_mutation_campaign("memmove", spec, source, obj, self.probes, cases,
                                           directory / "mutation", None, record)
        self.assertEqual(record["raw_total"], 4)
        self.assertEqual(record["raw_killed"], 1)
        self.assertEqual([item["classification"] for item in record["operators"]],
                         ["unclassified", "unclassified", "survived", "semantic-kill"])
        self.assertEqual(record["operators"][0]["probes"][0]["returncode"], -11)
        self.assertEqual(record["operators"][1]["probes"][0]["classification"], "timeout")
        self.assertEqual(record["equivalent"], [])

    def test_later_named_rejection_does_not_hide_an_earlier_signal(self):
        directory = Path(self.enterContext(TemporaryDirectory()))
        source, obj = directory / "source.asm", directory / "original.o"
        source.write_text("ret\n")
        obj.write_bytes(b"object")
        record = {"operators": []}
        with patch.object(copy, "variants", return_value=[("signal-then-reject", "ret\n")]), \
                patch.object(gate, "candidate_object", return_value=obj), \
                patch("phase1.build_case", return_value=(obj, {obj.name: "a" * 64})), \
                patch.object(gate, "execute_native", side_effect=[((-11, b"", b""), {}), ((13, b"", b""), {})]):
            with self.assertRaisesRegex(GateError, "1 unresolved operators"):
                copy.raw_mutation_campaign("memmove", load_project().functions["memmove"], source, obj,
                    self.probes, self.plan, directory / "mutation", None, record)
        self.assertEqual(record["raw_killed"], 1)
        self.assertEqual(record["unclassified"], 1)
        self.assertEqual(record["operators"][0]["probes"][0]["returncode"], -11)

    def test_wrapped_observation_timeout_keeps_partial_output(self):
        directory = Path(self.enterContext(TemporaryDirectory()))
        source, obj = directory / "source.asm", directory / "original.o"
        source.write_text("ret\n")
        obj.write_bytes(b"object")
        timeout = GateError("probe exceeded 30 seconds")
        timeout.__cause__ = copy.subprocess.TimeoutExpired("probe", 30, output=b"partial", stderr=b"diagnostic")
        record = {"operators": []}
        plan = replace(self.plan, mutations=((self.plan.trace, (21, 22, 23)),))
        with patch.object(copy, "variants", return_value=[("timeout", "ret\n")]), \
                patch.object(gate, "candidate_object", return_value=obj), \
                patch("phase1.build_case", return_value=(obj, {obj.name: "a" * 64})), \
                patch.object(gate, "execute_native", side_effect=timeout):
            with self.assertRaisesRegex(GateError, "1 unresolved operators"):
                copy.raw_mutation_campaign("memmove", load_project().functions["memmove"], source, obj,
                    self.probes, plan, directory / "mutation", None, record)
        observed = record["operators"][0]["probes"][0]
        self.assertEqual(observed["classification"], "timeout")
        self.assertEqual(observed["stdout_hex"], b"partial".hex())
        self.assertEqual(observed["stderr_hex"], b"diagnostic".hex())
        self.assertEqual(record["raw_killed"], 0)


class ReviewedEquivalences(unittest.TestCase):
    def setUp(self):
        self.plan = gate.PLANS["memmove"]
        self.root = Path(self.enterContext(TemporaryDirectory()))
        self.receipt = json.loads((ROOT / copy.REVIEW).read_bytes())
        self.source = Path(self.receipt["source"]["path"])
        for relative in (self.source, Path(self.receipt["proof"]["path"]), copy.REVIEW):
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, path)
        self.enterContext(patch.object(copy, "ROOT", self.root))
        self.operators = []
        for name, contents in copy.variants(self.root / self.source):
            reviewed = name in self.receipt["reviewed_equivalent_operator_source_hashes"]
            self.operators.append({"operator": name, "source": contents,
                "source_sha256": sha256(contents.encode()).hexdigest(), "killed": not reviewed,
                "classification": "survived" if reviewed else "semantic-kill",
                "probes": [{"case": case, "classification": "survived", "returncode": 0,
                            "stdout_hex": "", "stderr_hex": ""} for case, _ in self.plan.mutations]})

    def binding(self, operators=None, plan=None):
        return copy.reviewed_equivalences("memmove", self.source,
            self.operators if operators is None else operators, self.plan if plan is None else plan)

    def test_exact_receipt_binds_all_ten_and_only_two_observed_survivors(self):
        equivalent = self.binding()
        self.assertEqual(len(self.operators), 10)
        self.assertEqual({item["operator"] for item in equivalent},
                         set(self.receipt["reviewed_equivalent_operator_source_hashes"]))
        self.assertEqual(sum(item["killed"] for item in self.operators), 8)
        self.assertTrue(all(item["review_sha256"] == copy.REVIEW_SHA256 for item in equivalent))

    def test_changed_or_missing_receipt_proof_and_source_are_rejected(self):
        for relative in (copy.REVIEW, Path(self.receipt["proof"]["path"]), self.source):
            path = self.root / relative
            original = path.read_bytes()
            for replacement in (None, original + b"\n"):
                with self.subTest(path=relative, missing=replacement is None):
                    if replacement is None:
                        path.unlink()
                    else:
                        path.write_bytes(replacement)
                    with self.assertRaises((GateError, ValueError)):
                        self.binding()
                    path.write_bytes(original)

    def test_missing_extra_duplicate_or_changed_raw_operator_is_rejected(self):
        for kind in ("missing", "extra", "duplicate", "hash", "contents", "name-type"):
            operators = deepcopy(self.operators)
            if kind == "missing":
                operators.pop()
            elif kind == "extra":
                operators.append({**operators[0], "operator": "extra"})
            elif kind == "duplicate":
                operators.append(operators[0])
            elif kind == "hash":
                operators[0]["source_sha256"] = "a" * 64
            elif kind == "contents":
                operators[0]["source"] += "\n"
            else:
                operators[0]["operator"] = []
            with self.subTest(kind=kind), self.assertRaisesRegex(GateError, "raw operator binding"):
                self.binding(operators)

    def test_named_rejection_unclassified_or_incomplete_reviewed_observation_is_rejected(self):
        for kind in ("kill", "unclassified", "timeout", "missing", "extra", "return", "bool-return", "output"):
            operators = deepcopy(self.operators)
            item = next(item for item in operators if item["operator"] == "comparison-signedness-30")
            if kind == "kill":
                item.update(killed=True, classification="semantic-kill")
            elif kind in ("unclassified", "timeout"):
                item["probes"][0]["classification"] = kind
            elif kind == "missing":
                item["probes"].pop()
            elif kind == "extra":
                item["probes"].append(item["probes"][0])
            elif kind == "return":
                item["probes"][0]["returncode"] = 21
            elif kind == "bool-return":
                item["probes"][0]["returncode"] = False
            else:
                item["probes"][0]["stdout_hex"] = "00"
            with self.subTest(kind=kind), self.assertRaisesRegex(GateError, "contradicted or unresolved"):
                self.binding(operators)
        with self.assertRaisesRegex(GateError, "observation inventory"):
            self.binding(plan=replace(self.plan, mutations=()))


if __name__ == "__main__":
    unittest.main()

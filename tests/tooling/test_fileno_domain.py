"""Check that a fileno reachability review cannot qualify changed FILE inputs."""

from copy import deepcopy
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from gate import GateError
from runtime_manifest_gate import FILENO_DESCRIPTORLESS, FILENO_REVIEW, bind_descriptorless_scope, descriptor_domain
from spec import sha256_file


class DescriptorDomain(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.source = Path(temporary.name) / "fileno.asm"
        self.source.write_text("    js .no_descriptor\n")
        identity = sha256_file(self.source)
        self.inputs = {"src/x86_64-linux/stdio/fileno.asm": identity,
                       "src/x86_64-linux/stdio/freopen.asm": "1" * 64,
                       "build/include/c/stdio.h": "2" * 64,
                       str(FILENO_REVIEW): "3" * 64}
        self.enterContext(patch.dict(FILENO_DESCRIPTORLESS, source_sha256=identity))
        self.enterContext(patch("runtime_manifest_gate.FILENO_DOMAIN_SHA256", descriptor_domain(self.inputs)[0]))
        self.trace = {
            "outcome": "partial", "covered": 1, "total": 2,
            "edges": [
                {"line": 38, "instruction": "js", "branch": "taken", "covered": False},
                {"line": 38, "instruction": "js", "branch": "fallthrough", "covered": True},
            ],
        }

    def record(self, inputs):
        trace = deepcopy(self.trace)
        bind_descriptorless_scope(self.source, trace, inputs)
        proof = trace.pop("descriptorless")
        self.assertEqual(trace, self.trace)
        return proof

    def test_exact_review_preserves_raw_trace_and_adjusts_applicable_count(self):
        proof = self.record(self.inputs)
        self.assertEqual(proof["outcome"], "unreachable_in_reviewed_public_domain")
        self.assertEqual((proof["applicable_covered"], proof["applicable_total"]), (1, 1))

    def test_new_constructor_anywhere_returns_to_pending(self):
        for path in ("src/x86_64-linux/other/open_stream.asm", "spec/functions/other/open_stream.toml",
                     "build/include/c/other.h"):
            with self.subTest(path=path):
                proof = self.record({**self.inputs, path: "4" * 64})
                self.assertEqual(proof["outcome"], "pending")
                self.assertNotIn("applicable_total", proof)

    def test_changed_lifetime_transition_returns_to_pending(self):
        proof = self.record({**self.inputs, "src/x86_64-linux/stdio/freopen.asm": "5" * 64})
        self.assertEqual(proof["outcome"], "pending")
        self.assertNotIn("applicable_covered", proof)

    def test_different_candidate_or_missing_edge_cannot_reuse_proof(self):
        self.trace["edges"][0]["line"] = 39
        with self.assertRaises(GateError):
            self.record(self.inputs)
        self.trace["edges"][0]["line"] = 38
        self.source.write_text("    jns .no_descriptor\n")
        with self.assertRaises(GateError):
            self.record(self.inputs)


if __name__ == "__main__":
    unittest.main()

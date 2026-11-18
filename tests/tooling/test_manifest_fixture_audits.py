"""Reject stripped or stale opt-in audits without changing API expectations."""

from copy import deepcopy
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))

from failure_journal import hash_json
from manifest_fixture_audits import check_declared_audits
import manifest_audit_fixture as fixture
from runtime_manifest_gate import PLANS
from spec import snapshot_inputs


class DeclaredAudits(unittest.TestCase):
    def setUp(self):
        self.root = Path(self.enterContext(TemporaryDirectory()))
        self.inputs = snapshot_inputs(self.root, fixture.sources(self.root))
        self.checks = fixture.records(self.inputs)

    def verify(self, checks):
        check_declared_audits('mbsinit', PLANS['mbsinit'], checks, self.inputs)

    def test_current_audits_pass_and_default_plans_remain_optional(self):
        self.verify(self.checks)
        check_declared_audits('wcscmp', PLANS['wcscmp'], {}, {})

    def test_stripped_false_changed_or_incomplete_model_audits_are_rejected(self):
        for kind in ('missing', 'false', 'source', 'object', 'imports', 'headers', 'header-hash', 'captured-header', 'external-header', 'dependency'):
            checks = deepcopy(self.checks)
            model = checks['candidate_build']['fixture_independence']
            if kind == 'missing':
                checks['candidate_build'].clear()
            elif kind == 'false':
                model['outcome'] = 'fail'
            elif kind == 'source':
                model['source_sha256'] = '0' * 64
            elif kind == 'object':
                model['objects'].pop('musl')
            elif kind == 'imports':
                model['objects']['candidate']['undefined_symbols'] = {'mbsinit': 'U'}
            elif kind == 'headers':
                model['objects']['candidate']['headers'] = {}
            elif kind == 'header-hash':
                model['objects']['candidate']['headers_sha256'] = '0' * 64
            elif kind in ('captured-header', 'external-header'):
                item = model['objects']['candidate']
                path = fixture.HEADER.as_posix() if kind == 'captured-header' else '/tmp/outside-header.h'
                item['headers'] = {path: '0' * 64}
                item['headers_sha256'] = hash_json(item['headers'])
            else:
                model['objects']['candidate']['dependency_file_sha256'] = 'bad'
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                self.verify(checks)

    def test_stripped_false_changed_or_weak_reference_audits_are_rejected(self):
        for kind in ('missing', 'false', 'source', 'case', 'assertion', 'stage', 'weak', 'object', 'binary', 'cases-shape', 'observation'):
            checks = deepcopy(self.checks)
            parent = checks['native_oracles']
            refs = parent['required_references']
            binding = refs['bindings']['multibyte-scalar16']
            if kind == 'missing':
                parent.pop('required_references')
            elif kind == 'false':
                refs['outcome'] = 'fail'
            elif kind == 'source':
                binding['source_sha256'] = '0' * 64
            elif kind == 'case':
                binding['args'] = ['scalar32']
            elif kind == 'assertion':
                binding['assertions'] = []
            elif kind == 'stage':
                binding['builds'].pop('second')
            elif kind == 'weak':
                binding['builds']['first']['undefined_symbol'] = {'mbsinit': 'w'}
            elif kind == 'object':
                binding['builds']['first']['test_object_sha256'] = '0' * 64
            elif kind == 'binary':
                binding['builds']['second']['binary_sha256'] = '0' * 64
            elif kind == 'cases-shape':
                parent['cases'] = []
            else:
                parent['cases']['multibyte-scalar16']['outcome'] = 'fail'
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                self.verify(checks)


if __name__ == '__main__':
    unittest.main()

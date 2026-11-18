"""Keep Phase 2 manifest and scalar child contracts distinct and exact."""

from copy import deepcopy
import json
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))

import test_verification_tiers as fixtures
from gate import GateError
from spec import sha256_file
from verify_tiers import gate, manifest_dependency_bindings, phase2_report, retained_tier_children


class Phase2ManifestTier(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.TierEvidence('runTest')
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.records = self.fixture.manifest_reports()
        self.root = self.fixture.root
        self.started = self.fixture.started
        self.enterContext(patch('verify_tiers.phase2_functions', return_value=('scalar', 'memmove')))
        self.scalar = {**self.fixture.data, 'function': 'scalar', 'scope': 'production-function',
                       'production_verified': True,
                       'checks': {'engine_fuzz': {'outcome': 'pass', 'requested_seconds': 300,
                                                 'elapsed_seconds': 300, 'runs': 1}}}
        self.write('scalar', self.scalar)
        functions = {name: self.item(name) for name in ('scalar', 'memmove')}
        self.batch = {**self.fixture.data, 'scope': 'phase2-batch', 'full_scope': True,
                      'total': 2, 'passed': 2, 'functions': functions}
        for field, name, scope in (
                ('shared_integer_scanner', '__al_strtox', 'production-private-dependency'),
                ('runtime_tls_accessor', '__errno_location', 'production-runtime-function'),
                ('bulk_memcpy', '__al_memcpy_bulk', 'production-private-dependency')):
            self.write(name, {**self.fixture.data, 'scope': scope, 'function': name})
            self.batch[field] = self.item(name)
        self.path = self.root / 'build/evidence/phase2.json'
        self.path.write_text(json.dumps(self.batch))

    def write(self, name, data):
        path = self.root / f'build/evidence/{name}.production.json'
        path.write_text(json.dumps(data))

    def item(self, name):
        path = self.root / f'build/evidence/{name}.production.json'
        return {'outcome': 'pass', 'evidence': path.relative_to(self.root).as_posix(),
                'evidence_sha256': sha256_file(path)}

    def update_child(self, name, record):
        self.write(name, record)
        self.batch['functions'][name] = self.item(name)
        self.path.write_text(json.dumps(self.batch))

    def test_manifest_packets_and_scalar_engine_are_both_required(self):
        self.assertEqual(phase2_report(self.started), (self.path, self.batch))
        changed = deepcopy(self.scalar)
        changed['checks']['engine_fuzz']['elapsed_seconds'] = 299
        self.update_child('scalar', changed)
        with self.assertRaisesRegex(GateError, 'timed libFuzzer'):
            phase2_report(self.started)
        self.update_child('scalar', self.scalar)
        changed = deepcopy(self.records['memmove'])
        changed['checks']['differential_fuzz']['elapsed_s'] = 59.99
        self.update_child('memmove', changed)
        with self.assertRaisesRegex(GateError, 'timed candidate/glibc/musl'):
            phase2_report(self.started)

    def test_manifest_wrong_scope_and_incomplete_checks_fail_closed(self):
        for kind in ('wrong-scope', 'false-flag', 'missing-check', 'changed-object', 'second-map'):
            changed = deepcopy(self.records['memmove'])
            if kind == 'wrong-scope':
                changed['scope'] = 'production-function'
            elif kind == 'false-flag':
                changed['production_verified'] = False
            elif kind == 'missing-check':
                changed['checks'].pop('abi')
            elif kind == 'changed-object':
                changed['checks']['candidate_build']['object_sha256'] = '0' * 64
            else:
                changed['checks']['runtime_build']['artifacts']['second'] = {'crt1.o': '0' * 64}
            self.update_child('memmove', changed)
            with self.subTest(kind=kind), self.assertRaises((GateError, ValueError)):
                phase2_report(self.started)

    def test_phase2_raw_aggregate_and_retained_child_survive_later_move_producer(self):
        aggregate_bytes = self.path.read_bytes()
        canonical = self.root / 'build/evidence/memmove.production.json'
        first_bytes = canonical.read_bytes()
        with patch('verify_tiers.time_ns', return_value=self.started), patch('verify_tiers.invoke'):
            first = {}
            gate('phase2', first)
        retained = first['children']['memmove']
        self.assertTrue(retained['retained'])
        self.assertEqual((self.root / retained['evidence']).read_bytes(), first_bytes)
        changed = deepcopy(self.records['memmove'])
        changed['synthetic_run_marker'] = 'later actual production-moves invocation'
        self.write('memmove', changed)
        caller = deepcopy(self.records['wmemmove'])
        caller['checks']['production_dependencies'] = manifest_dependency_bindings(('memmove',), bind_runtime=True)
        self.write('wmemmove', caller)
        with patch('verify_tiers.time_ns', return_value=self.started), patch('verify_tiers.invoke'):
            second = {}
            gate('production-moves', second)
        retained_tier_children({'phase2': first, 'production-moves': second})
        self.assertEqual(self.path.read_bytes(), aggregate_bytes)
        self.assertNotEqual(sha256_file(canonical), retained['evidence_sha256'])
        self.assertEqual((self.root / retained['evidence']).read_bytes(), first_bytes)
        altered = deepcopy(first)
        altered['children']['memmove']['origin_started_ns'] -= 1
        with self.assertRaisesRegex(GateError, 'freshness'):
            retained_tier_children({'phase2': altered, 'production-moves': second})
        duplicate = deepcopy(second)
        duplicate['children']['memmove'] = retained
        with self.assertRaisesRegex(GateError, 'unexpected or duplicate producer'):
            retained_tier_children({'phase2': first, 'production-moves': duplicate})


if __name__ == '__main__':
    unittest.main()

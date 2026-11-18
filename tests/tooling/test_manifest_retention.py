"""Exercise exact retained leaf bytes without product implementations."""

from copy import deepcopy
import json
import os
from dataclasses import replace
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
from time import time_ns
from types import SimpleNamespace
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))

from gate import GateError
from runtime_manifest_gate import REQUIRED_CHECKS
from spec import sha256_file, snapshot_inputs
from verify_tiers import MANIFEST_PLANS, RETAINED_PRODUCERS, retain_manifest_leaf, retained_manifest_leaf, retained_tier_children


class ManifestRetention(unittest.TestCase):
    NAME = "wcscmp"

    def setUp(self):
        self.name = self.NAME
        self.producer = RETAINED_PRODUCERS[self.name]
        family = "wchar" if self.name == "wcscmp" else "string"
        temporary = self.enterContext(TemporaryDirectory())
        self.root = Path(temporary)
        self.source = Path(f'src/x86_64-linux/{family}/{self.name}.asm')
        path = self.root / self.source
        path.parent.mkdir(parents=True)
        path.write_text('synthetic self-contained source\n')
        (self.root / 'Makefile').write_text('synthetic build\n')
        (self.root / 'devenv.lock').write_text('synthetic toolchain pin\n')
        self.sources = (self.source, Path('Makefile'), Path('devenv.lock'))
        self.inputs = snapshot_inputs(self.root, self.sources)
        self.started = time_ns()
        self.path = self.root / f'build/evidence/{self.name}.production.json'
        self.path.parent.mkdir(parents=True)
        artifacts = {'crt1.o': 'a' * 64, 'libopenasm.a': 'b' * 64, f'obj/{family}/{self.name}.o': 'c' * 64}
        checks = {name: {'outcome': 'pass'} for name in REQUIRED_CHECKS}
        checks['candidate_build'].update(source=self.source.as_posix(),
            source_sha256=self.inputs[self.source.as_posix()], object_sha256='c' * 64)
        checks['runtime_build']['artifacts'] = {'first': artifacts, 'second': artifacts}
        checks['differential_fuzz'].update(elapsed_s=60.1, records=512, runs=['candidate', 'glibc', 'musl'],
            sha256={'candidate': 'd' * 64, 'glibc': 'd' * 64, 'musl': 'd' * 64, 'input': 'e' * 64})
        self.record = {'schema_version': 1, 'scope': 'production-runtime-manifest-function', 'function': self.name,
                       'outcome': 'pass', 'production_verified': True, 'inputs': self.inputs, 'checks': checks}
        self.path.write_text(json.dumps(self.record))
        os.utime(self.path, ns=(self.started + 1, self.started + 1))
        self.child = {'outcome': 'pass', 'evidence': self.path.relative_to(self.root).as_posix(),
                      'evidence_sha256': sha256_file(self.path)}
        self.enterContext(patch('verify_tiers.ROOT', self.root))
        self.enterContext(patch('runtime_manifest_gate.ROOT', self.root))
        self.enterContext(patch('runtime_manifest_gate.manifest_inputs',
                               side_effect=lambda _name: snapshot_inputs(self.root, self.sources)))
        self.project = SimpleNamespace(functions={self.name: SimpleNamespace(deps=())})
        self.enterContext(patch('verify_tiers.load_project', return_value=self.project))

    def retain(self):
        return retain_manifest_leaf(self.name, self.child, self.started)

    def altered_snapshot(self, item, data):
        directory = self.root / f'build/evidence/tier-retained/{self.name}'
        path = directory / 'new.json'
        path.write_text(json.dumps(data))
        digest = sha256_file(path)
        path = path.rename(directory / f'{digest}.json')
        changed = deepcopy(item)
        changed.update(evidence=path.relative_to(self.root).as_posix(), evidence_sha256=digest)
        return changed

    def test_exact_bytes_and_repeated_retention(self):
        item = self.retain()
        self.assertEqual((self.root / item['evidence']).read_bytes(), self.path.read_bytes())
        self.assertEqual(self.retain(), item)
        self.assertEqual(retained_manifest_leaf(self.name, item, self.started), self.record)

    def test_later_canonical_does_not_rebind_earlier_leaf(self):
        item = self.retain()
        old = self.path.read_bytes()
        self.path.write_bytes(old + b' ')
        self.assertNotEqual(sha256_file(self.path), item['evidence_sha256'])
        self.assertEqual(retained_manifest_leaf(self.name, item, self.started), self.record)
        self.assertEqual((self.root / item['evidence']).read_bytes(), old)

    def test_missing_and_changed_snapshot_fail(self):
        item = self.retain()
        path = self.root / item['evidence']
        original = path.read_bytes()
        path.unlink()
        with self.assertRaisesRegex(ValueError, 'missing regular file'):
            retained_manifest_leaf(self.name, item, self.started)
        path.write_bytes(original + b' ')
        with self.assertRaisesRegex(GateError, 'filename'):
            retained_manifest_leaf(self.name, item, self.started)

    def test_wrong_function_schema_and_stale_inputs_are_rejected_with_matching_filename(self):
        item = self.retain()
        for field, value in (('function', 'wcslen'), ('scope', 'other-scope'), ('schema_version', 2), ('inputs', {})):
            with self.subTest(field=field):
                changed = self.altered_snapshot(item, {**self.record, field: value})
                with self.assertRaisesRegex(ValueError, 'no exact passing'):
                    retained_manifest_leaf(self.name, changed, self.started)

    def test_original_freshness_and_exact_path_are_required(self):
        item = self.retain()
        for field, value in (('origin_mtime_ns', self.started - 1), ('origin_started_ns', self.started - 1),
                             ('evidence', f'build/evidence/tier-retained/{self.name}/../other.json'),
                             ('schema_version', True)):
            with self.subTest(field=field), self.assertRaises(GateError):
                retained_manifest_leaf(self.name, {**item, field: value}, self.started)

    def test_final_reader_rejects_removed_or_false_retention_marker(self):
        item = self.retain()
        for remove in (False, True):
            changed = deepcopy(item)
            if remove:
                changed.pop('retained')
            else:
                changed['retained'] = False
            with self.subTest(remove=remove), self.assertRaises(GateError):
                retained_tier_children({self.producer: {'retained_origin_started_ns': self.started,
                                               'children': {self.name: changed}}})

    def test_final_reader_anchors_child_to_parent_gate_start(self):
        item = self.retain()
        parent = {'retained_origin_started_ns': self.started, 'children': {self.name: item}}
        retained_tier_children({self.producer: parent})
        changed = deepcopy(parent)
        changed['children'][self.name]['origin_started_ns'] = self.started - 1
        with self.assertRaisesRegex(GateError, 'freshness'):
            retained_tier_children({self.producer: changed})

    def test_source_change_is_stale(self):
        item = self.retain()
        (self.root / self.source).write_text('changed source\n')
        with self.assertRaisesRegex(ValueError, 'no exact passing'):
            retained_manifest_leaf(self.name, item, self.started)

    def test_complete_equal_maps_and_member_identity_are_required(self):
        item = self.retain()
        for kind in ('missing', 'second', 'member'):
            data = deepcopy(self.record)
            builds = data['checks']['runtime_build']['artifacts']
            if kind == 'missing':
                for stage in ('first', 'second'):
                    builds[stage].pop('crt1.o', None)
            elif kind == 'second':
                builds['second'] = {**builds['second'], 'crt1.o': '0' * 64}
            else:
                data['checks']['candidate_build']['object_sha256'] = '0' * 64
            changed = self.altered_snapshot(item, data)
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                retained_manifest_leaf(self.name, changed, self.started)

    def test_private_or_declared_dependencies_are_rejected(self):
        item = self.retain()
        self.project.functions[self.name].deps = ('helper',)
        with self.assertRaisesRegex(GateError, 'self-contained'):
            retained_manifest_leaf(self.name, item, self.started)
        self.project.functions[self.name].deps = ()
        for field, value in (('private_engine', 'helper'), ('private_helpers', ('helper',)),
                             ('required_production', ('helper',))):
            with self.subTest(field=field), patch.dict(MANIFEST_PLANS,
                    {self.name: replace(MANIFEST_PLANS[self.name], **{field: value})}):
                with self.assertRaisesRegex(GateError, 'self-contained'):
                    retained_manifest_leaf(self.name, item, self.started)
        changed = deepcopy(self.record)
        changed['checks']['production_dependencies'] = {'outcome': 'pass'}
        with self.assertRaisesRegex(GateError, 'self-contained'):
            retained_manifest_leaf(self.name, self.altered_snapshot(item, changed), self.started)

    def test_existing_different_bytes_are_never_overwritten(self):
        directory = self.root / f'build/evidence/tier-retained/{self.name}'
        directory.mkdir(parents=True)
        destination = directory / f'{self.child["evidence_sha256"]}.json'
        destination.write_bytes(b'preserve this corrupted evidence')
        with self.assertRaisesRegex(GateError, 'different bytes'):
            self.retain()
        self.assertEqual(destination.read_bytes(), b'preserve this corrupted evidence')

    def test_symlink_leaf_and_parent_are_rejected(self):
        directory = self.root / 'build/evidence/tier-retained'
        directory.mkdir()
        target = self.root / 'outside'
        target.mkdir()
        (directory / self.name).symlink_to(target, target_is_directory=True)
        with self.assertRaisesRegex(GateError, 'symlink'):
            self.retain()
        self.assertEqual(list(target.iterdir()), [])
        (directory / self.name).unlink()
        item = self.retain()
        path = self.root / item['evidence']
        raw = path.read_bytes()
        path.unlink()
        other = target / 'raw.json'
        other.write_bytes(raw)
        path.symlink_to(other)
        with self.assertRaisesRegex(ValueError, 'symbolic link'):
            retained_manifest_leaf(self.name, item, self.started)


    def test_unexpected_and_duplicate_producers_are_rejected(self):
        item = self.retain()
        parent = {'retained_origin_started_ns': self.started, 'children': {self.name: item}}
        retained_tier_children({self.producer: parent})
        for records in ({'other-producer': parent}, {self.producer: parent, 'other-producer': deepcopy(parent)}):
            with self.subTest(producers=list(records)), self.assertRaisesRegex(GateError, 'unexpected or duplicate producer'):
                retained_tier_children(records)


class MemmoveRetention(ManifestRetention):
    NAME = "memmove"


if __name__ == '__main__':
    unittest.main()

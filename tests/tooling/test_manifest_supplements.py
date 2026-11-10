"""Check additive independent manifest loading without executing product code."""
from dataclasses import replace
from functools import partial
from tempfile import TemporaryDirectory
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from gate import GateError
import runtime_manifest_gate as gate


def probe(name):
    return SimpleNamespace(case=SimpleNamespace(name=name, requires=('wcsstr',)))


class Supplements(unittest.TestCase):
    def setup_plan(self):
        return replace(gate.PLANS['wcsstr'],suite=Path('one'),supplement=Path('two'),
                       extra_manifests=(Path('three'),))

    def test_all_manifests(self):
        rows=iter([([probe('a')],{'wcsstr':'control'}),([probe('b')],{}),([probe('c')],{'wcsstr':'extra'})])
        with patch.object(gate,'load_probes',side_effect=lambda *_a,**_k:next(rows)) as load:
            extra={}
            selected,controls=gate.load_plan_probes('wcsstr',self.setup_plan(),extra_controls=extra)
        self.assertEqual(set(selected),{'a','b','c'})
        self.assertEqual(controls,{'wcsstr':'control'})
        self.assertEqual(load.call_count,3)
        self.assertEqual(extra,{'three':'extra'})
        self.assertFalse(load.call_args_list[2].kwargs['supplement'])

    def test_only_load_missing_cases(self):
        rows=iter([([probe('a')],{}),([probe('b')],{}),([probe('c')],{})])
        with patch.object(gate,'load_probes',side_effect=lambda *_a,**_k:next(rows)) as load:
            selected,_=gate.load_plan_probes('wcsstr',self.setup_plan(),required_cases={'b'})
        self.assertEqual(set(selected),{'a','b'})
        self.assertEqual(load.call_count,2)

    def test_actual_wcsstr_control_domains(self):
        extra={}
        probes,controls=gate.load_plan_probes('wcsstr',gate.PLANS['wcsstr'],extra_controls=extra)
        self.assertIn('wide-matching-wcsstr-ordinary',probes)
        self.assertEqual(controls['wcsstr'][1],(22,b'',b''))
        self.assertEqual(len(extra),1)
        self.assertEqual(next(iter(extra.values()))[1],(21,b'',b''))

    def test_extra_manifest_rejects_unrelated_api(self):
        plan=gate.PLANS['wcsstr'];suite=plan.extra_manifests[0]
        text=(ROOT/suite/'manifest.toml').read_text()
        parse=partial(gate.parse_probe,suite=suite,programs=(),asm_fixtures=plan.assembly,
                      fault_wrappers={},allow_fixture_files=True)
        (ROOT/"build").mkdir(exist_ok=True)
        with TemporaryDirectory(dir=ROOT/"build") as temporary:
            path=Path(temporary)/'manifest.toml'
            for field in ('requires = ["wcsstr"]','symbol = "wcsstr"'):
                self.assertEqual(text.count(field),1)
                path.write_text(text.replace(field,field.replace('wcsstr','wcscmp')))
                with self.assertRaises((GateError,ValueError)):
                    gate.load_probes(path,frozenset({'wcsstr'}),parse,supplement=False)

    def test_duplicate_case_rejected(self):
        rows=iter([([probe('a')],{}),([probe('a')],{})])
        with patch.object(gate,'load_probes',side_effect=lambda *_a,**_k:next(rows)):
            with self.assertRaisesRegex(GateError,'overlapping'):
                gate.load_plan_probes('wcsstr',self.setup_plan())


if __name__=='__main__':
    unittest.main()

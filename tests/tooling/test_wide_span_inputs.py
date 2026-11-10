"""Guard private proof input collection without building product code."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import wide_span_production as span


class SpanInputs(unittest.TestCase):
    def test_contract_paths_are_unique(self):
        observed=[]

        def snapshot(root, paths):
            paths=tuple(paths)
            self.assertEqual(root,ROOT)
            self.assertEqual(len(paths),len(set(paths)))
            observed.extend(paths)
            return {str(path):'a'*64 for path in paths}

        with patch('production.phase2_inputs',return_value={}),patch('spec.snapshot_inputs',snapshot):
            result=span.span_inputs()
        self.assertIn(span.CONTRACT,observed)
        self.assertEqual(set(result),set(map(str,observed)))


if __name__=='__main__':
    unittest.main()

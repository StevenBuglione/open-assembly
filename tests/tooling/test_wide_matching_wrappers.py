"""Check declarative wrapper CLI selection without building a runtime."""
from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
from pathlib import Path
import runpy
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))


class SelectedPool:
    def __init__(self, **_options):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *_arguments):
        return False

    def map(self, _function, names):
        return [(name, {"outcome": "pass"}) for name in names]


class MatchingWrapperSelection(unittest.TestCase):
    def run_cli(self, names, expected, flag="--wide-matching-wrappers"):
        writes = []

        def evidence(name, record):
            writes.append((name, record))
            return Path("isolated-wrapper-selection.json")

        arguments = ["runtime_manifest_gate.py", flag, *names]
        with patch.object(sys, "argv", arguments), patch("concurrent.futures.ThreadPoolExecutor", SelectedPool), \
                patch("gate.write_evidence", evidence), redirect_stdout(StringIO()), redirect_stderr(StringIO()):
            with self.assertRaises(SystemExit) as stopped:
                runpy.run_path(str(ROOT / "tools/runtime_manifest_gate.py"), run_name="__main__")
        self.assertEqual(stopped.exception.code, expected)
        return writes

    def test_all(self):
        writes = self.run_cli([], 0)
        self.assertEqual(len(writes), 1)
        self.assertEqual(set(writes[0][1]["functions"]), {"wcsspn", "wcscspn", "wcspbrk"})
        self.assertTrue(writes[0][1]["full_scope"])
        self.assertFalse(writes[0][1]["production_verified"])

    def test_one(self):
        writes = self.run_cli(["wcscspn"], 0)
        self.assertEqual(set(writes[0][1]["functions"]), {"wcscspn"})
        self.assertFalse(writes[0][1]["full_scope"])

    def test_memory_copy_batch_stays_scoped(self):
        writes=self.run_cli([],0,"--wide-memory-wrappers")
        self.assertEqual(set(writes[0][1]["functions"]),{"wmemcpy","wmemmove"})
        self.assertFalse(writes[0][1]["production_verified"])
        self.assertTrue(writes[0][1]["full_scope"])

    def test_memory_full_function_is_not_a_scoped_copy(self):
        self.assertEqual(self.run_cli(["wmemset"],2,"--wide-memory-wrappers"),[])

    def test_duplicate(self):
        self.assertEqual(self.run_cli(["wcscspn", "wcscspn"], 2), [])

    def test_unknown(self):
        self.assertEqual(self.run_cli(["wcsstr"], 2), [])


if __name__ == "__main__":
    unittest.main()

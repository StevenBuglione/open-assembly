"""Causal controls for the tier's narrowly selected PGID-1 boundary."""

import json
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "tools"))
from gate import GateError
from tier_process import _cleanup, inherited_pgid1_run, subreaper_state
from verify_tiers import gate, invoke


class TierProcess(unittest.TestCase):
    def test_default_still_starts_an_isolated_session(self):
        record = {}
        invoke([sys.executable, "-c", "import os,json;print(json.dumps([os.getpid(),os.getpgrp(),os.getsid(0)]))"],
               record, timeout=5)
        pid, group, session = json.loads(record["stdout"])
        self.assertEqual((group, session), (pid, pid))
        self.assertNotIn("process_boundary", record)

    def test_only_two_named_gates_select_the_boundary(self):
        for name in ("phase6-fcntl", "fcntl-production", "phase6-files"):
            with self.subTest(name=name), patch("verify_tiers.invoke") as call, \
                    patch("verify_tiers.fresh_report", side_effect=GateError("after invocation")):
                with self.assertRaisesRegex(GateError, "after invocation"):
                    gate(name, {})
                self.assertEqual(call.call_args.kwargs["preserve_pgid1"], name != "phase6-files")

    def test_inherits_group_and_restores_subreaper(self):
        previous = subreaper_state()
        record = {}
        invoke([sys.executable, "-c", "import os;print(os.getpgrp())"], record,
               timeout=5, preserve_pgid1=True)
        self.assertEqual(record["stdout"], "1\n")
        boundary = record["process_boundary"]
        self.assertEqual(boundary["process_group"], 1)
        self.assertEqual(boundary["subreaper_before"], previous)
        self.assertEqual(boundary["subreaper_after"], previous)
        self.assertEqual(subreaper_state(), previous)
        self.assertTrue(boundary["cleanup"]["complete"])
        self.assertEqual(boundary["cleanup"]["signalled_pids"], [])
        self.assertFalse(boundary["process_group_signals"])

    def test_natural_failure_preserves_status_and_output(self):
        record = {}
        with self.assertRaisesRegex(GateError, "exited 23"):
            invoke([sys.executable, "-c", "import sys;print('partial');print('detail',file=sys.stderr);sys.exit(23)"],
                   record, timeout=5, preserve_pgid1=True)
        self.assertEqual((record["returncode"], record["stdout"], record["stderr"]), (23, "partial\n", "detail\n"))
        self.assertTrue(record["process_boundary"]["cleanup"]["complete"])

    def test_timeout_reaps_direct_escaped_and_double_fork_children(self):
        program = """import os,time
r,w=os.pipe()
pid=os.fork()
if not pid:
    os.close(r)
    os.setsid()
    second=os.fork()
    if second: os._exit(0)
    print('escaped-double-fork',os.getpid(),flush=True)
    os.write(w,b'x')
    time.sleep(30)
else:
    os.close(w)
    os.read(r,1)
    print('direct-primary',os.getpid(),flush=True)
    time.sleep(30)
"""
        previous = subreaper_state()
        record = {}
        with self.assertRaisesRegex(GateError, "exceeded"):
            invoke([sys.executable, "-u", "-c", program], record, timeout=2, preserve_pgid1=True)
        self.assertTrue(record["timed_out"])
        self.assertEqual(record["returncode"], -9)
        self.assertIn("escaped-double-fork", record["stdout"])
        self.assertIn("direct-primary", record["stdout"])
        cleanup = record["process_boundary"]["cleanup"]
        self.assertTrue(cleanup["complete"])
        self.assertGreaterEqual(len(cleanup["signalled_pids"]), 2)
        for pid in cleanup["signalled_pids"]:
            self.assertFalse(Path(f"/proc/{pid}").exists())
        self.assertEqual(subreaper_state(), previous)

    def test_normal_exit_also_reclaims_orphans(self):
        program = """import os,time
r,w=os.pipe()
pid=os.fork()
if not pid:
    os.close(r)
    os.setsid()
    null=os.open('/dev/null',os.O_RDWR)
    os.dup2(null,1);os.dup2(null,2)
    os.write(w,b'x')
    time.sleep(30)
else:
    os.close(w);os.read(r,1)
    print(pid)
"""
        record = {}
        invoke([sys.executable, "-c", program], record, timeout=5, preserve_pgid1=True)
        pid = int(record["stdout"])
        self.assertIn(pid, record["process_boundary"]["cleanup"]["signalled_pids"])
        self.assertFalse(Path(f"/proc/{pid}").exists())
        self.assertNotIn("timed_out", record)

    def test_wrong_group_rejects_before_launch(self):
        program = """import sys
sys.path.insert(0,'tools')
from gate import GateError
from verify_tiers import invoke
try: invoke([sys.executable,'-c',"raise RuntimeError('must not launch')"],{},timeout=1,preserve_pgid1=True)
except GateError as error:
    assert 'inherited process group 1' in str(error)
else: raise AssertionError('wrong group accepted')
"""
        child = subprocess.run([sys.executable, "-c", program], capture_output=True, start_new_session=True)
        self.assertEqual((child.returncode, child.stdout, child.stderr), (0, b"", b""))

    def test_existing_child_is_not_adopted_or_signalled(self):
        child = subprocess.Popen([sys.executable, "-c", "import time;time.sleep(30)"])
        try:
            with self.assertRaisesRegex(GateError, "no existing children"):
                invoke([sys.executable, "-c", "pass"], {}, timeout=1, preserve_pgid1=True)
            self.assertIsNone(child.poll())
        finally:
            child.kill()
            child.wait()

    def test_unrelated_sibling_is_not_signalled(self):
        sibling = subprocess.Popen([sys.executable, "-c", "import time;time.sleep(30)"])
        program = """import sys
sys.path.insert(0,'tools')
from gate import GateError
from verify_tiers import invoke
record={}
try: invoke([sys.executable,'-c','import time;time.sleep(30)'],record,timeout=.1,preserve_pgid1=True)
except GateError:
    assert record['timed_out'] and record['process_boundary']['cleanup']['complete']
else: raise AssertionError('timeout accepted')
"""
        try:
            result = subprocess.run([sys.executable, "-c", program], capture_output=True, timeout=10)
            self.assertEqual((result.returncode, result.stdout, result.stderr), (0, b"", b""))
            self.assertIsNone(sibling.poll())
        finally:
            sibling.kill()
            sibling.wait()

    def test_capability_failure_is_not_a_skip(self):
        with patch("tier_process.os.pidfd_open", side_effect=OSError("pidfd unavailable")), \
                patch("tier_process.subprocess.Popen") as launch:
            with self.assertRaisesRegex(OSError, "pidfd unavailable"):
                inherited_pgid1_run([sys.executable, "-c", "pass"], {}, cwd=Path.cwd(), environment=None, timeout=1)
            launch.assert_not_called()

    def test_launch_error_restores_subreaper(self):
        previous = subreaper_state()
        record = {}
        with self.assertRaises(FileNotFoundError):
            invoke(["/nonexistent/open-assembly-tier-control"], record, timeout=1, preserve_pgid1=True)
        self.assertEqual(subreaper_state(), previous)
        self.assertEqual(record["process_boundary"]["subreaper_after"], previous)

    def cleanup_error_control(self, *, timed_out):
        # The child owns a real orphan that escapes its session. Cleanup runs
        # normally before the synthetic failure, so the test leaks no process.
        program = """import os,sys,time
r,w=os.pipe()
pid=os.fork()
if not pid:
    os.close(r)
    os.setsid()
    null=os.open('/dev/null',os.O_RDWR)
    os.dup2(null,1);os.dup2(null,2)
    os.write(w,b'x')
    time.sleep(30)
else:
    os.close(w);os.read(r,1)
    os.write(1,b'primary-partial\\xff\\n')
    os.write(2,b'primary-error\\xfe\\n')
    if sys.argv[1]=='timeout': time.sleep(30)
    else: sys.exit(23)
"""
        previous = subreaper_state()
        record = {}

        def fail_after_cleanup(child, cleanup):
            _cleanup(child, cleanup)
            raise GateError("synthetic cleanup error after real reclamation")

        with patch("tier_process._cleanup", side_effect=fail_after_cleanup):
            with self.assertRaisesRegex(GateError, "synthetic cleanup error"):
                invoke([sys.executable, "-u", "-c", program, "timeout" if timed_out else "natural"],
                       record, timeout=2 if timed_out else 5, preserve_pgid1=True)
        self.assertEqual(record.get("timed_out", False), timed_out)
        self.assertEqual(record["returncode"], -9 if timed_out else 23)
        self.assertEqual(record["stdout"], "primary-partial\ufffd\n")
        self.assertEqual(record["stderr"], "primary-error\ufffd\n")
        captured = record["primary_observations"][0]
        self.assertEqual(captured["stdout_hex"], b"primary-partial\xff\n".hex())
        self.assertEqual(captured["stderr_hex"], b"primary-error\xfe\n".hex())
        self.assertEqual(captured["communicate_completed"], not timed_out)
        self.assertEqual(captured["stage"], "before-timeout-cleanup" if timed_out else "before-natural-cleanup")
        self.assertEqual(captured["returncode"], None if timed_out else 23)
        boundary = record["process_boundary"]
        self.assertTrue(boundary["cleanup"]["complete"])
        self.assertFalse(boundary["process_group_signals"])
        self.assertGreaterEqual(len(boundary["cleanup"]["signalled_pids"]), 1)
        for pid in boundary["cleanup"]["signalled_pids"]:
            self.assertNotIn(pid, (1, os.getpid()))
            self.assertFalse(Path(f"/proc/{pid}").exists())
        self.assertEqual(subreaper_state(), previous)
        self.assertEqual(boundary["subreaper_after"], previous)

    def test_cleanup_error_after_timeout_keeps_partial_bytes(self):
        self.cleanup_error_control(timed_out=True)

    def test_cleanup_error_after_natural_exit_keeps_bytes_and_status(self):
        self.cleanup_error_control(timed_out=False)


if __name__ == "__main__":
    unittest.main()

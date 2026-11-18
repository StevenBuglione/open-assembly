"""Preserve the PGID-1 oracle domain without signalling its process group.

Only a single-threaded, child-free tier driver may use this boundary. Linux's
process-local subreaper adopts escaped descendants; pidfds identify the exact
direct children killed during bounded cleanup. Other tier commands use the
ordinary isolated-session boundary in verify_tiers.py.
"""

import ctypes
import os
from pathlib import Path
import signal
import subprocess
from time import monotonic, sleep

from gate import GateError

PR_SET_CHILD_SUBREAPER = 36
PR_GET_CHILD_SUBREAPER = 37
CLEANUP_SECONDS = 5


def _prctl(option, argument):
    libc = ctypes.CDLL(None, use_errno=True)
    operation = libc.prctl
    operation.argtypes = [ctypes.c_int, *([ctypes.c_ulong] * 4)]
    operation.restype = ctypes.c_int
    if operation(option, argument, 0, 0, 0) != 0:
        raise OSError(ctypes.get_errno(), "process-local child-subreaper prctl")


def subreaper_state():
    state = ctypes.c_int()
    _prctl(PR_GET_CHILD_SUBREAPER, ctypes.addressof(state))
    return state.value


def _children():
    # The precondition below excludes other threads, so this is the process's
    # complete direct-child list, including children adopted by the subreaper.
    return [int(pid) for pid in Path(f"/proc/self/task/{os.getpid()}/children").read_text().split()]


def _require_boundary():
    if os.getpgrp() != 1:
        raise GateError("PGID-1 oracle requires inherited process group 1 before launching the gate")
    if len(list(Path("/proc/self/task").iterdir())) != 1 or _children():
        raise GateError("PGID-1 boundary requires a single-threaded driver with no existing children")
    # Probe capabilities before any test executable starts. No user/pid
    # namespace or machine configuration change is required.
    fd = os.pidfd_open(os.getpid())
    try:
        signal.pidfd_send_signal(fd, 0)
    finally:
        os.close(fd)


def _cleanup(child, record):
    started = record.setdefault("started_monotonic", monotonic())
    deadline = started + CLEANUP_SECONDS
    signalled = set()
    reaped = []
    while True:
        child.poll()  # Popen alone reaps its primary child and retains status.
        children = _children()
        if not children:
            record.update(complete=True, signalled_pids=sorted(signalled), reaped=reaped,
                          elapsed_seconds=monotonic() - started)
            return
        for pid in children:
            try:
                fd = os.pidfd_open(pid)
            except ProcessLookupError:
                continue
            try:
                # Recheck ownership after opening the lifetime-bound handle.
                # No process-group signal and no unrelated sibling is used.
                if pid in _children():
                    try:
                        signal.pidfd_send_signal(fd, signal.SIGKILL)
                        signalled.add(pid)
                    except ProcessLookupError:
                        pass
            finally:
                os.close(fd)
            if pid != child.pid:
                try:
                    found, status = os.waitpid(pid, os.WNOHANG)
                except ChildProcessError:
                    continue
                if found:
                    reaped.append({"pid": found, "wait_status": status})
        if monotonic() >= deadline:
            record.update(complete=False, signalled_pids=sorted(signalled), reaped=reaped,
                          remaining_pids=_children(), elapsed_seconds=monotonic() - started)
            raise GateError("PGID-1 child-subreaper cleanup exceeded its five-second bound")
        sleep(0.005)


def _capture_primary(record, child, stdout, stderr, *, complete, stage):
    """Persist bytes before cleanup can fail; keep lossless observations too."""
    record.update(returncode=child.returncode, stdout=stdout.decode(errors="replace"),
                  stderr=stderr.decode(errors="replace"))
    record.setdefault("primary_observations", []).append({
        "stage": stage, "returncode": child.returncode, "communicate_completed": complete,
        "stdout_hex": stdout.hex(), "stderr_hex": stderr.hex(),
    })


def inherited_pgid1_run(command, record, *, cwd, environment, timeout):
    """Run one gate in the existing PGID 1; return its exact CompletedProcess.

    The driver must have no pre-existing children. This makes every adopted
    child part of this invocation, even if it double-forks or calls setsid.
    The parent's prior subreaper setting is restored on success and error.
    """
    _require_boundary()
    before = subreaper_state()
    record["command"] = list(map(str, command))
    boundary = record["process_boundary"] = {
        "mode": "inherited-pgid1-subreaper-pidfd",
        "driver_pid": os.getpid(), "process_group": os.getpgrp(), "session": os.getsid(0),
        "subreaper_before": before, "cleanup_seconds": CLEANUP_SECONDS,
        "process_group_signals": False, "cleanup": {"complete": False},
    }
    child = None
    _prctl(PR_SET_CHILD_SUBREAPER, 1)
    try:
        child = subprocess.Popen(list(map(str, command)), cwd=cwd, env=environment,
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        boundary["primary_child_pid"] = child.pid
        try:
            stdout, stderr = child.communicate(timeout=timeout)
        except subprocess.TimeoutExpired as error:
            record["timed_out"] = True
            _capture_primary(record, child, error.output or b"", error.stderr or b"",
                             complete=False, stage="before-timeout-cleanup")
            _cleanup(child, boundary["cleanup"])
            stdout, stderr = child.communicate(timeout=CLEANUP_SECONDS)
            _capture_primary(record, child, stdout, stderr, complete=True, stage="after-timeout-cleanup")
        else:
            _capture_primary(record, child, stdout, stderr, complete=True, stage="before-natural-cleanup")
            # A command that exits after orphaning children also owns cleanup.
            _cleanup(child, boundary["cleanup"])
        return subprocess.CompletedProcess(list(map(str, command)), child.returncode, stdout, stderr)
    finally:
        try:
            if child is not None and not boundary["cleanup"]["complete"] and "started_monotonic" not in boundary["cleanup"]:
                _cleanup(child, boundary["cleanup"])
                child.communicate(timeout=CLEANUP_SECONDS)
        finally:
            if child is not None and "primary_observations" in record:
                # Cleanup may have reaped the primary before raising. Its
                # status is then available even though invoke never returns.
                # A still-running child remains explicitly unknown (None).
                record["returncode"] = child.returncode
            _prctl(PR_SET_CHILD_SUBREAPER, before)
            boundary["subreaper_after"] = subreaper_state()
            if boundary["subreaper_after"] != before:
                raise GateError("PGID-1 boundary did not restore the process-local subreaper state")

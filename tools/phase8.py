"""Verify the initial freestanding pthread lifecycle slice."""

from pathlib import Path

from phase1 import phase1_inputs
from phase6 import execute_manifest_gate
from spec import ROOT, snapshot_inputs

SUITE = Path("tests/phase8/lifecycle")
PUBLIC = {"pthread_create", "pthread_detach", "pthread_equal", "pthread_exit", "pthread_join", "pthread_self"}
CONTRACT = Path("docs/adr/0010-thread-lifecycle-locks.md")


def inputs():
    bound = phase1_inputs()
    bound.update(snapshot_inputs(ROOT, [CONTRACT, *sorted(SUITE.rglob("*.*"))]))
    return dict(sorted(bound.items()))


if __name__ == "__main__":
    raise SystemExit(execute_manifest_gate(
        "phase8-lifecycle", SUITE, PUBLIC, {SUITE / "fault.c": ("__al_syscall",)},
        (), inputs, "OA_PHASE8_HOST",
        {"pending_phase8": ["broader Open POSIX subset", "full Helgrind and DRD stress",
                            "pthread attributes, mutexes, condition variables, cancellation and TSD",
                            "C11 threads and atomics helpers"]},
    ))

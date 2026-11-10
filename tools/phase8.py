"""Verify scoped freestanding pthread and C11 thread APIs."""

import argparse
from functools import partial
from pathlib import Path

from phase1 import phase1_inputs
from phase6 import execute_manifest_gate
from spec import ROOT, snapshot_inputs

SUITE = Path("tests/phase8")
CONTRACT = Path("docs/adr/0010-thread-lifecycle-locks.md")
PUBLIC = {
    "fork": {"fork", "_Fork", "pthread_atfork"},
    "lifecycle": {"pthread_create", "pthread_detach", "pthread_equal", "pthread_exit", "pthread_join", "pthread_self"},
    "sync": {
        "pthread_attr_destroy", "pthread_attr_getdetachstate", "pthread_attr_getguardsize", "pthread_attr_getstacksize",
        "pthread_attr_init", "pthread_attr_setdetachstate", "pthread_attr_setguardsize", "pthread_attr_setstacksize",
        "pthread_cond_broadcast", "pthread_cond_clockwait", "pthread_cond_destroy", "pthread_cond_init",
        "pthread_cond_signal", "pthread_cond_timedwait", "pthread_cond_wait", "pthread_condattr_destroy",
        "pthread_condattr_getclock", "pthread_condattr_init", "pthread_condattr_setclock", "pthread_getspecific",
        "pthread_key_create", "pthread_key_delete", "pthread_mutex_clocklock", "pthread_mutex_destroy",
        "pthread_mutex_init", "pthread_mutex_lock", "pthread_mutex_timedlock", "pthread_mutex_trylock",
        "pthread_mutex_unlock", "pthread_mutexattr_destroy", "pthread_mutexattr_gettype", "pthread_mutexattr_init",
        "pthread_mutexattr_settype", "pthread_once", "pthread_setspecific",
    },
    "c11": {
        "call_once", "cnd_broadcast", "cnd_destroy", "cnd_init", "cnd_signal", "cnd_timedwait", "cnd_wait",
        "mtx_destroy", "mtx_init", "mtx_lock", "mtx_timedlock", "mtx_trylock", "mtx_unlock", "thrd_create",
        "thrd_current", "thrd_detach", "thrd_equal", "thrd_exit", "thrd_join", "thrd_sleep", "thrd_yield",
        "tss_create", "tss_delete", "tss_get", "tss_set",
    },
}
FAULT_WRAPPERS = {
    SUITE / "lifecycle/fault.c": ("__al_syscall",),
    SUITE / "c11/fault.c": ("__al_syscall",),
    SUITE / "fork/fault.c": ("_Fork",),
}


def inputs(scope="lifecycle"):
    bound = phase1_inputs()
    suite = SUITE / scope
    contracts = [CONTRACT]
    if scope == "fork":
        contracts.append(Path("docs/adr/0043-threaded-fork.md"))
    bound.update(snapshot_inputs(ROOT, [*contracts, *sorted(suite.rglob("*.*"))]))
    return dict(sorted(bound.items()))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--sync", dest="scope", action="store_const", const="sync",
                      help="verify the pthread synchronization and attribute slice")
    mode.add_argument("--c11", dest="scope", action="store_const", const="c11",
                      help="verify the C11 threads interfaces")
    mode.add_argument("--fork", dest="scope", action="store_const", const="fork",
                      help="verify threaded fork and at-fork registration")
    parser.set_defaults(scope="lifecycle")
    scope = parser.parse_args().scope
    raise SystemExit(execute_manifest_gate(
        f"phase8-{scope}", SUITE / scope, PUBLIC[scope], FAULT_WRAPPERS,
        (), partial(inputs, scope), "OA_PHASE8_HOST",
        {"pending_phase8": ["broader Open POSIX subset", "full Helgrind and DRD stress",
                            "pthread cancellation and cleanup handlers", "process-shared and robust mutexes",
                            "C17 atomic flags and fences"]},
    ))

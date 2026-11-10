# Allocator and environment checkpoint

The decision from the recorded Phase 3 gate is to continue. The first
recorded hosted attempt for [the allocator and environment PR](https://github.com/StevenBuglione/open-assembly/pull/4)
passed at `10f3b61ca7fdf365078346eed2103c726e741042`. The branch had one
recorded hosted attempt for that change, so the observed first-pass result
is one out of one. This count does not measure earlier local iterations or
predict the success rate of future functions.

In the [pinned hosted run](https://github.com/StevenBuglione/open-assembly/actions/runs/42750951755),
the Phase 3 command took 37.36 seconds from invocation to its evidence
line. The full acceptance job took 20 minutes 52 seconds including the
inherited gates. The allocator and environment models each passed on
native Linux, QEMU, and Memcheck. The same pull request also carried a
separate freestanding TLS `errno` verification commit. The hosted record
does not give a reliable count of private implementation retries, agent
hours, or token cost.

The checkpoint supports continuing the assembly and independent test
workflow. It does not substitute for the per-function production gates
or the later allocator timing and kernel checks.

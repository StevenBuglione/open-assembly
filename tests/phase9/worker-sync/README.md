# Thread-local conversion state across synchronization

Sixteen rounds create two independent workers with distinct supplementary
Unicode scalars. Each worker leaves a UTF-8-to-wide conversion partial and
holds both a pending UTF-16 output low surrogate and a pending input high
surrogate. With those states live, it uses a thread-specific key and waits
on a condition. The initial thread acquires the same mutex after both
workers have reached the wait, sets their predicates and signals both
conditions. Each worker then checks its key value, replaces it, completes
all conversions, and runs the destructor before join publishes its result.
The initial thread's independent key value remains intact.

Run with `make phase9-worker-sync` in the pinned image. This supplemental
gate compares the combined runtime with the published per-thread default
state, condition and TSD contracts. The existing standalone worker and
synchronization gates cover those areas separately.

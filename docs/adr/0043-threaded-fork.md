# Fork callbacks and child runtime ownership

`pthread_atfork` appends one registration containing optional prepare,
parent and child callbacks. The process has 32 registrations. Exhaustion
returns ENOMEM and leaves the registry unchanged. All three callbacks may
be null. Registration returns an error number directly and preserves
errno. Registration does not acquire application locks.

Public `fork` snapshots the append-only registry. It runs nonnull prepare
callbacks in reverse registration order. A successful parent or a failed
fork runs parent callbacks in registration order. A successful child runs
child callbacks in registration order. Each call uses its own snapshot.
A registration performed during a prepare callback applies to later
forks. No callback runs while a fork guard is held. Successful fork
preserves the entry errno in both processes. A failure returns minus one
and publishes its error after the parent callbacks.

After preparing, the calling thread saves and blocks its catchable
signals. It acquires the following private guards in this order.

1. At-fork registration
2. Locale selection and locale description
3. Zone cache and environment
4. Stdio registry
5. Normal and quick termination registries
6. Random state, thread-specific key registry and compiler generic atomics
7. Temporary name state
8. Allocator

Zone lookup can nest environment lookup and allocation. Environment
mutation and the stream registry can nest allocation. Other listed
guards do not acquire a preceding guard. The allocator is last.
Registration, termination and TSD callbacks run outside their guards.

After the raw kernel call, the parent releases these guards in reverse
order. The child clears the same acquired words in its private address
space. This publishes a coherent snapshot of persistent runtime state.
The child also clears the explicitly enumerated transient scratch guards
for byte and wide formatting, numeric conversion, real and complex math,
and the shell command wrapper. These guards protect per-operation scratch
or bookkeeping in the vanished operation's own storage. The next
operation initializes the scratch it uses. Waiting on a formatter's
application stream or on another thread's shell child would make fork
depend on unrelated I/O. Kernel signal dispositions retain their fork
snapshot. Caller-owned mutexes, conditions, once controls, FILE owner
locks and directory object locks are outside the repair list.

The child keeps the caller's FS base, owner token, live stack and mapping
bounds, canary, executable TLS, errno slot, multibyte and thread-specific
state. It registers the survivor's clear-TID word with Linux and stores
the new TID. It publishes a single live thread, normalizes the survivor
lifecycle to the open root state, clears the stale result and inactive
private wait link, and keeps the caller's active once chain and thread
entry return convention. Other threads' handles do not name live child
threads. A failed post-fork kernel repair terminates through the raw
diagnostic path.

Both paths restore the saved signal mask before invoking their completion
callbacks. The child of a multithreaded fork remains subject to the
POSIX async-signal-safe restriction until exec. This includes child
callbacks. The repair list does not make stdio or arbitrary application
state safe there.

`_Fork` is the async-signal-safe no-callback entry. It uses the raw
kernel operation and TLS error translation without taking the fork guards.
It is intended for an async-signal-safe child path such as exec or
`_exit`. Internal spawn and shell child creation use raw paths.
`popen` calls `_Fork` while the stdio registry guard protects the
descriptor snapshot. Public `fork` would try to acquire that guard
again. Asynchronous thread cancellation and recovery of
application-owned synchronization remain separate.

[POSIX fork](https://pubs.opengroup.org/onlinepubs/9799919799/functions/fork.html) ·
[POSIX at-fork registration](https://pubs.opengroup.org/onlinepubs/9799919799/functions/pthread_atfork.html) ·
[Linux clear TID](https://man7.org/linux/man-pages/man2/set_tid_address.2.html).

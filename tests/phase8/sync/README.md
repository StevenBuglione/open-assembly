# Independent pthread synchronization fixtures

The manifest has 43 cases and 35 direct stub controls for the POSIX
thread attributes, mutex and condition operations, thread-specific
keys and one-time initialization. Each ordinary candidate case runs
native, QEMU user mode, and Memcheck with the project's own startup
and archive. The host builds compare common POSIX behavior with
pinned glibc and musl. Project errno preservation is asserted
separately in the candidate.

- Attributes check default joinability, the specified initial stack
  and guard sizes, exact requested sizes, rejected updates that retain
  the previous value, detached creation and a worker that touches
  more than the default stack size.
- Mutex checks cover static and dynamic initialization, recursive
  depth across foreign attempts, error-check ownership, 8,000
  protected writes, immediate acquisition with a malformed deadline
  and expired versus malformed deadlines when the mutex is held.
- Condition waits synchronize readiness and progress through a
  shared predicate and mutex. They exercise single notification,
  broadcast, both clock APIs, timeout reacquisition and rejecting
  destruction with registered waiters. The timed notification cases
  bound missing wakes, including the stub controls.
- Keys check independent initial values, deletion without callbacks,
  exhausted output preservation, stale generation clearing, a
  destructor that enters the key APIs, and four passes before join
  publishes the thread result.
- Once tests a blocked initializer, nested initialization, publication
  to returning callers, and a second attempt after an initializer
  leaves through `pthread_exit`.

The manifest marks project diagnostics outside portable POSIX usage
and clock-selecting symbols absent from pinned musl. The candidate
still executes these cases on all three backends. The init fixture
inspects the project condition object's initialized storage before
trying to lock a zero-return stub's untouched, poisoned object.

[POSIX threads](https://pubs.opengroup.org/onlinepubs/9799919799/basedefs/pthread.h.html)

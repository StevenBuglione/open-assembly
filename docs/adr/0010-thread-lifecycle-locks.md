# Linux thread lifecycle and runtime locks

Status: contract for the first Phase 8 slice. The acceptance gate remains
the independently authored POSIX subset and Helgrind/DRD stress.

## Public scope

Start with `pthread_create`, `pthread_join`, `pthread_detach`,
`pthread_self`, `pthread_equal`, and `pthread_exit`. A `pthread_t`
is an opaque, process-local pointer-sized handle. The attribute slice
adds initialization, destruction, and detach, stack size, and guard size
accessors. A 32-byte, eight-byte-aligned opaque object stores a validity
tag, requested stack size, guard size, and detach state. A null attribute
selects defaults. Other attributes, caller-owned stacks, cancellation,
cleanup handlers, process-shared
and robust mutexes have separate acceptance requirements.
The API returns positive error numbers and preserves the caller's errno.
An unsuccessful create leaves its output untouched. Join rejects
self-join with EDEADLK and does not return EINTR. Handles are valid
through their specified lifecycle. Code may not inspect or reuse them
after successful join or detached termination.
[POSIX pthread_create](https://pubs.opengroup.org/onlinepubs/9799919799/functions/pthread_create.html) ·
[POSIX pthread_join](https://pubs.opengroup.org/onlinepubs/9799919799/functions/pthread_join.html)

## Static TLS and stack

Preserve variant-II placement and FS offsets 0x00, 0x10, 0x28, 0x30,
and 0x40. The initial auxiliary vector and ELF program headers supply
the immutable TLS template, its distance from the thread pointer, the
guard words, and the page size. Startup and worker creation use one
checked allocator and image-copy path. Each anonymous mapping starts
with zero-filled TLS padding, BSS, and errno. The compiler guard words
stay process-wide while each thread has its own slots. Local-exec TLS
continues to be the only compiler TLS model.

The private descriptor has 2336 bytes at and above the FS base.
Fields through byte 0x4f retain the established compiler ABI and reserved
space. The new fields use eight-byte slots except for the adjacent
32-bit TID and lifecycle words.

| Offset | Field |
| --- | --- |
| 0x48 | Process-unique thread ownership token |
| 0x50 | TLS mapping base |
| 0x58 | TLS mapping length |
| 0x60 | Stack mapping base, zero for the initial kernel stack |
| 0x68 | Stack mapping length |
| 0x70 | Kernel-owned clear-TID word |
| 0x74 | Runtime-owned lifecycle word |
| 0x78 | Pointer result published at termination |
| 0x80–0xff | Reserved for per-thread locale and conversion state |
| 0x100 | Condition wait link |
| 0x108 | Four-byte condition wake flag |
| 0x110–0x90f | 128 thread-specific key slots, each with an eight-byte generation and value |
| 0x910 | Active one-time initialization frame link |
| 0x918 | Four-byte start mode and C11 publication flag |

The default worker uses 1 MiB of writable stack and one inaccessible
guard page below it. The minimum requested stack size is 16384 bytes.
Accessors retain the requested byte counts. Creation rounds both regions
up to the startup page size, checks overflow, and uses an unguarded
mapping when the requested guard size is zero. The child stack top is
16-byte aligned. A detached attribute selects self-reclamation from
creation. The creator publishes the handle value without reading the
descriptor after clone returns, so immediate detached exit is safe. The creator writes the start
routine and argument into a 16-byte launch record at the top of the new
stack. The child reads that record only after the kernel has installed its
TLS and stack. Parent errors unwind both mappings without publishing
a handle. Keep the TLS and stack mappings independent so teardown can
reclaim each under its own ownership.
[Runtime TLS ABI](0002-runtime-abi.md) ·
[AMD64 psABI](https://gitlab.com/x86-psABIs/x86-64-ABI)

## Kernel launch and termination

Use the x86-64 raw `clone` boundary with CLONE_VM, CLONE_FS, CLONE_FILES,
CLONE_SIGHAND, CLONE_THREAD, CLONE_SYSVSEM, CLONE_SETTLS,
CLONE_PARENT_SETTID, and CLONE_CHILD_CLEARTID. Use the same descriptor TID
word for the parent and clear-TID arguments. The raw argument order is
flags, stack, parent TID address, child TID address, and TLS base. Register
the initial thread's TID and clear address with `set_tid_address`.
A new thread inherits the creating thread's signal mask and floating-point
environment. The kernel clears an alternate signal stack for this launch.
The clone parent returns on the old stack. The child goes directly to a
typed System V start thunk on the new stack and never returns through the
creator's frame.

The result is stored before the exit state is published. A join or a detach
that claims reaping waits for zero in the kernel clear-TID word, retrying
EAGAIN and EINTR. This wait uses the ordinary shared futex operation because
the kernel's clear-TID wake uses that key. Acquire the exit publication
before reading the result. A claim owns cleanup of the target's runtime
stack and TLS mappings after the kernel has stopped using them.

| State | Transition |
| --- | --- |
| Open | Join may claim it, detach may publish detached, or the thread may publish exiting open |
| Exiting open | Join or detach may claim reaping, then wait for kernel exit |
| Claimed | The terminating thread leaves both mappings for the claimant |
| Detached | The terminating thread owns cleanup and no new claim is valid |

A successful detach of a running thread relinquishes all descriptor access
at the publication point. If the exiting thread observes detached state,
it blocks catchable signals, clears its kernel clear-TID address, and hands
both mapping ranges to a dedicated stackless exit boundary. That boundary
keeps its inputs in registers, unmaps TLS and the runtime stack, and issues
the single-thread `exit` syscall. It performs no stack, TLS, or callback
access once unmapping starts. An initial thread with no runtime stack
skips stack unmapping. Explicit process `_exit` still uses `exit_group`.
An atomic live count starts at one, increments before clone, and rolls back
on clone failure. When the last thread leaves through the thread-exit
path it calls process `exit(0)` while its stack and TLS are still usable.
[Linux clone](https://man7.org/linux/man-pages/man2/clone.2.html) ·
[Linux clear TID](https://man7.org/linux/man-pages/man2/set_tid_address.2.html)

## Live runtime locks

Use the existing aligned four-byte lock words. A zero word is unlocked,
one is held, and two is held with possible waiters. Acquire by atomically
changing zero to one, or exchange with two before waiting on value two.
Retry expected wake races and signal interruptions. Release by exchanging
with zero and wake one waiter if the previous value was two. Private
library locks use FUTEX_WAIT_PRIVATE and FUTEX_WAKE_PRIVATE. The x86-64
locked operations carry the acquire/release ordering. A malformed state
or an unexpected kernel futex failure uses the raw fatal diagnostic path.
These hooks preserve errno and remain active for the initial thread, so
ownership can span the first thread creation without changing meaning.

No application callback runs under an allocator, stream registry, or
termination registry lock. Audit lock nesting and all public paths that
call a locked helper. A child after a multi-threaded `fork` uses the
existing async-signal-safe path to exec or `_exit`. The
[threaded fork contract](0043-threaded-fork.md) defines callbacks,
the runtime guard set, and the surviving child descriptor.
Future recursive public stdio locking must share ownership with implicit
I/O without making the unlocked entry points reacquire that lock.
[Linux futex](https://man7.org/linux/man-pages/man2/futex.2.html)

## Public mutexes

A process-private mutex uses 32 bytes with eight-byte alignment. The
first four bytes hold the same 0/1/2 futex word used by internal locks.
The type starts at byte four, the owner token at byte eight, the
recursive count at byte 16, and the destroyed marker at byte 24.
Default static initialization is four zero words. Attributes use a
16-byte opaque object and select normal, error-checking, or recursive
behavior. Default selects normal.

The runtime assigns each TLS allocation a unique nonzero ownership
token before publication. It does not reuse tokens when a mapping
address or kernel TID is reused. This keeps ownership meaningful even
if an application leaves a non-robust mutex locked at thread exit.
The first acquisition publishes owner and count only after acquiring
the futex word. A final release clears both before releasing the word.
Recursive acquisition increments up to the 32-bit count limit.
Error-checking self-lock returns EDEADLK. Try-lock never waits and
returns EBUSY for an already-held nonrecursive mutex. Foreign or
unowned unlock returns EPERM. A signal-interrupted wait resumes
inside the runtime. All API results preserve errno.

Timed mutex acquisition first tries the ordinary uncontended path.
A valid immediately acquired mutex needs no deadline read. If it
would block, a malformed nanosecond field returns EINVAL and an
expired absolute deadline returns ETIMEDOUT. The default clock is
CLOCK_REALTIME. The clock-selecting operation also supports
CLOCK_MONOTONIC. Both share the same futex word and wake protocol
as ordinary waiters. An interrupted timed wait retains its original
deadline. The public mutex type retains the same representation.
[POSIX mutex operations](https://pubs.opengroup.org/onlinepubs/9799919799/functions/pthread_mutex_lock.html)

## Condition variables

A process-private condition variable is 32 bytes with eight-byte
alignment. Its internal gate, selected clock, active waiter count,
and destroyed marker use four-byte fields at offsets 0 through 12.
Queue head and tail pointers follow. The default initializer is zero
and selects CLOCK_REALTIME. The 16-byte attribute object also accepts
CLOCK_MONOTONIC. Clockwait may select either clock for one call.

A caller holds its mutex exactly once. The runtime queues that
thread's dedicated TLS wait node before releasing the mutex. Signal
removes one node and broadcast removes all current nodes. A selected
node's four-byte wake flag stays set until the waiter finishes. This
avoids losing a notification to a shared sequence wrap. The signaller
holds the condition gate through the kernel wake. A waiter takes that
gate before reusing its node, including after an already-visible wake.
Timeout removes an unselected node while holding the gate. An already
expired valid deadline still releases and reacquires the mutex.
The caller never receives EINTR. Condition wait always reacquires a
valid mutex that it released. Cancellation and process sharing have
separate acceptance requirements.
[POSIX condition waits](https://pubs.opengroup.org/onlinepubs/9799919799/functions/pthread_cond_clockwait.html) ·
[Linux absolute futex waits](https://man7.org/linux/man-pages/man2/FUTEX_WAIT_BITSET.2const.html)

## Thread-specific keys

A process supports 128 live keys. A key is an opaque unsigned integer.
Creation publishes the result only after installing the key and
optional destructor. Exhaustion returns EAGAIN with the output
unchanged. A newly created key has a null value in every thread.
Each thread starts with null values regardless of its creator's values.
The thread stores a value together with the generation of its key.
Deleting a key invalidates the generation without calling its
destructor. When the key index is reused, only values from the new
generation are visible. Deleting an unavailable index or setting its
value returns EINVAL. A read of such an index yields null. Defined
API results preserve errno.

Thread exit clears each live, nonnull value before calling its
associated destructor. Destructors run with no key-table lock held.
A destructor can use any live key, including setting its own value
again. Exit performs up to four passes. It completes these passes
before publishing the thread result or releasing its stack and TLS.
Process exit does not invoke thread-specific destructors. Callback
order within a pass is unspecified.
[POSIX key creation](https://pubs.opengroup.org/onlinepubs/9799919799/functions/pthread_key_create.html) ·
[POSIX key deletion](https://pubs.opengroup.org/onlinepubs/9799919799/functions/pthread_key_delete.html)

## One-time initialization

The four-byte control starts at zero, changes to one while the
initializer runs, and becomes two after the initializer returns.
PTHREAD_ONCE_INIT is zero. Waiters use a private futex and retry
interrupted waits. The release publication makes all initializer
writes visible to returning callers. The callback runs with no
internal lock held. Nested initialization of other controls works.
A callback using the same in-progress control waits for completion.

Each active initializer publishes a bounded record in its own stack
and links it through its TLS descriptor. A normal return retires that
record before leaving the frame. Explicit pthread_exit resets and
wakes pending controls before invoking thread-specific destructors.
This lets later callers take over an incomplete initialization.
Asynchronous cancellation and broader post-fork runtime use remain
separate acceptance scopes. Jumping out of the initializer through
longjmp is undefined by POSIX.
[POSIX one-time initialization](https://pubs.opengroup.org/onlinepubs/9799919799/functions/pthread_once.html)

## C11 threads

The generated threads.h exposes all 25 C17 7.26 operations.
Thread identity, thread-specific keys, the once word, and the layouts
for mutex and condition objects use the same runtime mechanisms as
their POSIX counterparts. C11 mutex and condition object types are
declared independently and are initialized through their C11 API.
Timed waits use TIME_UTC through CLOCK_REALTIME.

Thread creation reuses the runtime stack and TLS allocation and
the same Linux clone boundary. The child dispatches the callback
according to its saved start mode. A C11 routine returns an int
from EAX and the runtime sign-extends that result. A POSIX routine
returns the full pointer from RAX. The C11 child waits for the parent
to publish the handle before entering the callback. The creator
publishes the flag as its final descriptor access. Join reclaims
the same mappings and publishes only an int for a C11 result.

The integer status constants are zero for success, one for busy,
two for error, three for unavailable memory, and four for timeout.
A resource allocation failure reports thrd_nomem from thrd_create.
Successful return from thrd_sleep leaves the remainder untouched.
An interruption reports -1 and preserves the kernel remainder when
requested. Other errors report -2. A scheduler yield uses the Linux
yield boundary. These wrappers preserve errno unless an application
callback modifies its own thread's errno.
[C17 7.26 draft](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

## C17 flag and fence boundary

The generated stdatomic header retains the pinned compilers' builtin
macros and generic operations. Function designators for the six flag
and fence APIs resolve to the Open Assembly archive. The compiler
header must expose a one-byte lock-free atomic_flag and the selected
memory_order values. Sequentially consistent flag clear uses a locked
byte exchange. Relaxed and release clear use a byte store. Test and set
uses a locked exchange for all orders. A sequentially consistent
thread fence uses MFENCE. Inline signal fences preserve the compiler
ordering boundary and the out-of-line signal fence emits no machine
fence. Wider non-lock-free compiler atomics have a separate ABI.
[C17 7.17 draft](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n2310.pdf)

## Verification boundary

Validate raw clone flags, branch-specific stack alignment, cleanup after
partial allocation and clone failure, clear-TID wait/wake, and the absence
of stack or TLS accesses after unmapping. Run independent native fixtures
for result transport, join/exit races, detached reclamation, guarded
stacks, compiler TLS initial values and isolation, alternate errno,
signal masks, and shared allocator/stream stress. Probe QEMU and Memcheck
separately and record their actual support for raw thread creation.

Choose applicable Open POSIX cases from a pinned, licensed Linux Test
Project tree and preserve their source hashes. Run the candidate with
Open Assembly startup and archive only. Use intentional races and a
lock-order positive control to establish what each detector observes.
If a detector needs client annotations, add them only in test fixtures
at measured lock and lifecycle edges, record the executable and annotation
hashes, and rerun controls through the same route. Native stress and
detector results remain separate observations.
[Open POSIX test tree](https://github.com/linux-test-project/ltp/tree/master/testcases/open_posix_testsuite) ·
[Helgrind manual](https://valgrind.org/docs/manual/hg-manual.html) ·
[DRD manual](https://valgrind.org/docs/manual/drd-manual.html)
